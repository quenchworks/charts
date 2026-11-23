{{/* The web app and the WebSocket signaling on 3000. */}}
{{- define "pairdrop.ports" -}}
{{- toJson (list (dict "name" "http" "port" 3000 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}
