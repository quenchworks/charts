{{- define "flink.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "flink.selectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* The jobmanager Service name: taskmanagers and clients reach the cluster through it. */}}
{{- define "flink.jobmanager" -}}
{{- printf "%s-jobmanager" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* FLINK_PROPERTIES shared by both roles: memory, slots and anything in flinkProperties. */}}
{{- define "flink.properties" -}}
{{- $role := .role -}}
{{- $v := .ctx.Values -}}
{{- if eq $role "jobmanager" }}
jobmanager.memory.process.size: {{ $v.jobmanager.memoryProcessSize }}
{{- else }}
taskmanager.memory.process.size: {{ $v.taskmanager.memoryProcessSize }}
taskmanager.numberOfTaskSlots: {{ $v.taskmanager.numberOfTaskSlots }}
taskmanager.host: $(POD_IP)
taskmanager.rpc.port: 6122
{{- end }}
{{- range $k, $val := $v.flinkProperties }}
{{ $k }}: {{ $val }}
{{- end }}
{{- end -}}
