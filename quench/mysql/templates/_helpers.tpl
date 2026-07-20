{{- define "mysql.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "mysql.rootPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretRootPasswordKey }}{{- else -}}mysql-root-password{{- end -}}
{{- end -}}

{{- define "mysql.passwordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}mysql-password{{- end -}}
{{- end -}}

{{- define "mysql.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "mysql.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Read-only Service name (Group Replication: selects the SECONDARY members). */}}
{{- define "mysql.readonlyName" -}}
{{- printf "%s-readonly" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Per-pod stable FQDN suffix under the headless Service. */}}
{{- define "mysql.podDomain" -}}
{{- printf "%s.%s.svc.cluster.local" (include "mysql.headlessName" .) .Release.Namespace -}}
{{- end -}}

{{/* group_replication_group_seeds — every pod's stable FQDN:33061, comma-separated. */}}
{{- define "mysql.groupSeeds" -}}
{{- $full := include "quench-common.fullname" . -}}
{{- $domain := include "mysql.podDomain" . -}}
{{- $members := list -}}
{{- range $i := until (int .Values.ha.replicaCount) -}}
{{- $members = append $members (printf "%s-%d.%s:33061" $full $i $domain) -}}
{{- end -}}
{{- join "," $members -}}
{{- end -}}

{{/* PDB quorum floor: majority of the group size (N/2 + 1). */}}
{{- define "mysql.haQuorum" -}}
{{- add (div (int .Values.ha.replicaCount) 2) 1 -}}
{{- end -}}
