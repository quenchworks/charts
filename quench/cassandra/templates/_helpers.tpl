{{- define "cassandra.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service used for stable pod DNS + gossip */}}
{{- define "cassandra.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/*
CASSANDRA_SEEDS: comma-list of the first N seed pods' stable headless DNS.
N = min(config.seedCount, replicaCount), at least 1. Each entry is
<fullname>-<ordinal>.<headless>.<namespace>.svc.cluster.local
*/}}
{{- define "cassandra.seeds" -}}
{{- $full := include "quench-common.fullname" . -}}
{{- $headless := include "cassandra.headlessName" . -}}
{{- $ns := .Release.Namespace -}}
{{- $count := int .Values.config.seedCount -}}
{{- if lt $count 1 }}{{- $count = 1 -}}{{- end -}}
{{- if gt $count (int .Values.replicaCount) }}{{- $count = int .Values.replicaCount -}}{{- end -}}
{{- $seeds := list -}}
{{- range $i := until $count -}}
{{- $seeds = append $seeds (printf "%s-%d.%s.%s.svc.cluster.local" $full $i $headless $ns) -}}
{{- end -}}
{{- join "," $seeds -}}
{{- end -}}
