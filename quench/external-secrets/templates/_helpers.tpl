{{/*
ServiceAccount name. All three deployments share one ServiceAccount; its RBAC is
the union of what controller/webhook/cert-controller need.
*/}}
{{- define "external-secrets.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Per-component resource names, derived from the release fullname. */}}
{{- define "external-secrets.controllerName" -}}
{{- printf "%s-controller" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "external-secrets.webhookName" -}}
{{- printf "%s-webhook" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "external-secrets.certControllerName" -}}
{{- printf "%s-cert-controller" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/*
Name of the Secret the cert-controller fills with the webhook's TLS material and
the webhook deployment mounts. Same name is referenced by the cert-controller
--secret-name flag and the cert-controller RBAC resourceNames.
*/}}
{{- define "external-secrets.webhookCertSecretName" -}}
{{- include "external-secrets.webhookName" . -}}
{{- end -}}

{{/*
Per-component selector labels: the shared selectorLabels plus a component label,
so each Deployment's pods are uniquely matched. Call with a dict:
  {{- include "external-secrets.componentSelectorLabels" (dict "ctx" . "component" "controller") }}
*/}}
{{- define "external-secrets.componentSelectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
Per-component metadata labels: the shared labels plus the component label.
  {{- include "external-secrets.componentLabels" (dict "ctx" . "component" "webhook") | nindent 4 }}
*/}}
{{- define "external-secrets.componentLabels" -}}
{{ include "quench-common.labels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}
