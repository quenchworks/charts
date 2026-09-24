{{/* Component selector labels: quench-common's selector plus the MetalLB component. */}}
{{- define "metallb.selectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "metallb.controllerName" -}}
{{- printf "%s-controller" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "metallb.speakerName" -}}
{{- printf "%s-speaker" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Memberlist key Secret. The controller creates it; the speakers mount it. */}}
{{- define "metallb.memberlistSecret" -}}
{{- printf "%s-memberlist" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "metallb.image" -}}
{{- printf "%s@%s" .repository .digest -}}
{{- end -}}
