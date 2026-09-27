{{- define "squid.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "squid.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "squid.mountedConfigMap" -}}
{{- if .Values.config.existingConfigMap -}}{{ .Values.config.existingConfigMap }}{{- else -}}{{ include "squid.configMapName" . }}{{- end -}}
{{- end -}}

{{/*
The effective squid.conf: `config.raw` verbatim, else one generated from values.

The probes GET /squid-internal-static/icons/SN.png, which squid serves from
memory, and http_access applies to it. The kubelet probes from the node IP, so
allowedSources must cover the node CIDR. There is deliberately no "allow this
path from anywhere" ACL: a urlpath ACL also matches proxied requests to any
host with that path, which would make the proxy an open relay.
*/}}
{{- define "squid.conf" -}}
{{- if .Values.config.raw -}}
{{ .Values.config.raw }}
{{- else -}}
{{- range .Values.allowedSources }}
acl localnet src {{ . }}
{{- end }}
{{- range .Values.sslPorts }}
acl SSL_ports port {{ . }}
{{- end }}
{{- range .Values.safePorts }}
acl Safe_ports port {{ . }}
{{- end }}

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access deny to_localhost
http_access deny to_linklocal
http_access allow localnet
http_access allow localhost
{{- with .Values.extraConfig }}

{{ . }}
{{- end }}
http_access deny all

http_port 3128

cache_mem {{ .Values.cacheMem }}
# squid sizes its descriptor tables from the fd limit, and containerd's is
# about a billion: without a cap the pod is OOMKilled before it logs a line.
max_filedescriptors 65536
pid_filename none
# The kubelet probes every 10s; keep them out of the access log. This ACL only
# filters logging, it grants nothing.
acl kubelet_probe urlpath_regex ^/squid-internal-static/icons/SN\.png$
access_log stdio:/dev/stdout !kubelet_probe
cache_log /dev/stderr
cache_store_log none
logfile_rotate 0
coredump_dir /tmp
shutdown_lifetime 5 seconds

refresh_pattern ^ftp:             1440 20% 10080
refresh_pattern -i (/cgi-bin/|\?) 0    0%  0
refresh_pattern .                 0    20% 4320
{{- end -}}
{{- end -}}
