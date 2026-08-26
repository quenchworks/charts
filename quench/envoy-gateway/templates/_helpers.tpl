{{/* ConfigMap holding the EnvoyGateway config file mounted at /config. */}}
{{- define "envoy-gateway.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The Envoy data-plane image, by digest. Empty when the digest is cleared, in
     which case the chart leaves the image Envoy Gateway ships with in place. */}}
{{- define "envoy-gateway.envoyProxyImage" -}}
{{- $i := .Values.envoyProxy.image | default dict -}}
{{- if $i.digest -}}
{{- with $i.registry -}}{{ printf "%s/" (trimSuffix "/" .) }}{{- end -}}
{{- printf "%s@%s" (required "envoyProxy.image.repository is required when envoyProxy.image.digest is set" $i.repository) $i.digest -}}
{{- end -}}
{{- end -}}

{{/*
The EnvoyGateway config file (spec of the `EnvoyGateway` kind, minus apiVersion
and kind, which the ConfigMap writes itself).

The chart owns four things -- the GatewayClass controllerName, the log level, the
two QuenchWorks images the controller injects into the workloads it provisions,
and the topology injector switch. Everything else is the operator's, via
.Values.config, which is deep-merged LAST so it can override any of them.

proxyTopologyInjector is disabled unconditionally: it is a pod-scheduling
optimisation implemented as a cluster-wide MutatingWebhookConfiguration on pod
creation, and this chart deliberately installs no admission webhook. Re-enabling
it through .Values.config alone would point the API server at a webhook that does
not exist and break pod creation, so don't.
*/}}
{{- define "envoy-gateway.config" -}}
{{- $kube := dict "shutdownManager" (dict "image" (include "quench-common.image" .)) -}}
{{- $cfg := dict
      "gateway" (dict "controllerName" .Values.controllerName)
      "logging" (dict "level" (dict "default" .Values.logLevel))
      "provider" (dict "type" "Kubernetes" "kubernetes" $kube)
      "proxyTopologyInjector" (dict "disabled" true) -}}
{{- with (include "envoy-gateway.envoyProxyImage" .) -}}
{{- $_ := set $cfg "envoyProxy" (dict "provider" (dict "type" "Kubernetes" "kubernetes"
      (dict "envoyDeployment" (dict "container" (dict "image" .))))) -}}
{{- end -}}
{{- toYaml (mergeOverwrite $cfg (deepCopy (.Values.config | default dict))) -}}
{{- end -}}
