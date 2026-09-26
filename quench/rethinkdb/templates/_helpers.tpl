{{- define "rethinkdb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "rethinkdb.secretName" -}}
{{- default (include "quench-common.fullname" .) .Values.auth.existingSecret -}}
{{- end -}}
