{{/* The one port: ZAP's API and proxy share it. */}}
{{- define "zap.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "zap.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* ZAP serves its API only to requests addressed to itself; any other Host is proxied. The Service's DNS names (and
     extraAliases, e.g. an Ingress host) are registered as aliases so in-cluster clients reach the API. */}}
{{- define "zap.aliases" -}}
{{- $f := include "quench-common.fullname" . -}}
{{- $ns := .Release.Namespace -}}
{{- toJson (concat (list $f (printf "%s.%s" $f $ns) (printf "%s.%s.svc" $f $ns) (printf "%s.%s.svc.cluster.local" $f $ns)) .Values.extraAliases) -}}
{{- end -}}

{{- define "zap.args" -}}
- -daemon
- -host
- 0.0.0.0
- -port
- "8080"
- -dir
- /home/zap/.ZAP
- -config
- start.checkForUpdates=false
- -config
- start.checkAddonUpdates=false
- -config
- api.key=$(ZAP_API_KEY)
- -config
- api.addrs.addr.name={{ .Values.api.allowedAddresses }}
- -config
- api.addrs.addr.regex=true
{{- range $i, $a := (include "zap.aliases" . | fromJsonArray) }}
- -config
- {{ printf "network.localServers.aliases.alias(%d).name=%s" $i $a | quote }}
{{- end }}
{{- range .Values.extraConfig }}
- -config
- {{ . | quote }}
{{- end }}
{{- end -}}
