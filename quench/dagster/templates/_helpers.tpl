{{- define "dagster.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "dagster.selectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* PostgreSQL: the bundled subchart, or an external server. Required: the webserver and
     the daemon share run, event and schedule storage, which SQLite cannot do across pods. */}}
{{- define "dagster.pg.host" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ required "Dagster needs PostgreSQL: set postgresql.enabled=true or externalDatabase.host" .Values.externalDatabase.host }}{{- end -}}
{{- end -}}
{{- define "dagster.pg.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}
{{- define "dagster.pg.database" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}
{{- define "dagster.pg.username" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.username }}{{- end -}}
{{- end -}}
{{- define "dagster.pg.secretName" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ required "externalDatabase.existingSecret is required with an external database" .Values.externalDatabase.existingSecret }}{{- end -}}
{{- end -}}
{{- define "dagster.pg.secretKey" -}}
{{- if .Values.postgresql.enabled -}}postgres-password{{- else -}}{{ .Values.externalDatabase.existingSecretPasswordKey }}{{- end -}}
{{- end -}}

{{/* Env shared by every Dagster process: where the instance's PostgreSQL is. */}}
{{- define "dagster.env" -}}
- name: DAGSTER_PG_HOST
  value: {{ include "dagster.pg.host" . | quote }}
- name: DAGSTER_PG_PORT
  value: {{ include "dagster.pg.port" . | quote }}
- name: DAGSTER_PG_DB
  value: {{ include "dagster.pg.database" . | quote }}
- name: DAGSTER_PG_USERNAME
  value: {{ include "dagster.pg.username" . | quote }}
- name: DAGSTER_PG_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "dagster.pg.secretName" . }}
      key: {{ include "dagster.pg.secretKey" . }}
{{- with .Values.extraEnvVars }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/* Mounts shared by the webserver and daemon: DAGSTER_HOME with dagster.yaml, and the
     workspace file. */}}
{{- define "dagster.mounts" -}}
- name: home
  mountPath: /var/lib/dagster
- name: config
  mountPath: /var/lib/dagster/dagster.yaml
  subPath: dagster.yaml
  readOnly: true
- name: config
  mountPath: /etc/dagster/workspace.yaml
  subPath: workspace.yaml
  readOnly: true
- name: tmp
  mountPath: /tmp
{{- end -}}

{{- define "dagster.volumes" -}}
- name: home
  emptyDir: {}
- name: tmp
  emptyDir: {}
- name: config
  configMap:
    name: {{ include "quench-common.fullname" . }}-config
{{- end -}}

{{/* Hold every Dagster process until PostgreSQL accepts connections. A code server that
     starts first gives up after its retries and keeps serving the load error while its
     TCP probe stays green. The image has no shell, so the wait is a python socket loop. */}}
{{- define "dagster.waitForDb" -}}
- name: wait-for-postgres
  image: {{ include "quench-common.image" . }}
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  command:
    - /opt/dagster/venv/bin/python
    - -c
    - |
      import socket, sys, time
      host, port = sys.argv[1], int(sys.argv[2])
      for _ in range(150):
          try:
              socket.create_connection((host, port), timeout=2).close()
              sys.exit(0)
          except OSError:
              time.sleep(2)
      sys.exit(f"postgres {host}:{port} not reachable")
    - {{ include "dagster.pg.host" . | quote }}
    - {{ include "dagster.pg.port" . | quote }}
  securityContext:
    {{- include "quench-common.containerSecurityContext" . | nindent 4 }}
{{- end -}}
