{{/* SSH, HTTP (smart HTTP and the web UI), the git daemon, and the stats (Prometheus) listener. */}}
{{- define "soft-serve.ports" -}}
{{- $p := .Values.service.ports -}}
{{- toJson (list (dict "name" "ssh" "port" 23231 "servicePort" (int $p.ssh) "protocol" "TCP")
                 (dict "name" "http" "port" 23232 "servicePort" (int $p.http) "protocol" "TCP")
                 (dict "name" "git" "port" 9418 "servicePort" (int $p.git) "protocol" "TCP")
                 (dict "name" "stats" "port" 23233 "servicePort" (int $p.stats) "protocol" "TCP")) -}}
{{- end -}}
