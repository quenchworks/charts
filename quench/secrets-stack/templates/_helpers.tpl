{{- define "secrets-stack.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: secrets-stack
{{- end -}}

{{/* The realm's issuer / discovery base: Keycloak's production.hostname, so the
     tokens Keycloak signs and the issuer OpenBao expects are the same string. */}}
{{- define "secrets-stack.issuer" -}}
{{- printf "%s/realms/secrets" (trimSuffix "/" (required "keycloak.production.hostname is required (it is the token issuer)" .Values.keycloak.production.hostname)) -}}
{{- end -}}
