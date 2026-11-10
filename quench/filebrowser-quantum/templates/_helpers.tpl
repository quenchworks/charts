{{- define "filebrowser-quantum.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* PVC for the SQLite database (users, shares, settings). */}}
{{- define "filebrowser-quantum.dataClaim" -}}
{{- if .Values.persistence.existingClaim -}}{{ .Values.persistence.existingClaim }}{{- else -}}{{ printf "%s-data" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{/* PVC for the files FileBrowser serves (/srv). */}}
{{- define "filebrowser-quantum.filesClaim" -}}
{{- if .Values.files.existingClaim -}}{{ .Values.files.existingClaim }}{{- else -}}{{ printf "%s-files" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{/* Secret holding the admin password and the JWT signing secret. */}}
{{- define "filebrowser-quantum.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}
