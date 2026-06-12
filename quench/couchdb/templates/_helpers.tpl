{{/* Secret holding the admin password, Erlang cookie and proxy/cookie-auth secret */}}
{{- define "couchdb.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "couchdb.secretPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}adminPassword{{- end -}}
{{- end -}}

{{- define "couchdb.secretCookieKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretCookieKey }}{{- else -}}cookieAuthSecret{{- end -}}
{{- end -}}

{{- define "couchdb.secretErlangCookieKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretErlangCookieKey }}{{- else -}}erlangCookie{{- end -}}
{{- end -}}

{{- define "couchdb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service name for the StatefulSet */}}
{{- define "couchdb.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}
