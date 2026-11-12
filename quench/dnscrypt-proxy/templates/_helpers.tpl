{{/* Every port dnscrypt-proxy listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "dnscrypt-proxy.ports" -}}
{{- $p := list -}}
{{- $p = append $p (dict "name" "dns" "port" 5353 "servicePort" (int .Values.service.dnsPort) "protocol" "UDP") -}}
{{- $p = append $p (dict "name" "dns-tcp" "port" 5353 "servicePort" (int .Values.service.dnsPort) "protocol" "TCP") -}}
{{- toJson $p -}}
{{- end -}}

{{/* Helm reads YAML numbers as floats and toToml writes 4096 as 4096.0, which dnscrypt-proxy's
     integer settings reject: turn whole-number floats back into integers, in place, at any depth. */}}
{{- define "dnscrypt-proxy.ints" -}}
{{- range $k, $v := . -}}
{{- if and (kindIs "float64" $v) (eq $v (float64 (int64 $v))) -}}{{- $_ := set $ $k (int64 $v) -}}
{{- else if kindIs "map" $v -}}{{- include "dnscrypt-proxy.ints" $v -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* dnscrypt-proxy.toml: the user's config with the listener the chart owns laid over it. */}}
{{- define "dnscrypt-proxy.config" -}}
{{- $c := mergeOverwrite (deepCopy .Values.config) (dict "listen_addresses" (list "0.0.0.0:5353")) -}}
{{- include "dnscrypt-proxy.ints" $c -}}
{{- toToml $c -}}
{{- end -}}
