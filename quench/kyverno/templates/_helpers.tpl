{{/*
Per-component object names. Kyverno does not hardcode these: each controller is
told its own Service, Deployment, ServiceAccount and ConfigMap names through env
vars (KYVERNO_SVC, KYVERNO_DEPLOYMENT, KYVERNO_SERVICEACCOUNT_NAME, INIT_CONFIG,
METRICS_CONFIG), so a release-scoped name is safe here and two releases can
coexist. The one thing that is NOT release-scoped is the set of webhook
configurations Kyverno creates at runtime -- those names are compiled into the
binary. See templates/hook-webhook-cleanup.yaml.
*/}}
{{- define "kyverno.admissionName" -}}
{{- printf "%s-admission-controller" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kyverno.backgroundName" -}}
{{- printf "%s-background-controller" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kyverno.cleanupName" -}}
{{- printf "%s-cleanup-controller" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kyverno.reportsName" -}}
{{- printf "%s-reports-controller" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
The Service the API server dials for admission. Its name also becomes the CN/SAN
set of the serving certificate Kyverno generates and the service reference in
every webhook configuration it writes.
*/}}
{{- define "kyverno.serviceName" -}}
{{- printf "%s-svc" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kyverno.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kyverno.metricsConfigMapName" -}}
{{- printf "%s-metrics-config" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Names of the two Secrets the admission controller writes its self-generated CA
and serving keypair into, and the matching pair for the cleanup controller's own
webhook. Kyverno takes these verbatim from --caSecretName / --tlsSecretName; the
"<service>.<namespace>.svc." prefix is upstream's convention and is kept so the
Secret is obviously tied to one Service.
*/}}
{{- define "kyverno.admissionCASecretName" -}}
{{- printf "%s.%s.svc.kyverno-tls-ca" (include "kyverno.serviceName" .) .Release.Namespace -}}
{{- end -}}

{{- define "kyverno.admissionTLSSecretName" -}}
{{- printf "%s.%s.svc.kyverno-tls-pair" (include "kyverno.serviceName" .) .Release.Namespace -}}
{{- end -}}

{{- define "kyverno.cleanupCASecretName" -}}
{{- printf "%s.%s.svc.kyverno-tls-ca" (include "kyverno.cleanupName" .) .Release.Namespace -}}
{{- end -}}

{{- define "kyverno.cleanupTLSSecretName" -}}
{{- printf "%s.%s.svc.kyverno-tls-pair" (include "kyverno.cleanupName" .) .Release.Namespace -}}
{{- end -}}

{{/*
ServiceAccount names -- one per component, so each controller's grants stop at
its own pods. Kyverno also needs two of them by their fully qualified user name:
the admission controller is told which requests come from the background and
reports controllers so it does not evaluate policies against Kyverno's own writes.
*/}}
{{- define "kyverno.admissionServiceAccountName" -}}
{{- if .Values.serviceAccount.create }}{{ include "kyverno.admissionName" . }}{{ else }}default{{ end -}}
{{- end -}}

{{- define "kyverno.backgroundServiceAccountName" -}}
{{- if .Values.serviceAccount.create }}{{ include "kyverno.backgroundName" . }}{{ else }}default{{ end -}}
{{- end -}}

{{- define "kyverno.cleanupServiceAccountName" -}}
{{- if .Values.serviceAccount.create }}{{ include "kyverno.cleanupName" . }}{{ else }}default{{ end -}}
{{- end -}}

{{- define "kyverno.reportsServiceAccountName" -}}
{{- if .Values.serviceAccount.create }}{{ include "kyverno.reportsName" . }}{{ else }}default{{ end -}}
{{- end -}}

{{/*
The image reference, resolved strictly by digest (never a tag), matching the
quench-common image contract. One image for all four controllers.
*/}}
{{- define "kyverno.image" -}}
{{- $repo := required "image.repository is required" .Values.image.repository -}}
{{- $digest := required "image.digest is required (QuenchWorks pins by digest, never a tag)" .Values.image.digest -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}

{{- define "kyverno.cleanupHookImage" -}}
{{- $img := .Values.webhookCleanup.image -}}
{{- $repo := required "webhookCleanup.image.repository is required" $img.repository -}}
{{- $digest := required "webhookCleanup.image.digest is required (QuenchWorks pins by digest, never a tag)" $img.digest -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}

{{/*
Per-component label sets. The component label is what the aggregated ClusterRoles
select on, so it must be exactly one of admission-controller / background-controller
/ cleanup-controller / reports-controller. Call with a dict:
  {{- include "kyverno.componentLabels" (dict "ctx" . "component" "admission-controller") | nindent 4 }}
*/}}
{{- define "kyverno.componentSelectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "kyverno.componentLabels" -}}
{{ include "quench-common.labels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}
