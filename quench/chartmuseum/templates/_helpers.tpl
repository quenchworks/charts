{{- define "chartmuseum.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the PVC backing the chart storage directory. */}}
{{- define "chartmuseum.pvcName" -}}
{{- if .Values.persistence.existingClaim -}}{{ .Values.persistence.existingClaim }}{{- else -}}{{ printf "%s-storage" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{/* Whether basic auth is configured (inline credentials or an existing Secret). */}}
{{- define "chartmuseum.authEnabled" -}}
{{- if or .Values.auth.existingSecret .Values.auth.username -}}true{{- end -}}
{{- end -}}

{{/* Secret holding the basic-auth credentials consumed by the pod. */}}
{{- define "chartmuseum.authSecretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "chartmuseum.authUserKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretUserKey }}{{- else -}}basic-auth-user{{- end -}}
{{- end -}}

{{- define "chartmuseum.authPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}basic-auth-pass{{- end -}}
{{- end -}}
