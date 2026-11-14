{{/* Every port Shiori listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "shiori.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "shiori.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "shiori.secretName" -}}
{{- .Values.owner.existingSecret | default (printf "%s-owner" (include "quench-common.fullname" .)) -}}
{{- end -}}

{{- define "shiori.sessionSecretName" -}}
{{- printf "%s-session" (include "quench-common.fullname" .) -}}
{{- end -}}
