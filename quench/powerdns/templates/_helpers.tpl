{{- define "powerdns.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "powerdns.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "powerdns.apiSecretName" -}}
{{- default (include "quench-common.fullname" .) .Values.api.existingSecret -}}
{{- end -}}

{{/*
pdns.conf without secrets. The API key comes from the Secret as the env var
PDNS_API_KEY, which the container args expand into --api-key. It is never in
the ConfigMap, and `kubectl describe` shows only $(PDNS_API_KEY).
*/}}
{{- define "powerdns.conf" -}}
launch=lmdb
lmdb-filename=/var/lib/powerdns/pdns.lmdb
local-address=0.0.0.0:5353, [::]:5353
socket-dir=/tmp
guardian=no
daemon=no
disable-syslog=yes
log-timestamp=no
write-pid=no
{{- if .Values.api.enabled }}
api=yes
webserver=yes
webserver-address=0.0.0.0
webserver-port=8081
webserver-allow-from={{ join "," .Values.api.allowFrom }}
{{- end }}
{{- with .Values.extraConfig }}
{{ . }}
{{- end }}
{{- end -}}
