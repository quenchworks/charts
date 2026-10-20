{{- define "datahub.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* One of .Values.images.<part> by digest, with the optional registry prefix.
     Call as (include "datahub.image" (dict "ctx" . "part" "gms")). */}}
{{- define "datahub.image" -}}
{{- $img := index .ctx.Values.images .part -}}
{{- $repo := required (printf "images.%s.repository is required" .part) $img.repository -}}
{{- $digest := required (printf "images.%s.digest is required (Quenchworks pins by digest, never a tag)" .part) $img.digest -}}
{{- with .ctx.Values.images.registry -}}
{{- printf "%s/%s@%s" (trimSuffix "/" .) $repo $digest -}}
{{- else -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}
{{- end -}}

{{/* Labels selecting one component's pods (gms or frontend). */}}
{{- define "datahub.selectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "datahub.gmsName" -}}{{ include "quench-common.fullname" . }}-gms{{- end -}}

{{/* Database. With the bundled subchart its Service is "<release>-mysql" and its Secret
     carries the user password under mysql-password: read from there, never copied, so a
     first install cannot end up with two different generated passwords. */}}
{{- define "datahub.db.host" -}}
{{- if .Values.mysql.enabled -}}{{ printf "%s-mysql" .Release.Name }}{{- else -}}{{ required "externalDatabase.host is required when mysql.enabled=false" .Values.externalDatabase.host }}{{- end -}}
{{- end -}}
{{- define "datahub.db.port" -}}
{{- if .Values.mysql.enabled -}}3306{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}
{{- define "datahub.db.name" -}}
{{- if .Values.mysql.enabled -}}{{ required "mysql.auth.database is required" .Values.mysql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}
{{- define "datahub.db.user" -}}
{{- if .Values.mysql.enabled -}}{{ required "mysql.auth.username is required" .Values.mysql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}
{{- define "datahub.db.secretName" -}}
{{- if .Values.mysql.enabled -}}
{{- .Values.mysql.auth.existingSecret | default (printf "%s-mysql" .Release.Name) -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}
{{- define "datahub.db.secretKey" -}}
{{- if and .Values.mysql.enabled .Values.mysql.auth.existingSecret -}}
{{- .Values.mysql.auth.existingSecretPasswordKey | default "mysql-password" -}}
{{- else if .Values.mysql.enabled -}}
mysql-password
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
db-password
{{- end -}}
{{- end -}}

{{- define "datahub.kafka" -}}
{{- if .Values.kafka.enabled -}}{{ printf "%s-kafka:9092" .Release.Name }}{{- else -}}{{ required "externalKafka.bootstrapServers is required when kafka.enabled=false" .Values.externalKafka.bootstrapServers }}{{- end -}}
{{- end -}}
{{- define "datahub.es.host" -}}
{{- if .Values.elasticsearch.enabled -}}{{ printf "%s-elasticsearch" .Release.Name }}{{- else -}}{{ required "externalElasticsearch.host is required when elasticsearch.enabled=false" .Values.externalElasticsearch.host }}{{- end -}}
{{- end -}}
{{- define "datahub.es.port" -}}
{{- if .Values.elasticsearch.enabled -}}9200{{- else -}}{{ .Values.externalElasticsearch.port }}{{- end -}}
{{- end -}}

{{/* The environment GMS and the setup job share: stores, Kafka, the internal schema
     registry and the service credentials. Secrets come in by secretKeyRef only. */}}
{{- define "datahub.backendEnv" -}}
{{- $secret := include "quench-common.fullname" . -}}
{{- $db := printf "%s:%s" (include "datahub.db.host" .) (include "datahub.db.port" .) -}}
- name: EBEAN_DATASOURCE_HOST
  value: {{ $db | quote }}
- name: EBEAN_DATASOURCE_URL
  value: {{ printf "jdbc:mysql://%s/%s?verifyServerCertificate=false&useSSL=true&useUnicode=yes&characterEncoding=UTF-8&enabledTLSProtocols=TLSv1.2" $db (include "datahub.db.name" .) | quote }}
- name: EBEAN_DATASOURCE_DRIVER
  value: com.mysql.cj.jdbc.Driver
- name: EBEAN_DATASOURCE_USERNAME
  value: {{ include "datahub.db.user" . | quote }}
- name: EBEAN_DATASOURCE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "datahub.db.secretName" . }}
      key: {{ include "datahub.db.secretKey" . }}
- name: KAFKA_BOOTSTRAP_SERVER
  value: {{ include "datahub.kafka" . | quote }}
- name: SCHEMA_REGISTRY_TYPE
  value: INTERNAL
- name: KAFKA_SCHEMAREGISTRY_URL
  value: {{ printf "http://%s:%v/schema-registry/api/" (include "datahub.gmsName" .) .Values.service.gmsPort | quote }}
- name: GRAPH_SERVICE_IMPL
  value: elasticsearch
- name: ELASTICSEARCH_HOST
  value: {{ include "datahub.es.host" . | quote }}
- name: ELASTICSEARCH_PORT
  value: {{ include "datahub.es.port" . | quote }}
- name: ELASTICSEARCH_USE_SSL
  value: {{ ternary .Values.externalElasticsearch.useSSL false (not .Values.elasticsearch.enabled) | quote }}
- name: ELASTICSEARCH_NUM_REPLICAS_PER_INDEX
  value: {{ .Values.search.replicasPerIndex | quote }}
- name: DATAHUB_SYSTEM_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ $secret }}
      key: system-client-secret
- name: DATAHUB_TOKEN_SERVICE_SIGNING_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $secret }}
      key: token-signing-key
- name: DATAHUB_TOKEN_SERVICE_SALT
  valueFrom:
    secretKeyRef:
      name: {{ $secret }}
      key: token-salt
- name: DATAHUB_TELEMETRY_ENABLED
  value: {{ .Values.gms.telemetry | quote }}
{{- end -}}
