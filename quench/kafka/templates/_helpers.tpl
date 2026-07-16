{{- define "kafka.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "kafka.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The in-cluster client bootstrap address (the client Service fronts all brokers). */}}
{{- define "kafka.advertisedHost" -}}
{{- printf "%s.%s.svc.cluster.local" (include "quench-common.fullname" .) .Release.Namespace -}}
{{- end -}}

{{/* Per-pod stable FQDN suffix under the headless Service: <headless>.<ns>.svc.cluster.local */}}
{{- define "kafka.podDomain" -}}
{{- printf "%s.%s.svc.cluster.local" (include "kafka.headlessName" .) .Release.Namespace -}}
{{- end -}}

{{/* KRaft controller quorum: every pod is a voter. node.id == StatefulSet ordinal. */}}
{{- define "kafka.controllerQuorumVoters" -}}
{{- $full := include "quench-common.fullname" . -}}
{{- $domain := include "kafka.podDomain" . -}}
{{- $voters := list -}}
{{- range $i := until (int .Values.replicaCount) -}}
{{- $voters = append $voters (printf "%d@%s-%d.%s:9093" $i $full $i $domain) -}}
{{- end -}}
{{- join "," $voters -}}
{{- end -}}
