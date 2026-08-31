{{- define "kube-state-metrics.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name for the cluster-scoped RBAC objects. Cluster-scoped names are GLOBAL, so
     it carries the release namespace: two releases in different namespaces would
     otherwise fight over one ClusterRole and the second install would steal the
     first one's binding. */}}
{{- define "kube-state-metrics.clusterRoleName" -}}
{{- printf "%s-%s" (include "quench-common.fullname" .) .Release.Namespace | trunc 63 | trimSuffix "-" -}}
{{- end -}}
