{{- define "linkerd.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* The identity component needs the full triple: a trust domain to name
     identities with, the trust anchors PEM (public material; the chart renders
     the trust-roots ConfigMap from it), and a user-created Secret holding the
     issuer CA (crt.pem/key.pem). Refuse to render a half-configured identity:
     upstream's binary would otherwise run as a healthy-looking pod that quietly
     exited ("Identity disabled in control plane configuration."). */}}
{{/* The required results are assigned to throwaway variables: `required`
     RETURNS the value when set, and an include renders whatever its body
     renders -- without the assignment this helper would inline the trust
     domain and the whole PEM blob into whatever YAML calls it. */}}
{{- define "linkerd.identityChecks" -}}
{{- $trustDomain := required "identity.trustDomain is required when identity.enabled=true" .Values.identity.trustDomain -}}
{{- $anchors := required "identity.trustAnchorsPEM is required when identity.enabled=true" .Values.identity.trustAnchorsPEM -}}
{{- $secret := required "identity.existingSecret is required when identity.enabled=true (Secret keys: crt.pem, key.pem)" .Values.identity.existingSecret -}}
{{- end -}}

{{- define "linkerd.policyChecks" -}}
{{- $secret := required "policyController.existingSecret is required when policyController.enabled=true (Secret keys: tls.crt, tls.key)" .Values.policyController.existingSecret -}}
{{- end -}}

{{/* Trust-roots ConfigMap name; also used by the Deployment's checksum. */}}
{{- define "linkerd.trustRootsConfigMapName" -}}
{{- printf "%s-trust-roots" (include "quench-common.fullname" .) -}}
{{- end -}}
