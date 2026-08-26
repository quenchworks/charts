{{/* Per-component object names, derived from the release fullname. */}}
{{- define "tekton.controllerName" -}}
{{- printf "%s-controller" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tekton.webhookName" -}}
{{- printf "%s-webhook" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Secret the webhook fills with its self-generated serving CA + leaf certificate.
The chart creates it EMPTY: the webhook has get/update on it (never create) and
populates it on first start, then patches the same CA into the caBundle of the
three webhook configurations and of the CRD conversion stanzas.
*/}}
{{- define "tekton.webhookCertsSecretName" -}}
{{- printf "%s-certs" (include "tekton.webhookName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tekton.controllerServiceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "tekton.controllerName" .) .Values.serviceAccount.controllerName }}{{- else -}}{{ default "default" .Values.serviceAccount.controllerName }}{{- end -}}
{{- end -}}

{{- define "tekton.webhookServiceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "tekton.webhookName" .) .Values.serviceAccount.webhookName }}{{- else -}}{{ default "default" .Values.serviceAccount.webhookName }}{{- end -}}
{{- end -}}

{{/*
Per-component label sets: the shared quench-common labels/selectorLabels plus a
component label, so each Deployment matches only its own pods.
  {{- include "tekton.componentLabels" (dict "ctx" . "component" "controller") | nindent 4 }}
*/}}
{{- define "tekton.componentSelectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "tekton.componentLabels" -}}
{{ include "quench-common.labels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
The shell image used for the injected `place-scripts` init container, strictly by
digest like every other image reference in this chart.
*/}}
{{- define "tekton.shellImage" -}}
{{- $repo := required "shellImage.repository is required" .Values.shellImage.repository -}}
{{- $digest := required "shellImage.digest is required (QuenchWorks pins by digest, never a tag)" .Values.shellImage.digest -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}

{{/*
The three admission-controller names Tekton derives from
webhook.admissionControllerName. The webhook binary computes them itself, so the
webhook configurations MUST be named exactly this or the webhook will never find
(and therefore never inject a caBundle into) them.
*/}}
{{- define "tekton.mutatingWebhookName" -}}
{{- .Values.webhook.admissionControllerName -}}
{{- end -}}

{{- define "tekton.validatingWebhookName" -}}
{{- printf "validation.%s" .Values.webhook.admissionControllerName -}}
{{- end -}}

{{- define "tekton.configWebhookName" -}}
{{- printf "config.%s" .Values.webhook.admissionControllerName -}}
{{- end -}}
