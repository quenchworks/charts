{{/* ConfigMap holding the controller's config.yaml, mounted at /etc/apisix-ingress-controller. */}}
{{- define "apisix-ingress-controller.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The adc sidecar image, by digest. Same digest-only contract as quench-common.image. */}}
{{- define "apisix-ingress-controller.adcImage" -}}
{{- $i := .Values.adc.image -}}
{{- printf "%s@%s" (required "adc.image.repository is required" $i.repository) (required "adc.image.digest is required (QuenchWorks pins by digest, never a tag)" $i.digest) -}}
{{- end -}}

{{/* The GatewayProxy / IngressClass / GatewayClass this chart creates. */}}
{{- define "apisix-ingress-controller.gatewayProxyName" -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}

{{/*
The controller's config.yaml.

Built as a map so .Values.config can be deep-merged over it rather than
string-concatenated. NOTE: the controller runs this file through Go text/template
with missingkey=error to interpolate environment variables, so a literal {{ in
any value here would break start-up.
*/}}
{{- define "apisix-ingress-controller.configYaml" -}}
{{- $v := .Values -}}
{{- $cfg := dict
      "log_level" $v.logLevel
      "controller_name" $v.controllerName
      "leader_election_id" $v.leaderElection.id
      "leader_election" (dict "disable" (not $v.leaderElection.enabled))
      "probe_addr" (printf ":%v" $v.containerPorts.probe)
      "metrics_addr" (printf ":%v" $v.containerPorts.metrics)
      "exec_adc_timeout" $v.execAdcTimeout
      "disable_gateway_api" (not $v.gatewayAPI.enabled)
      "provider" (dict
        "type" $v.dataPlane.mode
        "sync_period" $v.syncPeriod
        "init_sync_delay" $v.initSyncDelay)
-}}
{{- $cfg = mergeOverwrite $cfg (deepCopy ($v.config | default dict)) -}}
{{- toYaml $cfg -}}
{{- end -}}

{{/*
The GatewayProxy's spec.provider.controlPlane block.

The CRD carries a CEL rule `has(self.endpoints) != has(self.service)`, so exactly
one of the two is emitted, and auth.adminKey is required either way.
*/}}
{{- define "apisix-ingress-controller.controlPlane" -}}
{{- $d := .Values.dataPlane -}}
{{- $k := $d.adminKey -}}
mode: {{ $d.mode }}
tlsVerify: {{ $d.tlsVerify }}
{{- if and $d.endpoints $d.service }}
{{- fail "dataPlane: set exactly one of endpoints or service, not both (the GatewayProxy CRD rejects both)." }}
{{- else if $d.endpoints }}
endpoints:
  {{- toYaml $d.endpoints | nindent 2 }}
{{- else if $d.service }}
service:
  name: {{ required "dataPlane.service.name is required" $d.service.name }}
  port: {{ required "dataPlane.service.port is required" $d.service.port }}
{{- else }}
{{- fail "dataPlane.create=true needs the APISIX Admin API address: set dataPlane.endpoints (e.g. [\"http://apisix-admin:9180\"]) or dataPlane.service {name, port}." }}
{{- end }}
auth:
  type: AdminKey
  adminKey:
    {{- if $k.existingSecret }}
    valueFrom:
      secretKeyRef:
        name: {{ $k.existingSecret }}
        key: {{ required "dataPlane.adminKey.existingSecretKey is required with existingSecret" $k.existingSecretKey }}
    {{- else if $k.value }}
    value: {{ $k.value | quote }}
    {{- else }}
    {{- fail "dataPlane.adminKey: set existingSecret (preferred) or value -- APISIX's Admin API refuses an unauthenticated client." }}
    {{- end }}
{{- end -}}
