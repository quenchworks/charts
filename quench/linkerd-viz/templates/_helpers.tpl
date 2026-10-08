{{- define "viz.image" -}}
{{- printf "%s@%s" .repository .digest -}}
{{- end -}}

{{/* Labels on every viz object; pods add component. */}}
{{- define "viz.labels" -}}
{{ include "quench-common.labels" .ctx }}
linkerd.io/extension: viz
component: {{ .component }}
{{- end -}}

{{- define "viz.selector" -}}
linkerd.io/extension: viz
component: {{ . }}
{{- end -}}

{{/* Pod metadata: meshed by the linkerd proxy injector. */}}
{{- define "viz.podMeta" -}}
labels:
  {{- include "viz.selector" .component | nindent 2 }}
  app.kubernetes.io/part-of: Linkerd
annotations:
  linkerd.io/inject: enabled
  config.alpha.linkerd.io/proxy-wait-before-exit-seconds: "0"
  {{- with .checksum }}
  checksum/tls: {{ . }}
  {{- end }}
{{- end -}}

{{/* Pod-level fields shared by the viz pods. */}}
{{- define "viz.podSpec" -}}
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

{{/* Container hardening (upstream runs viz as uid/gid 2103, the images' user). */}}
{{- define "viz.securityContext" -}}
securityContext:
  runAsNonRoot: true
  runAsUser: 2103
  runAsGroup: 2103
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities: { drop: [ALL] }
  seccompProfile: { type: RuntimeDefault }
{{- end -}}

{{/* A webhook serving Secret for <name>.<ns>.svc, generated once and kept on upgrade.
     Returns YAML: crt, key, ca (base64). */}}
{{- define "viz.tls" -}}
{{- $sec := lookup "v1" "Secret" .ctx.Release.Namespace (printf "%s-k8s-tls" .name) -}}
{{- if and $sec (index $sec.data "ca.crt") -}}
crt: {{ index $sec.data "tls.crt" }}
key: {{ index $sec.data "tls.key" }}
ca: {{ index $sec.data "ca.crt" }}
{{- else -}}
{{- $ca := genCA (printf "%s-ca" .name) 3650 -}}
{{- $cn := printf "%s.%s.svc" .name .ctx.Release.Namespace -}}
{{- $cert := genSignedCert $cn nil (list $cn) 3650 $ca -}}
crt: {{ $cert.Cert | b64enc }}
key: {{ $cert.Key | b64enc }}
ca: {{ $ca.Cert | b64enc }}
{{- end -}}
{{- end -}}

{{- define "viz.tlsSecret" -}}
apiVersion: v1
kind: Secret
type: kubernetes.io/tls
metadata:
  name: {{ .name }}-k8s-tls
  labels:
    {{- include "viz.labels" (dict "ctx" .ctx "component" .name) | nindent 4 }}
data:
  tls.crt: {{ .tls.crt }}
  tls.key: {{ .tls.key }}
  ca.crt: {{ .tls.ca }}
{{- end -}}
