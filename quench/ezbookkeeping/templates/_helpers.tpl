{{/* Every port ezBookkeeping listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "ezbookkeeping.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "ezbookkeeping.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "ezbookkeeping.secretName" -}}
{{- .Values.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}
