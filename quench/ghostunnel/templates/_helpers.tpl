{{/* Every port ghostunnel listens on, as {name, port, protocol}: container, Service and NetworkPolicy. */}}
{{- define "ghostunnel.ports" -}}
{{- $p := list (dict "name" "tunnel" "port" (int .Values.port) "protocol" "TCP") -}}
{{- if .Values.status.enabled }}{{ $p = append $p (dict "name" "status" "port" (int .Values.status.port) "protocol" "TCP") }}{{ end -}}
{{- toJson $p -}}
{{- end -}}

{{/* The Secret holding the CA that signs accepted client certificates (key ca.crt). */}}
{{- define "ghostunnel.clientCASecret" -}}
{{- .Values.clientCA.existingSecret | default (printf "%s-client" (include "quench-common.fullname" .)) -}}
{{- end -}}

{{/* CN of the client certificate the chart generates. */}}
{{- define "ghostunnel.clientCN" -}}
{{- printf "%s-client" (include "quench-common.fullname" .) -}}
{{- end -}}
