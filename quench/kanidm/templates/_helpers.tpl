{{/* Every port kanidmd listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "kanidm.ports" -}}
{{- $p := list (dict "name" "https" "port" 8443 "servicePort" (int .Values.service.port) "protocol" "TCP") -}}
{{- if .Values.ldap.enabled -}}
{{- $p = append $p (dict "name" "ldaps" "port" 3636 "servicePort" (int .Values.service.ldapsPort) "protocol" "TCP") -}}
{{- end -}}
{{- toJson $p -}}
{{- end -}}

{{- define "kanidm.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The public origin: https://<domain>, unless set. */}}
{{- define "kanidm.origin" -}}
{{- .Values.origin | default (printf "https://%s" (required "domain is required: the DNS name clients use, e.g. idm.example.com (it cannot change after the first start)" .Values.domain)) -}}
{{- end -}}
