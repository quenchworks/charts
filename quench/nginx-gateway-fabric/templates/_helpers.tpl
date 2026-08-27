{{/*
The NginxGateway resource: dynamic control-plane configuration (log level), passed to
the binary as --config and re-read at runtime.
*/}}
{{- define "nginx-gateway-fabric.configName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/*
The NginxProxy resource: the DATA PLANE's configuration, referenced by the GatewayClass
as parametersRef. A GatewayClass with no parametersRef falls back to NGF's compiled-in
defaults, including the upstream nginx image.
*/}}
{{- define "nginx-gateway-fabric.proxyConfigName" -}}
{{- printf "%s-proxy-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "nginx-gateway-fabric.leaderElectionName" -}}
{{- printf "%s-leader-election" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/*
Refuse to render while an image is still on the PENDING placeholder.

The chart is authored before its images exist on GHCR (the image build's charts
dispatch is what fills these in, via scripts/repin.py). Rendering anyway would produce
a Deployment whose image reference is syntactically a digest and semantically garbage,
and the first sign of it would be ImagePullBackOff in someone's cluster. Fail here
instead, naming the fix.
*/}}
{{- define "nginx-gateway-fabric.assertDigest" -}}
{{- $digest := .digest | default "" -}}
{{- if not (regexMatch "^sha256:[0-9a-f]{64}$" $digest) -}}
{{- fail (printf "%s must be a real digest (sha256:<64 hex>), got %q. This chart is published only after both images are: run `uv run scripts/repin.py nginx-gateway-fabric <appVersion> <digest>` for the control plane and set nginx.image.digest for the data plane." .field $digest) -}}
{{- end -}}
{{- end -}}

{{/*
The data-plane image, as NginxProxy expresses it.

NginxProxy's image field is {repository, tag, pullPolicy} only -- there is no digest
field -- and the controller joins them as `repository:tag`
(provisioner.DetermineNginxImageName). Appending `@sha256` to the repository and
passing the bare hex as the tag makes that join produce `repo@sha256:<hex>`, a genuine
digest reference. It looks like a trick because it is one, but it is the only way to
pin the provisioned data plane by digest, and the kind install gate asserts the
resulting pod image matches.
*/}}
{{- define "nginx-gateway-fabric.dataPlaneRepository" -}}
{{- $i := .Values.nginx.image -}}
{{- $repo := $i.repository -}}
{{- with $i.registry }}{{- $repo = printf "%s/%s" (trimSuffix "/" .) $repo -}}{{- end -}}
{{- if $i.digest -}}
{{- printf "%s@sha256" $repo -}}
{{- else -}}
{{- $repo -}}
{{- end -}}
{{- end -}}

{{- define "nginx-gateway-fabric.dataPlaneTag" -}}
{{- $i := .Values.nginx.image -}}
{{- if $i.digest -}}
{{- include "nginx-gateway-fabric.assertDigest" (dict "digest" $i.digest "field" "nginx.image.digest") -}}
{{- trimPrefix "sha256:" $i.digest -}}
{{- else -}}
{{- .Chart.AppVersion -}}
{{- end -}}
{{- end -}}

{{/* Human-readable form, for NOTES.txt. */}}
{{- define "nginx-gateway-fabric.dataPlaneImage" -}}
{{- printf "%s:%s" (include "nginx-gateway-fabric.dataPlaneRepository" .) (include "nginx-gateway-fabric.dataPlaneTag" .) -}}
{{- end -}}
