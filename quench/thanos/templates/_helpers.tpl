{{/*
Per-component fullname: "<release>-thanos-<component>".
Call with a dict: {{ include "thanos.componentFullname" (dict "ctx" . "component" "query") }}
*/}}
{{- define "thanos.componentFullname" -}}
{{- printf "%s-%s" (include "quench-common.fullname" .ctx) .component -}}
{{- end -}}

{{/*
Headless Service name for a component (used for DNS SRV discovery / StatefulSet
governance): "<release>-thanos-<component>-headless".
*/}}
{{- define "thanos.componentHeadlessName" -}}
{{- printf "%s-%s-headless" (include "quench-common.fullname" .ctx) .component -}}
{{- end -}}

{{/*
Common labels for a component: the shared quench-common labels PLUS the
app.kubernetes.io/component dimension so each workload's objects are distinct.
Call with a dict: {{ include "thanos.componentLabels" (dict "ctx" . "component" "query") }}
*/}}
{{- define "thanos.componentLabels" -}}
{{ include "quench-common.labels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
Selector labels for a component: the shared selectorLabels PLUS the component
dimension. These MUST be a stable subset of componentLabels.
*/}}
{{- define "thanos.componentSelectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
ServiceAccount name (one SA shared by all component workloads).
*/}}
{{- define "thanos.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Name of the objstore Secret (chart-rendered).
*/}}
{{- define "thanos.objstoreSecretName" -}}
{{- printf "%s-objstore" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/*
Whether an objstore config is in play (inline yaml or an external Secret).
*/}}
{{- define "thanos.hasObjstore" -}}
{{- if or .Values.objstoreConfig.existingSecret .Values.objstoreConfig.yaml -}}true{{- end -}}
{{- end -}}

{{/*
Which objstore Secret to mount: an external one wins, else the chart-rendered one.
*/}}
{{- define "thanos.objstoreSecret" -}}
{{- if .Values.objstoreConfig.existingSecret -}}{{ .Values.objstoreConfig.existingSecret }}{{- else -}}{{ include "thanos.objstoreSecretName" . }}{{- end -}}
{{- end -}}

{{/*
Whether the chart should render its own objstore Secret (inline yaml set AND no
external Secret provided) AND a component that consumes it is enabled.
*/}}
{{- define "thanos.renderObjstoreSecret" -}}
{{- if and .Values.objstoreConfig.yaml (not .Values.objstoreConfig.existingSecret) -}}
{{- if or .Values.store.enabled .Values.compact.enabled .Values.rule.enabled (and .Values.receive.enabled .Values.receive.objstore.enabled) -}}true{{- end -}}
{{- end -}}
{{- end -}}

{{/*
The gRPC Store API endpoint query uses to discover receive: a DNS SRV lookup
against receive's headless Service. Resolves all receive replicas.
*/}}
{{- define "thanos.receiveEndpoint" -}}
{{- printf "dnssrv+_grpc._tcp.%s.%s.svc.cluster.local" (include "thanos.componentHeadlessName" (dict "ctx" . "component" "receive")) .Release.Namespace -}}
{{- end -}}
