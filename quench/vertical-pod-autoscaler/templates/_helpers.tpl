{{/* The admission webhook's CA and serving certificate. The controller registers its own
     MutatingWebhookConfiguration with this CA, for the <fullname>-webhook Service.
     Regenerated on every render, so an upgrade rolls the controller (checksum/tls). */}}
{{- define "vpa.tls" -}}
{{- if not .vpaTLS -}}
{{- $svc := printf "%s-webhook" (include "quench-common.fullname" .) -}}
{{- $ca := genCA "vpa-webhook-ca" 3650 -}}
{{- $cert := genSignedCert (printf "%s.%s.svc" $svc .Release.Namespace) nil (list $svc (printf "%s.%s" $svc .Release.Namespace) (printf "%s.%s.svc" $svc .Release.Namespace)) 3650 $ca -}}
{{- $_ := set . "vpaTLS" (dict "ca" $ca.Cert "cert" $cert.Cert "key" $cert.Key) -}}
{{- end -}}
caCert.pem: {{ .vpaTLS.ca | b64enc }}
serverCert.pem: {{ .vpaTLS.cert | b64enc }}
serverKey.pem: {{ .vpaTLS.key | b64enc }}
{{- end -}}
