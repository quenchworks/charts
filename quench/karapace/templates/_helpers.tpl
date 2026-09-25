{{- define "karapace.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "karapace.selectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* Settings shared by both roles. */}}
{{- define "karapace.env" -}}
- name: KARAPACE_BOOTSTRAP_URI
  value: {{ required "kafka.bootstrapServers is required" .Values.kafka.bootstrapServers | quote }}
- name: KARAPACE_HOST
  value: 0.0.0.0
{{- range $k, $v := .Values.config }}
- name: KARAPACE_{{ $k }}
  value: {{ $v | quote }}
{{- end }}
{{- with .Values.extraEnvVars }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "karapace.envFrom" -}}
{{- with .Values.existingSecret }}
envFrom:
  - secretRef:
      name: {{ . }}
{{- end }}
{{- end -}}
