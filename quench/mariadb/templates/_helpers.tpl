{{- define "mariadb.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "mariadb.rootPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretRootPasswordKey }}{{- else -}}mariadb-root-password{{- end -}}
{{- end -}}

{{- define "mariadb.passwordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}mariadb-password{{- end -}}
{{- end -}}

{{- define "mariadb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "mariadb.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}
