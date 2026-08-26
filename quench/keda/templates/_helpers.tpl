{{/*
Per-component resource names, derived from the release fullname. The names are
NOT hardcoded to KEDA's upstream defaults: every place that needs them (the
adapter's gRPC dial address, the certificate SANs, the APIService backend) is
templated from these helpers, so two releases can coexist in one cluster --
except for the cluster-singleton APIService, which is inherent to KEDA.
*/}}
{{- define "keda.operatorName" -}}
{{- printf "%s-operator" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "keda.metricsName" -}}
{{- printf "%s-metrics-apiserver" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Secret holding the shared CA + leaf keypair (ca.crt / tls.crt / tls.key). */}}
{{- define "keda.certSecretName" -}}
{{- .Values.certificates.existingSecret | default (printf "%s-certs" (include "quench-common.fullname" .)) -}}
{{- end -}}

{{- define "keda.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "quench-common.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Address the adapter dials for the operator's gRPC metrics service. Must be one
of the certificate SANs below, because the gRPC client verifies the server name.
*/}}
{{- define "keda.metricsServiceAddress" -}}
{{- printf "%s.%s.svc.%s:%v" (include "keda.operatorName" .) .Release.Namespace .Values.clusterDomain .Values.operator.grpcPort -}}
{{- end -}}

{{/*
SANs for the single shared leaf certificate: all four DNS forms of BOTH Services.
The operator's gRPC server and the adapter's aggregated API server present the
same certificate, and each verifies the other against the same CA, so one list
has to cover both.
*/}}
{{- define "keda.certDNSNames" -}}
{{- $ns := .Release.Namespace -}}
{{- $domain := .Values.clusterDomain -}}
{{- $names := list -}}
{{- range list (include "keda.operatorName" .) (include "keda.metricsName" .) -}}
{{- $names = concat $names (list . (printf "%s.%s" . $ns) (printf "%s.%s.svc" . $ns) (printf "%s.%s.svc.%s" . $ns $domain)) -}}
{{- end -}}
{{- toJson $names -}}
{{- end -}}

{{/*
Resolve the certificate material once per render.

Returns a dict of base64-encoded ca.crt / tls.crt / tls.key. On upgrade the
existing Secret is read back and reused verbatim, so no certificate churn
happens. `lookup` is empty during `helm template` / `--dry-run`, which just
means a throwaway keypair is rendered there.

CALL THIS EXACTLY ONCE PER RENDER (templates/certificates.yaml does, and emits
both the Secret and the APIService from the result). Two calls on a fresh
install would generate two unrelated CAs and the aggregation layer would reject
the adapter's certificate.
*/}}
{{- define "keda.certificates" -}}
{{- $existing := (lookup "v1" "Secret" .Release.Namespace (include "keda.certSecretName" .)).data | default dict -}}
{{- if and (hasKey $existing "ca.crt") (hasKey $existing "tls.crt") (hasKey $existing "tls.key") -}}
{{- toJson (dict "ca.crt" (index $existing "ca.crt") "tls.crt" (index $existing "tls.crt") "tls.key" (index $existing "tls.key")) -}}
{{- else -}}
{{- $days := int .Values.certificates.validityDays -}}
{{- $dns := include "keda.certDNSNames" . | fromJsonArray -}}
{{- $ca := genCA (printf "%s-ca" (include "quench-common.fullname" .)) $days -}}
{{- $leaf := genSignedCert (first $dns) nil $dns $days $ca -}}
{{- toJson (dict "ca.crt" ($ca.Cert | b64enc) "tls.crt" ($leaf.Cert | b64enc) "tls.key" ($leaf.Key | b64enc)) -}}
{{- end -}}
{{- end -}}

{{/*
Per-component selector labels: the shared selectorLabels plus a component label,
so each Deployment's pods are uniquely matched. Call with a dict:
  {{- include "keda.componentSelectorLabels" (dict "ctx" . "component" "operator") }}
*/}}
{{- define "keda.componentSelectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* Per-component metadata labels: the shared labels plus the component label. */}}
{{- define "keda.componentLabels" -}}
{{ include "quench-common.labels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}
