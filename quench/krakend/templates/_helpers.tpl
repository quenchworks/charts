{{- define "krakend.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap this chart renders krakend.json into. */}}
{{- define "krakend.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* ConfigMap actually mounted at /etc/krakend. An existing one wins. */}}
{{- define "krakend.mountedConfigMap" -}}
{{- default (include "krakend.configMapName" .) .Values.existingConfigMap -}}
{{- end -}}

{{/* Key inside that ConfigMap holding the config document. */}}
{{- define "krakend.mountedConfigKey" -}}
{{- if .Values.existingConfigMap -}}{{ required "existingConfigMapKey is required when existingConfigMap is set" .Values.existingConfigMapKey }}{{- else -}}krakend.json{{- end -}}
{{- end -}}

{{/*
The rendered gateway config. `port` is owned by the chart so krakend.json and the
container port cannot drift; everything else comes from .Values.config.
*/}}
{{- define "krakend.config" -}}
{{- $conf := mergeOverwrite (deepCopy .Values.config) (dict "port" (int .Values.containerPort)) -}}
{{- if include "quench-common.tls.enabled" . -}}
{{- $_ := set $conf "tls" (dict "keys" (list (dict "public_key" "/tls/tls.crt" "private_key" "/tls/tls.key"))) -}}
{{- end -}}
{{- $conf | toPrettyJson -}}
{{- end -}}
