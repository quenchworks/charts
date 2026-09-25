{{- define "zipkin.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "zipkin.env" -}}
{{- $s := .Values.storage -}}
- name: STORAGE_TYPE
  value: {{ $s.type | quote }}
- name: JAVA_TOOL_OPTIONS
  value: {{ .Values.javaOpts | quote }}
{{- if eq $s.type "elasticsearch" }}
- name: ES_HOSTS
  value: {{ required "storage.elasticsearch.hosts is required with storage.type=elasticsearch" $s.elasticsearch.hosts | quote }}
{{- else if eq $s.type "cassandra3" }}
- name: CASSANDRA_CONTACT_POINTS
  value: {{ required "storage.cassandra.contactPoints is required with storage.type=cassandra3" $s.cassandra.contactPoints | quote }}
- name: CASSANDRA_KEYSPACE
  value: {{ $s.cassandra.keyspace | quote }}
{{- else if eq $s.type "mysql" }}
- name: MYSQL_HOST
  value: {{ required "storage.mysql.host is required with storage.type=mysql" $s.mysql.host | quote }}
- name: MYSQL_TCP_PORT
  value: {{ $s.mysql.port | quote }}
- name: MYSQL_DB
  value: {{ $s.mysql.database | quote }}
- name: MYSQL_USER
  value: {{ $s.mysql.user | quote }}
{{- end }}
{{- if and $s.existingSecret (ne $s.type "mem") }}
- name: {{ get (dict "elasticsearch" "ES_PASSWORD" "cassandra3" "CASSANDRA_PASSWORD" "mysql" "MYSQL_PASS") $s.type }}
  valueFrom:
    secretKeyRef:
      name: {{ $s.existingSecret }}
      key: {{ $s.existingSecretPasswordKey }}
{{- end }}
{{- range $k, $v := .Values.env }}
- name: {{ $k }}
  value: {{ $v | quote }}
{{- end }}
{{- with .Values.extraEnvVars }}
{{ toYaml . }}
{{- end }}
{{- end -}}
