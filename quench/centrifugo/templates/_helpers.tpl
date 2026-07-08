{{- define "centrifugo.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the Secret holding Centrifugo credentials: an external one wins, else
     the chart-managed Secret. */}}
{{- define "centrifugo.secretName" -}}
{{- if .Values.secrets.existingSecret -}}{{ .Values.secrets.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{/* Secret data keys. For a chart-managed Secret they are fixed; with an
     existingSecret they come from .Values.secrets.keys so you can map your own. */}}
{{- define "centrifugo.tokenHmacKey" -}}
{{- if .Values.secrets.existingSecret -}}{{ .Values.secrets.keys.tokenHmacSecretKey }}{{- else -}}token-hmac-secret-key{{- end -}}
{{- end -}}
{{- define "centrifugo.apiKeyKey" -}}
{{- if .Values.secrets.existingSecret -}}{{ .Values.secrets.keys.apiKey }}{{- else -}}http-api-key{{- end -}}
{{- end -}}
{{- define "centrifugo.adminPasswordKey" -}}
{{- if .Values.secrets.existingSecret -}}{{ .Values.secrets.keys.adminPassword }}{{- else -}}admin-password{{- end -}}
{{- end -}}
{{- define "centrifugo.adminSecretKey" -}}
{{- if .Values.secrets.existingSecret -}}{{ .Values.secrets.keys.adminSecret }}{{- else -}}admin-secret{{- end -}}
{{- end -}}

{{/*
Resolve a credential the chart manages: explicit value wins, else reuse the value
already stored in the managed Secret (preserve across upgrades, so `helm upgrade`
never rotates live credentials), else generate a 40-char random one. Returns the
plaintext value. Only used when secrets.existingSecret is unset (otherwise the
chart does not own the Secret). Call with:
  {{ include "centrifugo.resolveSecret" (dict "ctx" . "key" "http-api-key" "explicit" .Values.secrets.apiKey) }}
*/}}
{{- define "centrifugo.resolveSecret" -}}
{{- $ctx := .ctx -}}
{{- $key := .key -}}
{{- $val := .explicit -}}
{{- $len := .len | default 40 -}}
{{- $name := include "quench-common.fullname" $ctx -}}
{{- $existing := lookup "v1" "Secret" $ctx.Release.Namespace $name -}}
{{- if and (not $val) $existing (hasKey ($existing.data | default dict) $key) -}}
{{- $val = index $existing.data $key | b64dec -}}
{{- end -}}
{{- if not $val -}}
{{- $val = randAlphaNum $len -}}
{{- end -}}
{{- $val -}}
{{- end -}}
