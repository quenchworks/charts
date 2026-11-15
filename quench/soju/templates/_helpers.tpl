{{/* Every port soju listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "soju.ports" -}}
{{- $p := list (dict "name" "irc" "port" 6667 "servicePort" (int .Values.service.port) "protocol" "TCP") -}}
{{- if include "quench-common.tls.enabled" . -}}
{{- $p = append $p (dict "name" "ircs" "port" 6697 "servicePort" (int .Values.service.tlsPort) "protocol" "TCP") -}}
{{- end -}}
{{- toJson $p -}}
{{- end -}}

{{- define "soju.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "soju.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* soju's config file (soju(1)). The admin socket stays at the image's /tmp default. */}}
{{- define "soju.config" -}}
listen irc+insecure://:6667
{{- if include "quench-common.tls.enabled" . }}
listen ircs://:6697
tls /tls/tls.crt /tls/tls.key
{{- end }}
listen unix+admin://
db sqlite3 /var/lib/soju/main.db
message-store db
hostname {{ required "hostname is required: the bouncer's host name, e.g. bouncer.example.com" .Values.hostname }}
{{- with .Values.title }}
title {{ . | quote }}
{{- end }}
{{- with .Values.extraConfig }}
{{ . }}
{{- end }}
{{- end -}}
