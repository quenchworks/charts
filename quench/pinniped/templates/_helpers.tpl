{{- define "pinniped.name" -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- define "pinniped.suffixed" -}}{{ include "quench-common.fullname" .root }}-{{ .suffix }}{{- end -}}
{{/* The Concierge assumes an `app` label on the objects it manages (kube cert agent,
     impersonation proxy); it copies the configured labels onto them. */}}
{{- define "pinniped.appLabel" -}}app: {{ include "quench-common.fullname" . }}{{- end -}}
