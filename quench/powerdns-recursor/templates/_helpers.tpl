{{- define "powerdns-recursor.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
recursor.yml, built as a dict and rendered with toYaml so every value is
quoted correctly. extraConfig is merged in last, over the generated keys.
*/}}
{{- define "powerdns-recursor.conf" -}}
{{- $auth := list -}}
{{- range $zone, $_ := .Values.authZones -}}
{{- $auth = append $auth (dict "zone" $zone "file" (printf "/etc/powerdns/zones/%s.zone" $zone)) -}}
{{- end -}}
{{- $rec := dict "socket_dir" "/tmp" "daemon" false -}}
{{- with $auth }}{{ $_ := set $rec "auth_zones" . }}{{ end -}}
{{- with .Values.forwardZones }}{{ $_ := set $rec "forward_zones" . }}{{ end -}}
{{- $conf := dict
  "incoming" (dict "listen" (list "0.0.0.0:5353" "[::]:5353") "allow_from" .Values.allowFrom)
  "dnssec" (dict "validation" .Values.dnssec)
  "recursor" $rec
  "logging" (dict "disable_syslog" true "timestamp" false) -}}
{{- toYaml (mergeOverwrite $conf (deepCopy .Values.extraConfig)) -}}
{{- end -}}
