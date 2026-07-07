{{- define "spicedb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the Secret holding the gRPC preshared key. An external Secret wins. */}}
{{- define "spicedb.secretName" -}}
{{- if .Values.grpcPresharedKey.existingSecret -}}{{ .Values.grpcPresharedKey.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{/* Key within the Secret that holds the preshared key. */}}
{{- define "spicedb.secretKey" -}}
{{- if .Values.grpcPresharedKey.existingSecret -}}{{ .Values.grpcPresharedKey.existingSecretKey }}{{- else -}}preshared-key{{- end -}}
{{- end -}}

{{/* Resolve the preshared key: explicit value wins; else reuse the value already
     stored in the managed Secret (preserved across upgrades); else generate one. */}}
{{- define "spicedb.presharedKey" -}}
{{- $name := include "quench-common.fullname" . -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $name -}}
{{- $key := .Values.grpcPresharedKey.value -}}
{{- if and (not $key) $existing -}}
{{- $key = index $existing.data "preshared-key" | b64dec -}}
{{- end -}}
{{- if not $key -}}
{{- $key = randAlphaNum 32 -}}
{{- end -}}
{{- $key -}}
{{- end -}}
