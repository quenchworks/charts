{{/* The GatewayParameters resource this chart creates and points the managed
     GatewayClasses at. Defaults to the release fullname. */}}
{{- define "kgateway.gatewayParametersName" -}}
{{- default (include "quench-common.fullname" .) .Values.dataPlane.gatewayParameters.name -}}
{{- end -}}

{{/* The data-plane image, split into the registry / repository / digest triple the
     GatewayParameters `image` field wants. quench-common.image renders a single
     `repo@digest` string, which this API cannot take. Digest-only, like every other
     QuenchWorks chart; `tag: ""` is emitted alongside it because kgateway couples the
     two fields at merge time -- see the note in gatewayparameters.yaml. */}}
{{- define "kgateway.dataPlaneImage" -}}
{{- $i := .Values.dataPlane.image -}}
{{- $repo := required "dataPlane.image.repository is required" $i.repository -}}
{{- $digest := required "dataPlane.image.digest is required (this chart pins by digest, never by tag)" $i.digest -}}
{{/* Split ghcr.io/quenchworks/images/kgateway-envoy into registry + repository: the API
     keeps them apart and joins them with a single slash. */}}
{{- $parts := splitList "/" $repo -}}
registry: {{ (initial $parts) | join "/" | quote }}
repository: {{ (last $parts) | quote }}
digest: {{ $digest | quote }}
tag: ""
pullPolicy: {{ $i.pullPolicy | default "IfNotPresent" | quote }}
{{- end -}}

{{/* KGW_GATEWAY_CLASS_PARAMETERS_REFS: a JSON map of GatewayClass name ->
     {name, namespace}. The waypoint class only exists when waypoint.enabled is true, so
     referencing it otherwise would be a dangling ref. */}}
{{- define "kgateway.gatewayClassParametersRefs" -}}
{{- $refs := dict -}}
{{- if .Values.dataPlane.gatewayParameters.create -}}
{{- $ref := dict "name" (include "kgateway.gatewayParametersName" .) "namespace" .Release.Namespace -}}
{{- range .Values.dataPlane.gatewayParameters.gatewayClasses -}}
{{- if or (ne . "kgateway-waypoint") $.Values.waypoint.enabled -}}
{{- $_ := set $refs . $ref -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- toJson $refs -}}
{{- end -}}
