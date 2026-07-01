{{- define "floci.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the PVC used for persistent storage. */}}
{{- define "floci.pvcName" -}}
{{- if .Values.persistence.existingClaim -}}{{ .Values.persistence.existingClaim }}{{- else -}}{{ printf "%s-data" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{/* True when a writable data volume must be mounted (persistence on). */}}
{{- define "floci.persistenceEnabled" -}}
{{- if .Values.persistence.enabled -}}true{{- end -}}
{{- end -}}
