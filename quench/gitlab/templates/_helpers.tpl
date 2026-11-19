{{/* Selector labels for one component (webservice, sidekiq, gitaly, gitlab-shell, migrations). */}}
{{- define "gitlab.selectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "gitlab.secretName" -}}
{{- default (include "quench-common.fullname" .) .Values.secrets.existingSecret -}}
{{- end -}}

{{/* Database: the bundled postgresql subchart (its superuser password under postgres-password), or externalDatabase. */}}
{{- define "gitlab.db.host" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host }}{{- end -}}
{{- end -}}
{{- define "gitlab.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}
{{- define "gitlab.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}
{{- define "gitlab.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.username }}{{- end -}}
{{- end -}}
{{- define "gitlab.db.passwordRef" -}}
{{- if .Values.postgresql.enabled -}}
{ name: {{ printf "%s-postgresql" .Release.Name }}, key: postgres-password }
{{- else -}}
{ name: {{ required "externalDatabase.existingSecret is required when postgresql.enabled=false" .Values.externalDatabase.existingSecret }}, key: {{ .Values.externalDatabase.existingSecretPasswordKey }} }
{{- end -}}
{{- end -}}

{{/* Redis: the bundled valkey subchart (Secret key valkey-password), or externalRedis. */}}
{{- define "gitlab.redis.host" -}}
{{- if .Values.valkey.enabled -}}{{ printf "%s-valkey" .Release.Name }}{{- else -}}{{ required "externalRedis.host is required when valkey.enabled=false" .Values.externalRedis.host }}{{- end -}}
{{- end -}}
{{- define "gitlab.redis.port" -}}
{{- if .Values.valkey.enabled -}}6379{{- else -}}{{ .Values.externalRedis.port }}{{- end -}}
{{- end -}}

{{/* Environment for every Rails process (webservice, sidekiq, migrations). The config files in configmap-rails.yaml
read these through ERB; REDIS_URL embeds the password by Kubernetes $(VAR) expansion, so REDIS_PASSWORD comes first. */}}
{{- define "gitlab.railsEnv" -}}
- { name: DB_HOST, value: {{ include "gitlab.db.host" . | quote }} }
- { name: DB_PORT, value: {{ include "gitlab.db.port" . | quote }} }
- { name: DB_NAME, value: {{ include "gitlab.db.name" . | quote }} }
- { name: DB_USER, value: {{ include "gitlab.db.user" . | quote }} }
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef: {{ include "gitlab.db.passwordRef" . }}
{{- if .Values.valkey.enabled }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-valkey" .Release.Name }}, key: valkey-password }
- { name: REDIS_URL, value: "redis://:$(REDIS_PASSWORD)@{{ include "gitlab.redis.host" . }}:{{ include "gitlab.redis.port" . }}" }
{{- else }}
- { name: REDIS_URL, value: {{ required "externalRedis.url is required when valkey.enabled=false" .Values.externalRedis.url | quote }} }
{{- end }}
- { name: TMPDIR, value: /tmp/rails }
- { name: EXECJS_RUNTIME, value: Disabled }   # terser loads with the bundle; assets are compiled, no JS runtime ships
- name: GITALY_TOKEN
  valueFrom:
    secretKeyRef: { name: {{ include "gitlab.secretName" . }}, key: gitaly-token }
{{- with .Values.extraEnvVars }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/* Rails config and secrets, one file per subPath into /srv/gitlab/config, plus the writable dirs the image expects
on a read-only rootfs. */}}
{{- define "gitlab.railsMounts" -}}
{{- range $f := list "gitlab.yml" "database.yml" "resque.yml" "cable.yml" }}
- { name: rails-config, mountPath: /srv/gitlab/config/{{ $f }}, subPath: {{ $f }}, readOnly: true }
{{- end }}
- { name: secrets, mountPath: /srv/gitlab/config/secrets.yml, subPath: secrets.yml, readOnly: true }
- { name: secrets, mountPath: /etc/gitlab/secrets/workhorse-secret, subPath: workhorse-secret, readOnly: true }
- { name: secrets, mountPath: /etc/gitlab/secrets/shell-secret, subPath: shell-secret, readOnly: true }
- { name: tmp, mountPath: /tmp }
- { name: rails-tmp, mountPath: /srv/gitlab/tmp }
- { name: rails-log, mountPath: /srv/gitlab/log }
- { name: shared, mountPath: /srv/gitlab/shared }
{{- end -}}
{{- define "gitlab.railsVolumes" -}}
- name: rails-config
  configMap: { name: {{ include "quench-common.fullname" . }}-rails }
- name: secrets
  secret: { secretName: {{ include "gitlab.secretName" . }} }
- { name: tmp, emptyDir: {} }
- { name: rails-tmp, emptyDir: {} }
- { name: rails-log, emptyDir: {} }
{{- if .Values.shared.persistence.enabled }}
- name: shared
  persistentVolumeClaim: { claimName: {{ .Values.shared.persistence.existingClaim | default (printf "%s-shared" (include "quench-common.fullname" .)) }} }
{{- else }}
- { name: shared, emptyDir: {} }
{{- end }}
{{- end -}}

{{/* Ruby's Dir.tmpdir refuses a world-writable dir without the sticky bit, which is every emptyDir (0777), so a
Rails pod would die on "could not find a temporary directory". This init container makes a 0700 dir inside the /tmp
emptyDir; gitlab.railsEnv points TMPDIR at it. */}}
{{- define "gitlab.tmpInit" -}}
- name: tmpdir
  image: "{{ .Values.rails.image.repository }}@{{ .Values.rails.image.digest }}"
  securityContext:
    {{- include "quench-common.containerSecurityContext" . | nindent 4 }}
  # /srv/gitlab/tmp is an emptyDir too: Rails and Puma expect its pids/sockets/cache subdirs to exist
  command: ["/bin/sh", "-c", "mkdir -p -m 0700 /tmp/rails && mkdir -p /srv/gitlab/tmp/pids /srv/gitlab/tmp/sockets /srv/gitlab/tmp/cache"]
  volumeMounts:
    - { name: tmp, mountPath: /tmp }
    - { name: rails-tmp, mountPath: /srv/gitlab/tmp }
{{- end -}}
