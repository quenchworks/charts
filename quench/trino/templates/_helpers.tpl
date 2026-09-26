{{- define "trino.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Coordinator and workers share the release's selector labels; the component
     label tells them apart. The Service selects the coordinator only. */}}
{{- define "trino.componentLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* The JVM sizes its heap from the container limit (MaxRAMPercentage), so the
     memory settings are a share of that limit rather than fixed sizes. */}}
{{- define "trino.jvmConfig" -}}
-server
-XX:InitialRAMPercentage={{ .Values.jvm.ramPercentage }}
-XX:MaxRAMPercentage={{ .Values.jvm.ramPercentage }}
-XX:G1HeapRegionSize=32M
-XX:+ExplicitGCInvokesConcurrent
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/data/trino
-XX:+ExitOnOutOfMemoryError
-XX:-OmitStackTraceInFastThrow
-XX:ReservedCodeCacheSize=256M
-XX:PerMethodRecompilationCutoff=10000
-XX:PerBytecodeRecompilationCutoff=10000
-Djdk.attach.allowAttachSelf=true
-Djdk.nio.maxCachedBufferSize=2000000
-Djava.io.tmpdir=/tmp
{{- range .Values.jvm.extraOptions }}
{{ . }}
{{- end }}
{{- end -}}
