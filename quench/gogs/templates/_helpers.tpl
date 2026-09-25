{{- define "gogs.adminSecretName" -}}
{{- default (include "quench-common.fullname" .) .Values.admin.existingSecret -}}
{{- end -}}

{{- define "gogs.validate" -}}
{{- $t := .Values.database.type -}}
{{- if not (has $t (list "sqlite3" "postgres" "mysql")) -}}
{{- fail (printf "database.type must be sqlite3, postgres or mysql, got %q" $t) -}}
{{- end -}}
{{- if and (ne $t "sqlite3") (or (not .Values.database.host) (not .Values.database.existingSecret)) -}}
{{- fail "an external database needs database.host and database.existingSecret" -}}
{{- end -}}
{{- end -}}
