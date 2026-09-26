{{- define "mariadb-operator.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* repository@digest for an images.* entry. */}}
{{- define "mariadb-operator.ref" -}}
{{- printf "%s@%s" .repository .digest -}}
{{- end -}}
