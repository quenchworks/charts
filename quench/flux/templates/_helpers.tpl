{{/* Service DNS names the controllers advertise to each other */}}
{{- define "flux.notificationAddr" -}}
http://{{ include "quench-common.fullname" . }}-notification.{{ .Release.Namespace }}.svc.cluster.local./
{{- end -}}
{{- define "flux.sourceAddr" -}}
{{ include "quench-common.fullname" . }}-source.{{ .Release.Namespace }}.svc.cluster.local.
{{- end -}}
