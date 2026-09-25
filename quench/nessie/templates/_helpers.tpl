{{- define "nessie.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "nessie.claimName" -}}
{{- default (printf "%s-data" (include "quench-common.fullname" .)) .Values.rocksdb.persistence.existingClaim -}}
{{- end -}}

{{- define "nessie.validate" -}}
{{- $t := .Values.versionStore.type -}}
{{- if not (has $t (list "IN_MEMORY" "ROCKSDB" "JDBC2")) -}}
{{- fail (printf "versionStore.type must be IN_MEMORY, ROCKSDB or JDBC2, got %q" $t) -}}
{{- end -}}
{{- if and (eq $t "JDBC2") (or (not .Values.jdbc.url) (not .Values.jdbc.existingSecret)) -}}
{{- fail "versionStore.type=JDBC2 needs jdbc.url and jdbc.existingSecret" -}}
{{- end -}}
{{- end -}}
