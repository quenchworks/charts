{{- define "satosa.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* BASE: the public URL of the proxy. Defaults to the in-cluster Service URL. */}}
{{- define "satosa.baseUrl" -}}
{{- default (printf "http://%s.%s.svc.cluster.local:%v" (include "quench-common.fullname" .) .Release.Namespace .Values.service.port) .Values.baseUrl | trimSuffix "/" -}}
{{- end -}}

{{/* ConfigMap mounted at /etc/satosa: an external one wins, else the chart's. */}}
{{- define "satosa.configMapName" -}}
{{- default (printf "%s-config" (include "quench-common.fullname" .)) .Values.config.existingConfigMap -}}
{{- end -}}

{{/* Secret with the state encryption key (key state-encryption-key). */}}
{{- define "satosa.stateSecretName" -}}
{{- default (printf "%s-state" (include "quench-common.fullname" .)) .Values.stateEncryption.existingSecret -}}
{{- end -}}

{{/* kubernetes.io/tls Secret with the SAML signing key pair. */}}
{{- define "satosa.samlSecretName" -}}
{{- default (printf "%s-saml" (include "quench-common.fullname" .)) .Values.samlKeyPair.existingSecret -}}
{{- end -}}
