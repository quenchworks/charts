{{- define "openziti.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "openziti.advertisedHost" -}}
{{- default (printf "%s.%s.svc.cluster.local" (include "quench-common.fullname" .) .Release.Namespace) .Values.advertisedHost -}}
{{- end -}}

{{- define "openziti.adminSecret" -}}
{{- default (printf "%s-admin" (include "quench-common.fullname" .)) .Values.admin.existingSecret -}}
{{- end -}}
