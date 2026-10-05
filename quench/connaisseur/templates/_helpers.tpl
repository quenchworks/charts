{{- define "connaisseur.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Secret holding the webhook CA and serving certificate */}}
{{- define "connaisseur.tlsSecret" -}}
{{- printf "%s-tls" (include "quench-common.fullname" .) -}}
{{- end -}}
