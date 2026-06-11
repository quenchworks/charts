{{/*
Quenchworks common helpers. App charts include these through the quench-common dependency.
The contract with the image factory lives in "quench-common.image": charts reference images
only by repository and digest, never a mutable tag.
*/}}

{{- define "quench-common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "quench-common.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "quench-common.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "quench-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: quenchworks
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end -}}

{{- define "quench-common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "quench-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Resolve the image strictly by digest. .Values.image.digest is required.
Refusing a tag-only reference is deliberate: it guarantees the deployed artifact is exactly
the one the image factory scanned and signed.
*/}}
{{- define "quench-common.image" -}}
{{- $repo := required "image.repository is required" .Values.image.repository -}}
{{- $digest := required "image.digest is required (Quenchworks pins by digest, never a tag)" .Values.image.digest -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}
