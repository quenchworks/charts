{{- define "graylog.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* This chart's managed Secret (password-secret, root-password-sha2, and the mongodb-uri
     when the chart manages it). */}}
{{- define "graylog.secretName" -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}

{{/*
OpenSearch (log storage) connection. When opensearch.enabled the bundled subchart's Service
is "<release>-opensearch" on httpPort 9200 with the security plugin disabled, so Graylog
reaches it over plain http with no auth. When external, externalOpensearch.hosts is used
verbatim. Consumed as GRAYLOG_ELASTICSEARCH_HOSTS.
*/}}
{{- define "graylog.opensearch.hosts" -}}
{{- if .Values.opensearch.enabled -}}
{{- printf "http://%s-opensearch:9200" .Release.Name -}}
{{- else -}}
{{- required "externalOpensearch.hosts is required when opensearch.enabled=false" .Values.externalOpensearch.hosts -}}
{{- end -}}
{{- end -}}

{{/* Whether this chart renders the mongodb-uri into its managed Secret. True for the bundled
     MongoDB and for an external MongoDB given by uri; false only when an external
     existingSecret already supplies the URI. */}}
{{- define "graylog.manageMongoUri" -}}
{{- if or .Values.mongodb.enabled (not .Values.externalMongodb.existingSecret) -}}true{{- end -}}
{{- end -}}

{{/* Secret name/key that GRAYLOG_MONGODB_URI is read from. */}}
{{- define "graylog.mongo.secretName" -}}
{{- if and (not .Values.mongodb.enabled) .Values.externalMongodb.existingSecret -}}
{{- .Values.externalMongodb.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "graylog.mongo.uriKey" -}}
{{- if and (not .Values.mongodb.enabled) .Values.externalMongodb.existingSecret -}}
{{- .Values.externalMongodb.existingSecretUriKey -}}
{{- else -}}
mongodb-uri
{{- end -}}
{{- end -}}
