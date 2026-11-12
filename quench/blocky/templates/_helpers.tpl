{{/* Every port Blocky listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "blocky.ports" -}}
{{- $p := list -}}
{{- $p = append $p (dict "name" "dns" "port" 5353 "servicePort" (int .Values.service.dnsPort) "protocol" "UDP") -}}
{{- $p = append $p (dict "name" "dns-tcp" "port" 5353 "servicePort" (int .Values.service.dnsPort) "protocol" "TCP") -}}
{{- $p = append $p (dict "name" "http" "port" 4000 "servicePort" 4000 "protocol" "TCP") -}}
{{- if .Values.tls.enabled }}
{{- $p = append $p (dict "name" "dot" "port" 8853 "servicePort" (int .Values.service.dotPort) "protocol" "TCP") -}}
{{- $p = append $p (dict "name" "doh" "port" 8443 "servicePort" (int .Values.service.dohPort) "protocol" "TCP") -}}
{{- end -}}
{{- toJson $p -}}
{{- end -}}

{{/* config.yml: the user's config with the listeners and TLS files the chart owns laid over it. */}}
{{- define "blocky.config" -}}
{{- $ports := dict "dns" 5353 "http" 4000 -}}
{{- if .Values.tls.enabled }}{{ $_ := set $ports "tls" 8853 }}{{ $_ := set $ports "https" 8443 }}{{ end -}}
{{- $own := dict "ports" $ports -}}
{{- if .Values.tls.enabled }}{{ $_ := set $own "certFile" "/tls/tls.crt" }}{{ $_ := set $own "keyFile" "/tls/tls.key" }}{{ end -}}
{{- toYaml (mergeOverwrite (deepCopy .Values.config) $own) -}}
{{- end -}}
