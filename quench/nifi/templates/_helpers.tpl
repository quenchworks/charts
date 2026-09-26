{{- define "nifi.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "nifi.secretName" -}}
{{- default (printf "%s-auth" (include "quench-common.fullname" .)) .Values.auth.existingSecret -}}
{{- end -}}

{{/* Host names NiFi accepts in the Host header (nifi.web.proxy.host). */}}
{{- define "nifi.proxyHosts" -}}
{{- $f := include "quench-common.fullname" . -}}
{{- $hosts := list (printf "%s:8443" $f) (printf "%s.%s:8443" $f .Release.Namespace) (printf "%s.%s.svc:8443" $f .Release.Namespace) (printf "%s.%s.svc.cluster.local:8443" $f .Release.Namespace) "localhost:8443" -}}
{{- join "," (concat $hosts .Values.proxyHosts) -}}
{{- end -}}
