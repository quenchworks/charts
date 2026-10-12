{{- define "apache-polaris.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "apache-polaris.authSecret" -}}
{{- default (include "quench-common.fullname" .) .Values.auth.existingSecret -}}
{{- end -}}

{{- define "apache-polaris.jdbc" -}}
{{- if eq .Values.persistence.type "relational-jdbc" }}true{{ end -}}
{{- end -}}

{{- define "apache-polaris.validate" -}}
{{- $t := .Values.persistence.type -}}
{{- if not (has $t (list "in-memory" "relational-jdbc")) -}}
{{- fail (printf "persistence.type must be in-memory or relational-jdbc, got %q" $t) -}}
{{- end -}}
{{- if and (eq $t "relational-jdbc") (not .Values.postgresql.enabled) (or (not .Values.externalDatabase.url) (not .Values.externalDatabase.existingSecret)) -}}
{{- fail "persistence.type=relational-jdbc needs postgresql.enabled=true, or externalDatabase.url and externalDatabase.existingSecret" -}}
{{- end -}}
{{- end -}}

{{/* Datasource and realm env shared by the server and the bootstrap initContainer. With the
bundled PostgreSQL the password comes from the subchart Secret, so a default install never
renders two different generated passwords. */}}
{{- define "apache-polaris.env" -}}
- name: POLARIS_PERSISTENCE_TYPE
  value: {{ .Values.persistence.type | quote }}
- name: POLARIS_REALM_CONTEXT_REALMS
  value: {{ .Values.auth.realm | quote }}
- name: POLARIS_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "apache-polaris.authSecret" . }}
      key: client-id
- name: POLARIS_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "apache-polaris.authSecret" . }}
      key: client-secret
{{- if include "apache-polaris.jdbc" . }}
- name: QUARKUS_DATASOURCE_DB_KIND
  value: postgresql
- name: QUARKUS_DATASOURCE_JDBC_ADDITIONAL_JDBC_PROPERTIES_CURRENTSCHEMA
  value: {{ .Values.jdbcSchema | quote }}
{{- if .Values.postgresql.enabled }}
- name: QUARKUS_DATASOURCE_JDBC_URL
  value: {{ printf "jdbc:postgresql://%s-postgresql:5432/%s" .Release.Name .Values.postgresql.auth.database | quote }}
- name: QUARKUS_DATASOURCE_USERNAME
  value: {{ .Values.postgresql.auth.username | quote }}
- name: QUARKUS_DATASOURCE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ default (printf "%s-postgresql" .Release.Name) .Values.postgresql.auth.existingSecret }}
      key: {{ default "postgres-password" .Values.postgresql.auth.existingSecretPasswordKey }}
{{- else }}
- name: QUARKUS_DATASOURCE_JDBC_URL
  value: {{ .Values.externalDatabase.url | quote }}
- name: QUARKUS_DATASOURCE_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalDatabase.existingSecret }}
      key: {{ .Values.externalDatabase.usernameKey }}
- name: QUARKUS_DATASOURCE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalDatabase.existingSecret }}
      key: {{ .Values.externalDatabase.passwordKey }}
{{- end }}
{{- end }}
{{- end -}}
