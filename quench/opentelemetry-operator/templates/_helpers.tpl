{{- define "otelop.certSecret" -}}{{ include "quench-common.fullname" . }}-webhook-cert{{- end -}}

{{/* One webhook certificate per render, shared by the Secret, the webhook configurations
     and the CRD conversion webhook. Kept across upgrades: an existing Secret is reused. */}}
{{- define "otelop.ensureCerts" -}}
{{- if not (hasKey .Values "__otelopCerts") -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace (include "otelop.certSecret" .) -}}
{{- if and $existing (hasKey $existing.data "ca.crt") -}}
{{- $_ := set .Values "__otelopCerts" (dict "ca" (index $existing.data "ca.crt") "crt" (index $existing.data "tls.crt") "key" (index $existing.data "tls.key")) -}}
{{- else -}}
{{- $svc := printf "%s-webhook" (include "quench-common.fullname" .) -}}
{{- $ca := genCA "opentelemetry-operator-ca" 3650 -}}
{{- $cert := genSignedCert $svc nil (list $svc (printf "%s.%s" $svc .Release.Namespace) (printf "%s.%s.svc" $svc .Release.Namespace) (printf "%s.%s.svc.cluster.local" $svc .Release.Namespace)) 3650 $ca -}}
{{- $_ := set .Values "__otelopCerts" (dict "ca" ($ca.Cert | b64enc) "crt" ($cert.Cert | b64enc) "key" ($cert.Key | b64enc)) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "otelop.caBundle" -}}
{{- include "otelop.ensureCerts" . -}}
{{- index .Values.__otelopCerts "ca" -}}
{{- end -}}
