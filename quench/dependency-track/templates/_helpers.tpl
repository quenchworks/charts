{{- define "dtrack.api" -}}{{ include "quench-common.fullname" . }}-api{{- end -}}
{{- define "dtrack.frontend" -}}{{ include "quench-common.fullname" . }}{{- end -}}

{{- define "dtrack.db.url" -}}
{{- if .Values.postgresql.enabled -}}
jdbc:postgresql://{{ .Release.Name }}-postgresql:5432/{{ .Values.postgresql.auth.database }}
{{- else -}}
{{- required "externalDatabase.url is required when postgresql.enabled=false" .Values.externalDatabase.url -}}
{{- end -}}
{{- end -}}
{{- define "dtrack.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.username }}{{- end -}}
{{- end -}}
{{- define "dtrack.db.secret" -}}
{{- if .Values.postgresql.enabled -}}{{ .Release.Name }}-postgresql{{- else -}}{{ required "externalDatabase.existingSecret is required when postgresql.enabled=false" .Values.externalDatabase.existingSecret }}{{- end -}}
{{- end -}}
{{- define "dtrack.db.secretKey" -}}
{{- if .Values.postgresql.enabled -}}postgres-password{{- else -}}{{ .Values.externalDatabase.existingSecretPasswordKey }}{{- end -}}
{{- end -}}
{{/* host:port for the wait-for-db initContainer */}}
{{- define "dtrack.db.hostport" -}}
{{- $u := include "dtrack.db.url" . | trimPrefix "jdbc:postgresql://" -}}
{{- $hp := regexReplaceAll "/.*$" $u "" -}}
{{- if contains ":" $hp }}{{ $hp }}{{ else }}{{ $hp }}:5432{{ end -}}
{{- end -}}
