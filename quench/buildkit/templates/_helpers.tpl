{{- define "buildkit.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "buildkit.claimName" -}}
{{- default (printf "%s-cache" (include "quench-common.fullname" .)) .Values.persistence.existingClaim -}}
{{- end -}}
