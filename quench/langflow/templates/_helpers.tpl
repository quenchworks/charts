{{/* The UI and the REST API on 7860. */}}
{{- define "langflow.ports" -}}
{{- toJson (list (dict "name" "http" "port" 7860 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "langflow.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}
