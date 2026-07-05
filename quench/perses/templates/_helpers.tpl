{{- define "perses.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the PVC used for the file datastore. */}}
{{- define "perses.pvcName" -}}
{{- if .Values.persistence.existingClaim -}}{{ .Values.persistence.existingClaim }}{{- else -}}{{ printf "%s-data" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{/* True (emits "true") when a PVC-backed datastore volume is in play. */}}
{{- define "perses.persistenceEnabled" -}}
{{- if .Values.persistence.enabled -}}true{{- end -}}
{{- end -}}
