{{/*
ServiceAccount names. Each cert-manager component runs as its own ServiceAccount
so its RBAC is scoped to exactly what that component needs (the controller talks
to the issuer/cert API surface, the webhook only authenticates admission reviews,
the cainjector only patches the CA bundle into webhook configs).
*/}}
{{- define "cert-manager.controllerServiceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "cert-manager.controllerName" .) .Values.serviceAccount.controllerName }}{{- else -}}{{ default "default" .Values.serviceAccount.controllerName }}{{- end -}}
{{- end -}}

{{- define "cert-manager.webhookServiceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "cert-manager.webhookName" .) .Values.serviceAccount.webhookName }}{{- else -}}{{ default "default" .Values.serviceAccount.webhookName }}{{- end -}}
{{- end -}}

{{- define "cert-manager.cainjectorServiceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "cert-manager.cainjectorName" .) .Values.serviceAccount.cainjectorName }}{{- else -}}{{ default "default" .Values.serviceAccount.cainjectorName }}{{- end -}}
{{- end -}}

{{/* Per-component resource names, derived from the release fullname. */}}
{{- define "cert-manager.controllerName" -}}
{{- printf "%s-controller" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "cert-manager.webhookName" -}}
{{- printf "%s-webhook" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "cert-manager.cainjectorName" -}}
{{- printf "%s-cainjector" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/*
Name of the Secret the webhook self-fills with its dynamically generated serving
CA + cert. The webhook's --dynamic-serving-ca-secret-name points here, the
cainjector reads it, and the admission-webhook inject annotation references it
(as "<namespace>/<name>").
*/}}
{{- define "cert-manager.webhookCASecretName" -}}
{{- printf "%s-ca" (include "cert-manager.webhookName" .) -}}
{{- end -}}

{{/*
Per-component image references. cert-manager ships four separate binaries/images.
Each is resolved strictly by digest (never a tag), matching the quench-common
image contract. Call with a dict: (dict "ctx" . "component" "controller").
*/}}
{{- define "cert-manager.image" -}}
{{- $img := index .ctx.Values.image .component -}}
{{- $repo := required (printf "image.%s.repository is required" .component) $img.repository -}}
{{- $digest := required (printf "image.%s.digest is required (QuenchWorks pins by digest, never a tag)" .component) $img.digest -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}

{{/*
Per-component selector labels: the shared selectorLabels plus a component label,
so each Deployment's pods are uniquely matched. Call with a dict:
  {{- include "cert-manager.componentSelectorLabels" (dict "ctx" . "component" "controller") }}
*/}}
{{- define "cert-manager.componentSelectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
Per-component metadata labels: the shared labels plus the component label.
  {{- include "cert-manager.componentLabels" (dict "ctx" . "component" "webhook") | nindent 4 }}
*/}}
{{- define "cert-manager.componentLabels" -}}
{{ include "quench-common.labels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}
