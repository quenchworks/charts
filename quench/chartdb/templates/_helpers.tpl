{{/* Every port ChartDB listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "chartdb.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{/* The runtime config the app loads from /config.js (served to every browser: nothing secret belongs here). */}}
{{- define "chartdb.configjs" -}}
window.env = { OPENAI_API_KEY: {{ .Values.ai.apiKey | toJson }}, OPENAI_API_ENDPOINT: {{ .Values.ai.endpoint | toJson }}, LLM_MODEL_NAME: {{ .Values.ai.model | toJson }}, HIDE_CHARTDB_CLOUD: {{ ternary "true" "false" .Values.hideCloud | quote }}, DISABLE_ANALYTICS: {{ ternary "true" "false" .Values.disableAnalytics | quote }} };
{{- end -}}
