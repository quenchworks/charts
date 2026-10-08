{{/* Refuse installs this chart cannot serve. Rendered once, from the destination template. */}}
{{- define "linkerd.guards" -}}
{{- $anchors := required "identity.trustAnchorsPEM is required: the mesh cannot issue certificates without a trust anchor (see README)" .Values.identity.trustAnchorsPEM -}}
{{- $issuer := required "identity.existingSecret is required: a Secret with the issuer's crt.pem and key.pem (see README)" .Values.identity.existingSecret -}}
{{- /* 0.0.x named everything <release>-linkerd-*; 0.1.0 uses upstream's fixed names. An upgrade
       would leave both control planes half-running, so it stops here instead. */ -}}
{{- if lookup "apps/v1" "Deployment" .Release.Namespace (printf "%s-linkerd-destination" .Release.Name) -}}
{{- fail (printf "found Deployment %s-linkerd-destination from chart 0.0.x: 0.1.0 renamed every object and cannot upgrade it in place. Uninstall release %s, then install 0.1.0 (README: Upgrading from 0.0.x)." .Release.Name .Release.Name) -}}
{{- end -}}
{{- /* fixed names: one release per namespace */ -}}
{{- with lookup "apps/v1" "Deployment" .Release.Namespace "linkerd-destination" -}}
{{- $owner := index (.metadata.annotations | default dict) "meta.helm.sh/release-name" -}}
{{- if and $owner (ne $owner $.Release.Name) -}}
{{- fail (printf "release %s already runs Linkerd in namespace %s; the object names are fixed, so only one release per namespace" $owner $.Release.Namespace) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "linkerd.controllerImage" -}}
{{- printf "%s@%s" .Values.controllerImage.repository .Values.controllerImage.digest -}}
{{- end -}}

{{- define "linkerd.proxyImage" -}}
{{- printf "%s:%s@%s" .Values.proxy.image.name .Values.proxy.image.tag .Values.proxy.image.digest -}}
{{- end -}}

{{/* Labels on every control-plane pod: the injector skips pods carrying
     linkerd.io/control-plane-component, and the proxies report these. */}}
{{- define "linkerd.podLabels" -}}
linkerd.io/control-plane-component: {{ .component }}
linkerd.io/control-plane-ns: {{ .ctx.Release.Namespace }}
linkerd.io/proxy-deployment: linkerd-{{ .component }}
linkerd.io/workload-ns: {{ .ctx.Release.Namespace }}
{{- end -}}

{{/* Container hardening shared by the controllers (upstream runs them as uid 2103). */}}
{{- define "linkerd.controllerSecurity" -}}
securityContext:
  runAsNonRoot: true
  runAsUser: 2103
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities: { drop: [ALL] }
  seccompProfile: { type: RuntimeDefault }
{{- end -}}

{{/* With the CNI plugin redirecting traffic, the network validator checks the redirect works
     before the pod's containers start. It ships in the proxy image. */}}
{{- define "linkerd.networkValidator" -}}
- name: linkerd-network-validator
  image: {{ include "linkerd.proxyImage" .ctx }}
  imagePullPolicy: IfNotPresent
  command: [/usr/lib/linkerd/linkerd2-network-validator]
  args: [--log-format, plain, --log-level, debug, --connect-addr, "1.1.1.1:20001", --listen-addr, "0.0.0.0:4140", --timeout, 10s]
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    runAsGroup: 65534
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities: { drop: [ALL] }
    seccompProfile: { type: RuntimeDefault }
{{- end -}}

{{/* The control plane's own proxy, as a native sidecar (an init container that keeps running).
     dict: ctx, inboundPorts, dst (address of destination), identity (address of identity),
     policy (address of the policy server), requireTLS (inbound ports that must be mTLS),
     native (run as a native sidecar in initContainers; identity's own proxy cannot, because it
     needs its certificate from the identity container beside it). */}}
{{- define "linkerd.proxy" -}}
{{- $v := .ctx.Values -}}
{{- $ns := .ctx.Release.Namespace -}}
{{- $td := $v.identity.trustDomain -}}
- name: linkerd-proxy
  image: {{ include "linkerd.proxyImage" .ctx }}
  imagePullPolicy: IfNotPresent
  {{- if .native }}
  restartPolicy: Always
  {{- end }}
  env:
    - name: _pod_name
      valueFrom: { fieldRef: { fieldPath: metadata.name } }
    - name: _pod_ns
      valueFrom: { fieldRef: { fieldPath: metadata.namespace } }
    - name: _pod_nodeName
      valueFrom: { fieldRef: { fieldPath: spec.nodeName } }
    - name: _pod_sa
      valueFrom: { fieldRef: { fieldPath: spec.serviceAccountName } }
    - { name: LINKERD2_PROXY_LOG, value: {{ printf "%s,[{headers}]=off,[{request}]=off" $v.proxy.logLevel | quote }} }
    - { name: LINKERD2_PROXY_LOG_FORMAT, value: plain }
    - { name: LINKERD2_PROXY_DESTINATION_SVC_ADDR, value: {{ .dst | quote }} }
    - { name: LINKERD2_PROXY_DESTINATION_PROFILE_NETWORKS, value: {{ $v.clusterNetworks | quote }} }
    - { name: LINKERD2_PROXY_POLICY_SVC_ADDR, value: {{ .policy | quote }} }
    - { name: LINKERD2_PROXY_POLICY_WORKLOAD, value: '{"ns":"$(_pod_ns)", "pod":"$(_pod_name)"}' }
    - { name: LINKERD2_PROXY_INBOUND_DEFAULT_POLICY, value: {{ $v.proxy.defaultInboundPolicy | quote }} }
    - { name: LINKERD2_PROXY_POLICY_CLUSTER_NETWORKS, value: {{ $v.clusterNetworks | quote }} }
    - { name: LINKERD2_PROXY_CONTROL_STREAM_INITIAL_TIMEOUT, value: 3s }
    - { name: LINKERD2_PROXY_CONTROL_STREAM_IDLE_TIMEOUT, value: 5m }
    - { name: LINKERD2_PROXY_CONTROL_STREAM_LIFETIME, value: 1h }
    - { name: LINKERD2_PROXY_INBOUND_CONNECT_TIMEOUT, value: 100ms }
    - { name: LINKERD2_PROXY_OUTBOUND_CONNECT_TIMEOUT, value: 1000ms }
    - { name: LINKERD2_PROXY_OUTBOUND_DISCOVERY_IDLE_TIMEOUT, value: 5s }
    - { name: LINKERD2_PROXY_INBOUND_DISCOVERY_IDLE_TIMEOUT, value: 90s }
    - { name: LINKERD2_PROXY_CONTROL_LISTEN_ADDR, value: "0.0.0.0:4190" }
    - { name: LINKERD2_PROXY_ADMIN_LISTEN_ADDR, value: "0.0.0.0:4191" }
    - { name: LINKERD2_PROXY_OUTBOUND_LISTEN_ADDR, value: "127.0.0.1:4140" }
    - { name: LINKERD2_PROXY_OUTBOUND_LISTEN_ADDRS, value: "127.0.0.1:4140" }
    - { name: LINKERD2_PROXY_INBOUND_LISTEN_ADDR, value: "0.0.0.0:4143" }
    - name: LINKERD2_PROXY_INBOUND_IPS
      valueFrom: { fieldRef: { fieldPath: status.podIPs } }
    - { name: LINKERD2_PROXY_INBOUND_PORTS, value: {{ .inboundPorts | quote }} }
    {{- with .requireTLS }}
    - { name: LINKERD2_PROXY_INBOUND_PORTS_REQUIRE_TLS, value: {{ . | quote }} }
    {{- end }}
    - { name: LINKERD2_PROXY_DESTINATION_PROFILE_SUFFIXES, value: {{ printf "svc.%s." $v.clusterDomain | quote }} }
    - { name: LINKERD2_PROXY_INBOUND_ACCEPT_KEEPALIVE, value: 10000ms }
    - { name: LINKERD2_PROXY_OUTBOUND_CONNECT_KEEPALIVE, value: 10000ms }
    - { name: LINKERD2_PROXY_INBOUND_PORTS_DISABLE_PROTOCOL_DETECTION, value: {{ $v.defaultOpaquePorts | quote }} }
    - { name: LINKERD2_PROXY_DESTINATION_CONTEXT, value: '{"ns":"$(_pod_ns)", "nodeName":"$(_pod_nodeName)", "pod":"$(_pod_name)"}' }
    - { name: LINKERD2_PROXY_IDENTITY_DIR, value: /var/run/linkerd/identity/end-entity }
    - name: LINKERD2_PROXY_IDENTITY_TRUST_ANCHORS
      valueFrom: { configMapKeyRef: { name: linkerd-identity-trust-roots, key: ca-bundle.crt } }
    - { name: LINKERD2_PROXY_IDENTITY_TOKEN_FILE, value: /var/run/secrets/tokens/linkerd-identity-token }
    - { name: LINKERD2_PROXY_IDENTITY_SVC_ADDR, value: {{ .identity | quote }} }
    - { name: LINKERD2_PROXY_IDENTITY_LOCAL_NAME, value: {{ printf "$(_pod_sa).$(_pod_ns).serviceaccount.identity.%s.%s" $ns $td | quote }} }
    - { name: LINKERD2_PROXY_IDENTITY_SVC_NAME, value: {{ printf "linkerd-identity.%s.serviceaccount.identity.%s.%s" $ns $ns $td | quote }} }
    - { name: LINKERD2_PROXY_DESTINATION_SVC_NAME, value: {{ printf "linkerd-destination.%s.serviceaccount.identity.%s.%s" $ns $ns $td | quote }} }
    - { name: LINKERD2_PROXY_POLICY_SVC_NAME, value: {{ printf "linkerd-destination.%s.serviceaccount.identity.%s.%s" $ns $ns $td | quote }} }
  ports:
    - { name: linkerd-proxy, containerPort: 4143 }
    - { name: linkerd-admin, containerPort: 4191 }
  startupProbe:
    httpGet: { path: /ready, port: 4191 }
    periodSeconds: 1
    failureThreshold: 120
  readinessProbe:
    httpGet: { path: /ready, port: 4191 }
    initialDelaySeconds: 2
  livenessProbe:
    httpGet: { path: /live, port: 4191 }
    initialDelaySeconds: 10
  {{- with $v.proxy.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  # uid 2102: the CNI plugin's iptables rules let this user's traffic out unredirected
  securityContext:
    runAsNonRoot: true
    runAsUser: 2102
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities: { drop: [ALL] }
    seccompProfile: { type: RuntimeDefault }
  terminationMessagePolicy: FallbackToLogsOnError
  volumeMounts:
    - { name: linkerd-identity-end-entity, mountPath: /var/run/linkerd/identity/end-entity }
    - { name: linkerd-identity-token, mountPath: /var/run/secrets/tokens }
{{- end -}}

{{- define "linkerd.proxyVolumes" -}}
- name: linkerd-identity-token
  projected:
    sources:
      - serviceAccountToken: { audience: identity.l5d.io, expirationSeconds: 86400, path: linkerd-identity-token }
- name: linkerd-identity-end-entity
  emptyDir: { medium: Memory }
{{- end -}}

{{/* Pod-level fields shared by the control-plane pods. */}}
{{- define "linkerd.podSpec" -}}
automountServiceAccountToken: true
securityContext:
  seccompProfile: { type: RuntimeDefault }
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
