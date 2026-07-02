{{- define "skywalking.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Elasticsearch storage nodes OAP connects to (SW_STORAGE_ES_CLUSTER_NODES). When the bundled
subchart is enabled its HTTP Service is "<release>-elasticsearch" on 9200 (the subchart's
quench-common.fullname resolves against its own chart name "elasticsearch"). Otherwise the
external cluster is taken from storage.elasticsearch.clusterNodes (may be empty, in which case
OAP falls back to its own default and no cluster env is emitted).
*/}}
{{- define "skywalking.esNodes" -}}
{{- if .Values.elasticsearch.enabled -}}
{{- printf "%s-elasticsearch:9200" .Release.Name -}}
{{- else -}}
{{- .Values.storage.elasticsearch.clusterNodes -}}
{{- end -}}
{{- end -}}

{{/* Whether an ES password is available (either supplied inline or via an existing Secret). */}}
{{- define "skywalking.es.hasPassword" -}}
{{- if or .Values.storage.elasticsearch.existingSecret .Values.storage.elasticsearch.password -}}true{{- end -}}
{{- end -}}

{{/* Whether this chart renders its own managed Secret for the ES password. */}}
{{- define "skywalking.es.manageSecret" -}}
{{- if and (not .Values.storage.elasticsearch.existingSecret) .Values.storage.elasticsearch.password -}}true{{- end -}}
{{- end -}}

{{/* Name of the Secret holding the ES password. */}}
{{- define "skywalking.es.secretName" -}}
{{- if .Values.storage.elasticsearch.existingSecret -}}{{ .Values.storage.elasticsearch.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{/* Key in the Secret that holds the ES password. */}}
{{- define "skywalking.es.secretPasswordKey" -}}
{{- if .Values.storage.elasticsearch.existingSecret -}}{{ .Values.storage.elasticsearch.existingSecretPasswordKey }}{{- else -}}es-password{{- end -}}
{{- end -}}
