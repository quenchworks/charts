{{- define "zabbix.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "zabbix.componentLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "zabbix.webImage" -}}
{{ .Values.web.image.repository }}@{{ .Values.web.image.digest }}
{{- end -}}

{{/* ZBX_DB_* for the frontend and the schema loader, which read the same variables. */}}
{{- define "zabbix.dbEnv" -}}
- { name: ZBX_DB_HOST, value: zabbix-postgresql }
- { name: ZBX_DB_PORT, value: "5432" }
- { name: ZBX_DB_NAME, value: {{ .Values.postgresql.auth.database | quote }} }
- { name: ZBX_DB_USER, value: {{ .Values.postgresql.auth.username | quote }} }
- name: ZBX_DB_PASSWORD
  valueFrom: { secretKeyRef: { name: zabbix-db, key: postgres-password } }
{{- end -}}
