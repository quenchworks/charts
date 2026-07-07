{{- define "woodpecker.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service that governs the StatefulSet (stable pod DNS) */}}
{{- define "woodpecker.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* True when an agent secret should be wired into the pod (chart-created or BYO) */}}
{{- define "woodpecker.agentSecretEnabled" -}}
{{- if or .Values.agentSecret.value .Values.agentSecret.existingSecret -}}true{{- end -}}
{{- end -}}

{{/* Name of the Secret carrying WOODPECKER_AGENT_SECRET (existing takes precedence) */}}
{{- define "woodpecker.agentSecretName" -}}
{{- if .Values.agentSecret.existingSecret -}}{{ .Values.agentSecret.existingSecret }}{{- else -}}{{ printf "%s-agent" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{/* Key within that Secret holding the agent secret value */}}
{{- define "woodpecker.agentSecretKey" -}}
{{- default "WOODPECKER_AGENT_SECRET" .Values.agentSecret.existingSecretKey -}}
{{- end -}}
