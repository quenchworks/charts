{{- define "step-ca.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
ServiceAccount the pre-install bootstrap Job runs as. It cannot use a
chart-created ServiceAccount (that is a normal release resource, applied AFTER
pre-install hooks), so when serviceAccount.create is true it falls back to
"default"; when create is false it uses the pre-provisioned name (e.g. an
image-pull ServiceAccount that already exists before install).
*/}}
{{- define "step-ca.bootstrapServiceAccountName" -}}
{{- if .Values.serviceAccount.create -}}default{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service that governs the StatefulSet (stable pod DNS) */}}
{{- define "step-ca.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Secret holding the CA key password + first provisioner password */}}
{{- define "step-ca.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{/* PVC that holds STEPPATH (ca.json + certs/keys + db) */}}
{{- define "step-ca.pvcName" -}}
{{- if .Values.persistence.existingClaim -}}{{ .Values.persistence.existingClaim }}{{- else -}}{{ printf "%s-pki" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}
