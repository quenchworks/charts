{{- define "sealed-secrets.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Cluster-scoped RBAC names are suffixed with the namespace: ClusterRoles are
     global, so two releases in different namespaces must not collide. */}}
{{- define "sealed-secrets.unsealerName" -}}
{{- printf "%s-%s-unsealer" (include "quench-common.fullname" .) .Release.Namespace | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Namespaced Role guarding create/list on the sealing-key Secrets. */}}
{{- define "sealed-secrets.keyAdminName" -}}
{{- printf "%s-key-admin" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Namespaced Role letting authenticated users proxy to the controller Service
     so `kubeseal` can fetch the public sealing certificate. */}}
{{- define "sealed-secrets.serviceProxierName" -}}
{{- printf "%s-service-proxier" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
