{{- define "falco.image" -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- end -}}

{{/* falco.yaml, rendered from .Values.config. */}}
{{- define "falco.config" -}}
{{- toYaml .Values.config -}}
{{- end -}}
