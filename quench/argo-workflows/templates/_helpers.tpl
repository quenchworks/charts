{{/* Per-component object names, derived from the release fullname. */}}
{{- define "argo-workflows.controllerName" -}}
{{- printf "%s-controller" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "argo-workflows.serverName" -}}
{{- printf "%s-server" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Name of the ConfigMap the controller and the server read their configuration
     from. Both are pointed at it with --configmap, so they always agree. */}}
{{- define "argo-workflows.configMapName" -}}
{{- if .Values.controller.existingConfigMap -}}
{{- .Values.controller.existingConfigMap -}}
{{- else -}}
{{- printf "%s-configmap" (include "argo-workflows.controllerName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* Role granting a workflow pod the right to report its step result. */}}
{{- define "argo-workflows.workflowRoleName" -}}
{{- printf "%s-workflow" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Per-component ServiceAccount names. The controller and the server get one each so
their RBAC is scoped to what that component actually does.
*/}}
{{- define "argo-workflows.controllerServiceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "argo-workflows.controllerName" .) .Values.serviceAccount.controllerName }}{{- else -}}{{ default "default" .Values.serviceAccount.controllerName }}{{- end -}}
{{- end -}}

{{- define "argo-workflows.serverServiceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "argo-workflows.serverName" .) .Values.serviceAccount.serverName }}{{- else -}}{{ default "default" .Values.serviceAccount.serverName }}{{- end -}}
{{- end -}}

{{/*
The executor image handed to the controller as --executor-image.

This is the whole point of the chart's image wiring: without it the controller
falls back to quay.io/argoproj/argoexec:<version>, which QuenchWorks does not
build, and every workflow pod dies on ImagePullBackOff. Defaults to the chart's
own image (one image ships controller + server + argoexec); executor.image.*
overrides it only for the unusual case of a separately shipped executor. Digest
only, never a tag -- same contract as quench-common.image.
*/}}
{{- define "argo-workflows.executorImage" -}}
{{- $repo := .Values.executor.image.repository | default .Values.image.repository -}}
{{- $digest := .Values.executor.image.digest | default .Values.image.digest -}}
{{- $repo = required "executor.image.repository or image.repository is required" $repo -}}
{{- $digest = required "executor.image.digest or image.digest is required (QuenchWorks pins by digest, never a tag)" $digest -}}
{{- with .Values.image.registry -}}
{{- printf "%s/%s@%s" (trimSuffix "/" .) $repo $digest -}}
{{- else -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}
{{- end -}}

{{/*
Per-component selector labels: the shared selector labels plus a component label,
so each Deployment matches only its own pods.
  {{- include "argo-workflows.componentSelectorLabels" (dict "ctx" . "component" "server") }}
*/}}
{{- define "argo-workflows.componentSelectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* Per-component metadata labels: the shared labels plus the component label. */}}
{{- define "argo-workflows.componentLabels" -}}
{{ include "quench-common.labels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
The controller configuration document, rendered into the ConfigMap's `config`
key. Chart-derived defaults first, then .Values.controller.config on top, so an
operator can set artifactRepository / workflowDefaults / persistence / sso
without losing the executor resource settings.

Note that executor.image is NOT written here on purpose: it is passed as the
--executor-image flag, which outranks the ConfigMap, so editing this config can
never silently un-pin the executor image.
*/}}
{{- define "argo-workflows.controllerConfig" -}}
{{- $base := dict -}}
{{- with .Values.executor.resources -}}
{{- $_ := set $base "executor" (dict "resources" .) -}}
{{- end -}}
{{- if gt (int .Values.controller.parallelism) 0 -}}
{{- $_ := set $base "parallelism" (int .Values.controller.parallelism) -}}
{{- end -}}
{{- toYaml (mergeOverwrite $base (deepCopy (.Values.controller.config | default dict))) -}}
{{- end -}}
