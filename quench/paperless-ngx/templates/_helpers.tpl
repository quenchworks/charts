{{/* Every port the server listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "paperless-ngx.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "paperless-ngx.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "paperless-ngx.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Settings every Paperless process reads (web, worker, scheduler, consumer, init steps). PostgreSQL and Valkey
     passwords come from the subcharts' own Secrets; PAPERLESS_REDIS splices the Valkey one in by Kubernetes $(VAR)
     expansion (generated passwords are alphanumeric, URL-safe). */}}
{{- define "paperless-ngx.env" -}}
- name: PAPERLESS_SECRET_KEY
  valueFrom:
    secretKeyRef: { name: {{ include "paperless-ngx.secretName" . }}, key: secret-key }
- { name: PAPERLESS_DATA_DIR, value: /var/lib/paperless/data }
- { name: PAPERLESS_MEDIA_ROOT, value: /var/lib/paperless/media }
- { name: PAPERLESS_CONSUMPTION_DIR, value: /var/lib/paperless/consume }
- { name: PAPERLESS_SCRATCH_DIR, value: /tmp/paperless }
{{- if .Values.postgresql.enabled }}
- { name: PAPERLESS_DBHOST, value: {{ printf "%s-postgresql" .Release.Name | quote }} }
- { name: PAPERLESS_DBUSER, value: {{ .Values.postgresql.auth.username | quote }} }
- { name: PAPERLESS_DBNAME, value: {{ .Values.postgresql.auth.database | quote }} }
- name: PAPERLESS_DBPASS
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-postgresql" .Release.Name }}, key: postgres-password }
{{- else }}
- { name: PAPERLESS_DBHOST, value: {{ required "externalDatabase.host (or postgresql.enabled)" .Values.externalDatabase.host | quote }} }
- { name: PAPERLESS_DBPORT, value: {{ .Values.externalDatabase.port | quote }} }
- { name: PAPERLESS_DBUSER, value: {{ .Values.externalDatabase.username | quote }} }
- { name: PAPERLESS_DBNAME, value: {{ .Values.externalDatabase.database | quote }} }
- name: PAPERLESS_DBPASS
  valueFrom:
    secretKeyRef: { name: {{ required "externalDatabase.existingSecret" .Values.externalDatabase.existingSecret }}, key: {{ .Values.externalDatabase.existingSecretKey }} }
{{- end }}
{{- if .Values.valkey.enabled }}
- name: KV_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-valkey" .Release.Name }}, key: valkey-password }
- { name: PAPERLESS_REDIS, value: "redis://:$(KV_PASSWORD)@{{ .Release.Name }}-valkey:6379" }
{{- else if .Values.externalRedis.existingSecret }}
- name: PAPERLESS_REDIS
  valueFrom:
    secretKeyRef: { name: {{ .Values.externalRedis.existingSecret }}, key: {{ .Values.externalRedis.existingSecretKey }} }
{{- else }}
{{- fail "set valkey.enabled, or externalRedis.existingSecret with a redis:// URL" }}
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}

{{/* One Paperless container: name, args (empty = the image's web server), extra env. */}}
{{- define "paperless-ngx.container" -}}
{{- $ctx := .ctx -}}
- name: {{ .name }}
  image: {{ include "quench-common.image" $ctx }}
  imagePullPolicy: {{ $ctx.Values.image.pullPolicy }}
  {{- with .command }}
  command: {{ toJson . }}
  {{- end }}
  securityContext:
    {{- include "quench-common.containerSecurityContext" $ctx | nindent 4 }}
  env:
    {{- include "paperless-ngx.env" $ctx | nindent 4 }}
    {{- with .env }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- include "quench-common.extraEnvVars" $ctx | nindent 4 }}
  {{- include "quench-common.envFrom" $ctx | nindent 2 }}
  {{- with .resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  volumeMounts:
    - { name: tmp, mountPath: /tmp }
    - { name: data, mountPath: /var/lib/paperless }
    {{- include "quench-common.extraVolumeMounts" $ctx | nindent 4 }}
{{- end -}}
