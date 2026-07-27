{{- define "crossplane.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* The RBAC manager runs under its own ServiceAccount: it holds `escalate` and `bind`
     on ClusterRoles, which the core control plane must not have. */}}
{{- define "crossplane.rbacManagerName" -}}
{{- printf "%s-rbac-manager" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Base for the cluster-scoped RBAC names. Deliberately NOT namespace-suffixed the way
     the other Quenchworks charts do it: the release name is already in fullname, and the
     only thing a namespace suffix would disambiguate is two same-named releases in
     different namespaces -- which cannot work for Crossplane anyway, since its CRDs,
     webhook configurations and aggregation labels are all cluster-global. Skipping it
     keeps these names (the longest is "-allowed-provider-permissions") well clear of the
     63-character truncation that would otherwise mangle them. */}}
{{- define "crossplane.clusterRoleName" -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}

{{- define "crossplane.rbacManagerClusterRoleName" -}}
{{- printf "%s-rbac-manager" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Namespace Crossplane unpacks and runs packages in. It must be the release namespace
     unless the operator deliberately points it elsewhere: the TLS Secrets this chart
     creates and the package-runtime Deployments both live there. */}}
{{- define "crossplane.namespace" -}}
{{- default .Release.Namespace .Values.core.namespace -}}
{{- end -}}

{{/* Names of the three Secrets `crossplane core init` fills with the CA it generates and
     the server/client certificates derived from it. Created empty by this chart so Helm
     owns their lifecycle (and so the pod's secret volumes resolve on first start). */}}
{{- define "crossplane.tlsCASecret" -}}{{ include "quench-common.fullname" . }}-root-ca{{- end -}}
{{- define "crossplane.tlsServerSecret" -}}{{ include "quench-common.fullname" . }}-tls-server{{- end -}}
{{- define "crossplane.tlsClientSecret" -}}{{ include "quench-common.fullname" . }}-tls-client{{- end -}}

{{/* The `core init` container and the control plane share every environment variable that
     names a Secret, a Service or the namespace, so they are defined once here. */}}
{{- define "crossplane.commonEnv" -}}
- name: POD_NAMESPACE
  value: {{ include "crossplane.namespace" . | quote }}
- name: POD_SERVICE_ACCOUNT
  value: {{ include "crossplane.serviceAccountName" . | quote }}
- name: TLS_CA_SECRET_NAME
  value: {{ include "crossplane.tlsCASecret" . | quote }}
- name: TLS_SERVER_SECRET_NAME
  value: {{ include "crossplane.tlsServerSecret" . | quote }}
- name: TLS_CLIENT_SECRET_NAME
  value: {{ include "crossplane.tlsClientSecret" . | quote }}
{{- if .Values.core.webhooks.enabled }}
- name: WEBHOOK_SERVICE_NAME
  value: {{ include "quench-common.fullname" . | quote }}
- name: WEBHOOK_SERVICE_NAMESPACE
  value: {{ .Release.Namespace | quote }}
- name: WEBHOOK_SERVICE_PORT
  value: {{ .Values.service.port | quote }}
{{- else }}
- name: ENABLE_WEBHOOKS
  value: "false"
{{- end }}
{{- end -}}
