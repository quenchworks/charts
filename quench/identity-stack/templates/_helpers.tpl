{{/*
Common labels for the umbrella's own glue objects. The subcharts label their
own objects via quench-common; these helpers cover the resources this chart
templates directly (the shared-config Secret).
*/}}
{{- define "identity-stack.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: identity-stack
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end -}}

{{/* Fully-qualified names of the subcharts' Services (quench-common fullname ==
     <release>-<chart>, no fullnameOverride). */}}
{{- define "identity-stack.postgresqlName" -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}

{{- define "identity-stack.keycloakName" -}}
{{- printf "%s-keycloak" .Release.Name -}}
{{- end -}}

{{- define "identity-stack.oauth2ProxyName" -}}
{{- printf "%s-oauth2-proxy" .Release.Name -}}
{{- end -}}

{{/* OIDC issuer URL oauth2-proxy points at (Keycloak realm endpoint). Keycloak's
     HTTP service port is 8080 (the chart default; not overridden by this umbrella). */}}
{{- define "identity-stack.oidcIssuerUrl" -}}
{{- $kc := .Values.keycloak | default dict -}}
{{- $svc := $kc.service | default dict -}}
{{- printf "http://%s-keycloak:%v/realms/%s" .Release.Name ($svc.port | default 8080) .Values.shared.oidcRealm -}}
{{- end -}}
