{{/* Secret holding the ClickHouse user password */}}
{{- define "clickhouse.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "clickhouse.secretPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}admin-password{{- end -}}
{{- end -}}

{{- define "clickhouse.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service name for the StatefulSet */}}
{{- define "clickhouse.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/*
Resolve the user password the chart manages: explicit value wins, else reuse the
password already stored in the managed Secret (preserve across upgrades), else
generate a 24-char random one. Returns the plaintext password. Only meaningful when
auth.existingSecret is unset (otherwise the chart does not own the password).
*/}}
{{- define "clickhouse.password" -}}
{{- $name := include "quench-common.fullname" . -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $name -}}
{{- $pw := .Values.auth.password -}}
{{- if and (not $pw) $existing -}}
{{- $pw = index $existing.data "admin-password" | b64dec -}}
{{- end -}}
{{- if not $pw -}}
{{- $pw = randAlphaNum 24 -}}
{{- end -}}
{{- $pw -}}
{{- end -}}
