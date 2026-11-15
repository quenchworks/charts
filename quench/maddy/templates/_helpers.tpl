{{/* Every port Maddy listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "maddy.ports" -}}
{{- $p := list
  (dict "name" "smtp" "port" 2525 "servicePort" (int .Values.service.smtpPort) "protocol" "TCP")
  (dict "name" "submission" "port" 1587 "servicePort" (int .Values.service.submissionPort) "protocol" "TCP")
  (dict "name" "imap" "port" 1143 "servicePort" (int .Values.service.imapPort) "protocol" "TCP") -}}
{{- if include "quench-common.tls.enabled" . -}}
{{- $p = append $p (dict "name" "imaps" "port" 1993 "servicePort" (int .Values.service.imapsPort) "protocol" "TCP") -}}
{{- end -}}
{{- toJson $p -}}
{{- end -}}

{{- define "maddy.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}
