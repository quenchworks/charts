{{- define "atlantis.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service used for the StatefulSet's stable pod DNS. */}}
{{- define "atlantis.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Name of the ConfigMap holding the optional server-side repos.yaml. */}}
{{- define "atlantis.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The Secret name carrying the VCS token + webhook secret: either the managed
     one (chart fullname) or the user-supplied existingSecret. */}}
{{- define "atlantis.secretName" -}}
{{- if .Values.vcs.existingSecret -}}{{ .Values.vcs.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}
