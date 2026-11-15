{{/* The relay ports, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy.
     croc clients dial the first port and are handed the others, so the Service keeps the same numbers. */}}
{{- define "croc.ports" -}}
{{- $l := list }}
{{- range $i := until (int .Values.relay.portCount) }}
{{- $p := add $.Values.relay.basePort $i }}
{{- $l = append $l (dict "name" (printf "relay-%d" $i) "port" $p "servicePort" $p "protocol" "TCP") }}
{{- end }}
{{- toJson $l -}}
{{- end -}}

{{- define "croc.secretName" -}}
{{- .Values.relay.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* "9009,9010,..." for CROC_PORTS */}}
{{- define "croc.portList" -}}
{{- $l := list }}
{{- range (include "croc.ports" . | fromJsonArray) }}{{ $l = append $l (printf "%v" .port) }}{{ end }}
{{- join "," $l -}}
{{- end -}}
