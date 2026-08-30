{{- define "kratos.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Database wiring. When postgresql.enabled the bundled subchart's primary Service is
named "<release>-postgresql" (the subchart's quench-common.fullname resolves against
its own chart name "postgresql"); credentials come from this chart's postgresql.auth.
When external, everything comes from externalDatabase.
*/}}
{{- define "kratos.db.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "kratos.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{- define "kratos.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}

{{- define "kratos.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}

{{- define "kratos.db.sslMode" -}}
{{- if .Values.postgresql.enabled -}}disable{{- else -}}{{ .Values.externalDatabase.sslMode }}{{- end -}}
{{- end -}}

{{/* Name of the Secret holding the DSN, and the key within it. */}}
{{- define "kratos.secretName" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "kratos.db.secretDsnKey" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretDsnKey -}}
{{- else -}}
dsn
{{- end -}}
{{- end -}}

{{/* Whether this chart renders its own managed Secret. */}}
{{- define "kratos.manageSecret" -}}
{{- if or .Values.postgresql.enabled (not .Values.externalDatabase.existingSecret) -}}true{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding kratos.yaml + the identity schema. */}}
{{- define "kratos.configMapName" -}}
{{- if .Values.config.existingConfigMap -}}
{{- .Values.config.existingConfigMap -}}
{{- else -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Default kratos.yaml. The DSN is deliberately absent here -- it is supplied only
via the DSN env var (from the managed Secret), so it never lands in this
ConfigMap. Recovery/verification flows are disabled because both require a
configured SMTP courier, which this chart does not wire up; enable them (and set
courier.smtp.connection_uri) via config.yaml if you need them.
*/}}
{{- define "kratos.defaultConfig" -}}
serve:
  public:
    base_url: {{ .Values.urls.public | quote }}
    port: {{ .Values.service.publicPort }}
    host: 0.0.0.0
  admin:
    base_url: {{ .Values.urls.admin | quote }}
    port: {{ .Values.service.adminPort }}
    host: 0.0.0.0
selfservice:
  default_browser_return_url: {{ .Values.urls.public | quote }}
  allowed_return_urls:
    - {{ .Values.urls.public | quote }}
  methods:
    password:
      enabled: true
  flows:
    registration:
      enabled: true
    login:
      enabled: true
    settings:
      enabled: true
    recovery:
      enabled: false
    verification:
      enabled: false
    logout:
      after:
        default_browser_return_url: {{ .Values.urls.public | quote }}
identity:
  default_schema_id: default
  schemas:
    - id: default
      url: file:///etc/config/identity.default.schema.json
log:
  level: info
  format: json
{{- end -}}

{{/* Minimal default identity schema: a single required "email" trait, used as
     the login identifier. */}}
{{- define "kratos.defaultIdentitySchema" -}}
{
  "$id": "https://quench-works.com/schemas/identity.default.schema.json",
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Default identity",
  "type": "object",
  "properties": {
    "traits": {
      "type": "object",
      "properties": {
        "email": {
          "type": "string",
          "format": "email",
          "title": "E-Mail",
          "ory.sh/kratos": {
            "credentials": {
              "password": { "identifier": true }
            }
          }
        }
      },
      "required": ["email"],
      "additionalProperties": false
    }
  }
}
{{- end -}}
