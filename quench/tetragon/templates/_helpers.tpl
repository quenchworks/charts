{{- define "tetragon.selectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "tetragon.agentName" -}}
{{- printf "%s-agent" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "tetragon.operatorName" -}}
{{- printf "%s-operator" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "tetragon.image" -}}
{{- printf "%s@%s" .repository .digest -}}
{{- end -}}

{{/*
Agent options, one file per flag in /etc/tetragon/tetragon.conf.d (Tetragon's
--config-dir format). gRPC listens on localhost only: tetra runs inside the
pod (kubectl exec), and the port gives the host nothing to reach.
*/}}
{{- define "tetragon.agentConfig" -}}
{{- $a := .Values.agent -}}
{{- $c := dict
  "cluster-name" $a.clusterName
  "procfs" "/procRoot"
  "server-address" "localhost:54321"
  "health-server-address" ":6789"
  "health-server-interval" "10"
  "metrics-server" (ternary (printf ":%v" $a.metricsPort) "" (gt (int $a.metricsPort) 0))
  "enable-k8s-api" (toString $a.enableK8sApi)
  "enable-process-cred" (toString $a.enableProcessCred)
  "enable-process-ns" (toString $a.enableProcessNs)
  "enable-policy-filter" (toString $a.enableK8sApi)
  "enable-tracing-policy-crd" (toString (and $a.enableK8sApi .Values.operator.enabled))
  "enable-pod-info" "false"
  "keep-sensors-on-exit" "true" -}}
{{- toYaml (mergeOverwrite $c (deepCopy $a.extraConfig)) -}}
{{- end -}}
