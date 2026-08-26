{{/*
Per-component object names. The Contour control plane owns the release fullname; the
Envoy data plane and the certgen hook get suffixed names of their own.
*/}}
{{- define "contour.envoyName" -}}
{{- printf "%s-envoy" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "contour.certgenName" -}}
{{- printf "%s-certgen" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "contour.serviceAccountName" -}}
{{- include "quench-common.serviceAccountName" . -}}
{{- end -}}

{{/*
Per-component image, resolved strictly by digest (never a tag), matching the
quench-common image contract. Call with a dict:
  {{ include "contour.image" (dict "ctx" . "component" "envoy") }}
*/}}
{{- define "contour.image" -}}
{{- $img := index .ctx.Values.image .component -}}
{{- $repo := required (printf "image.%s.repository is required" .component) $img.repository -}}
{{- $digest := required (printf "image.%s.digest is required (QuenchWorks pins by digest, never a tag)" .component) $img.digest -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}

{{/*
Selector / metadata labels carrying a component label, so the Deployment and the
DaemonSet in one release select their own pods and not each other's.
  {{- include "contour.componentSelectorLabels" (dict "ctx" . "component" "envoy") }}
*/}}
{{- define "contour.componentSelectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "contour.componentLabels" -}}
{{ include "quench-common.labels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
The xDS mTLS Secret names.

`contour certgen --secrets-format=compact --secrets-name-suffix=<s>` writes exactly
two Secrets, named "contourcert<s>" and "envoycert<s>". The suffix is what makes them
release-scoped instead of two releases silently overwriting each other's keypairs;
it is truncated so "contourcert" + suffix stays inside the 63-char name limit.
*/}}
{{- define "contour.certSecretSuffix" -}}
{{- printf "-%s" (include "quench-common.fullname" .) | trunc 50 | trimSuffix "-" -}}
{{- end -}}

{{- define "contour.contourCertSecretName" -}}
{{- if .Values.xdsTLS.contourSecretName -}}
{{- .Values.xdsTLS.contourSecretName -}}
{{- else -}}
{{- printf "contourcert%s" (include "contour.certSecretSuffix" .) -}}
{{- end -}}
{{- end -}}

{{- define "contour.envoyCertSecretName" -}}
{{- if .Values.xdsTLS.envoySecretName -}}
{{- .Values.xdsTLS.envoySecretName -}}
{{- else -}}
{{- printf "envoycert%s" (include "contour.certSecretSuffix" .) -}}
{{- end -}}
{{- end -}}

{{/* Which ConfigMap holds contour.yaml: an external one wins. */}}
{{- define "contour.configMapName" -}}
{{- if .Values.contour.existingConfigMap -}}
{{- .Values.contour.existingConfigMap -}}
{{- else -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* IngressClass name; empty means "Contour's built-in default matching". */}}
{{- define "contour.ingressClassName" -}}
{{- default "contour" .Values.ingressClass.name -}}
{{- end -}}
