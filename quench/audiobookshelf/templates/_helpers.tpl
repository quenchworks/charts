{{/* Every port Audiobookshelf listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "audiobookshelf.ports" -}}
{{- toJson (list (dict "name" "http" "port" 13378 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "audiobookshelf.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "audiobookshelf.secretName" -}}
{{- .Values.root.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}
