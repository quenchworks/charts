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
