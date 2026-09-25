{{- define "prefect.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "prefect.selectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* PostgreSQL: the bundled subchart, or an external server. */}}
{{- define "prefect.pg.host" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ required "Prefect needs PostgreSQL: set postgresql.enabled=true or externalDatabase.host" .Values.externalDatabase.host }}{{- end -}}
{{- end -}}
{{- define "prefect.pg.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}
{{- define "prefect.pg.database" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}
{{- define "prefect.pg.username" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.username }}{{- end -}}
{{- end -}}
{{- define "prefect.pg.secretName" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ required "externalDatabase.existingSecret is required with an external database" .Values.externalDatabase.existingSecret }}{{- end -}}
{{- end -}}
{{- define "prefect.pg.secretKey" -}}
{{- if .Values.postgresql.enabled -}}postgres-password{{- else -}}{{ .Values.externalDatabase.existingSecretPasswordKey }}{{- end -}}
{{- end -}}

{{/* The server's database, as discrete settings so the password never sits in a URL. */}}
{{- define "prefect.server.env" -}}
- name: PREFECT_SERVER_DATABASE_DRIVER
  value: postgresql+asyncpg
- name: PREFECT_SERVER_DATABASE_HOST
  value: {{ include "prefect.pg.host" . | quote }}
- name: PREFECT_SERVER_DATABASE_PORT
  value: {{ include "prefect.pg.port" . | quote }}
- name: PREFECT_SERVER_DATABASE_NAME
  value: {{ include "prefect.pg.database" . | quote }}
- name: PREFECT_SERVER_DATABASE_USER
  value: {{ include "prefect.pg.username" . | quote }}
- name: PREFECT_SERVER_DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "prefect.pg.secretName" . }}
      key: {{ include "prefect.pg.secretKey" . }}
- name: PREFECT_UI_ENABLED
  value: {{ .Values.ui.enabled | quote }}
- name: PREFECT_UI_API_URL
  value: {{ .Values.ui.apiUrl | quote }}
{{- with .Values.extraEnvVars }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/* Writable PREFECT_HOME (the UI copy lives there) and /tmp under a read-only root. */}}
{{- define "prefect.mounts" -}}
- name: home
  mountPath: /var/lib/prefect
- name: tmp
  mountPath: /tmp
{{- end -}}
{{- define "prefect.volumes" -}}
- name: home
  emptyDir: {}
- name: tmp
  emptyDir: {}
{{- end -}}

{{/* Hold a process until host:port accepts connections. The image has no shell, so the
     wait is a python socket loop. Call with (dict "ctx" . "host" h "port" p). */}}
{{- define "prefect.waitFor" -}}
- name: wait-for-{{ .name }}
  image: {{ include "quench-common.image" .ctx }}
  imagePullPolicy: {{ .ctx.Values.image.pullPolicy }}
  command:
    - /opt/prefect/venv/bin/python
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
      sys.exit(f"{host}:{port} not reachable")
    - {{ .host | quote }}
    - {{ .port | quote }}
  securityContext:
    {{- include "quench-common.containerSecurityContext" .ctx | nindent 4 }}
{{- end -}}
