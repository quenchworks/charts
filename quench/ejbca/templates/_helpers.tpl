{{/* The one Service port: EJBCA's public web, health check, CRL, SCEP, CMP, web services and REST on 8080. The EJB
     CLI listener (4447) and WildFly management (9990) stay on loopback inside the pod. */}}
{{- define "ejbca.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{/* The datasource reads DATABASE_JDBC_URL, DATABASE_USER and DATABASE_PASSWORD (WildFly ${env.*} expressions). */}}
{{- define "ejbca.env" -}}
{{- if .Values.postgresql.enabled }}
- { name: DATABASE_JDBC_URL, value: {{ printf "jdbc:postgresql://%s-postgresql:5432/%s" .Release.Name .Values.postgresql.auth.database | quote }} }
- { name: DATABASE_USER, value: {{ .Values.postgresql.auth.username | quote }} }
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-postgresql" .Release.Name }}, key: postgres-password }
{{- else }}
- { name: DATABASE_JDBC_URL, value: {{ printf "jdbc:postgresql://%s:%d/%s" (required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host) (int .Values.externalDatabase.port) .Values.externalDatabase.database | quote }} }
- { name: DATABASE_USER, value: {{ .Values.externalDatabase.username | quote }} }
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ required "externalDatabase.existingSecret is required when postgresql.enabled=false" .Values.externalDatabase.existingSecret }}, key: {{ .Values.externalDatabase.existingSecretPasswordKey }} }
{{- end }}
{{- with .Values.javaOpts }}
- { name: JAVA_OPTS, value: {{ . | quote }} }
{{- end }}
{{- end -}}
