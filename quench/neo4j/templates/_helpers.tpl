{{/* Secret holding the full NEO4J_AUTH string (neo4j/<password>) */}}
{{- define "neo4j.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "neo4j.secretAuthKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretAuthKey }}{{- else -}}neo4j-auth{{- end -}}
{{- end -}}

{{- define "neo4j.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service name for the StatefulSet (stable pod DNS) */}}
{{- define "neo4j.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Stable DNS the Bolt driver should be advertised on: the ClusterIP service. */}}
{{- define "neo4j.advertisedHost" -}}
{{- printf "%s.%s.svc.cluster.local" (include "quench-common.fullname" .) .Release.Namespace -}}
{{- end -}}
