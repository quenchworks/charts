{{/* Every port Inbucket listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "inbucket.ports" -}}
{{- $l := list (dict "name" "http" "port" 9000 "servicePort" (int .Values.service.port) "protocol" "TCP") }}
{{- $l = append $l (dict "name" "smtp" "port" 2500 "servicePort" (int .Values.service.smtpPort) "protocol" "TCP") }}
{{- if .Values.pop3.enabled }}
{{- $l = append $l (dict "name" "pop3" "port" 1100 "servicePort" (int .Values.service.pop3Port) "protocol" "TCP") }}
{{- end }}
{{- toJson $l -}}
{{- end -}}

{{- define "inbucket.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}
