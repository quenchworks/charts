{{- define "kuberay.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* featureGates as a map (Name: true) rendered to the flag's k=v,k=v form. */}}
{{- define "kuberay.featureGates" -}}
{{- $out := list -}}
{{- range $k, $v := .Values.featureGates }}{{ $out = append $out (printf "%s=%v" $k $v) }}{{ end -}}
{{- join "," $out -}}
{{- end -}}
