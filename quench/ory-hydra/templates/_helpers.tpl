{{- define "ory-hydra.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "ory-hydra.secretName" -}}
{{- default (include "quench-common.fullname" .) .Values.hydra.existingSecret -}}
{{- end -}}

{{/* DSN: Hydra reads one URL. Kubernetes expands $(DB_PASSWORD) from the env var set
     just before it, so the password stays in its Secret. */}}
{{- define "ory-hydra.dbEnv" -}}
{{- $db := .Values.externalDatabase -}}
{{- if and (not .Values.postgresql.enabled) $db.existingDsnSecret }}
- name: DSN
  valueFrom:
    secretKeyRef:
      name: {{ $db.existingDsnSecret }}
      key: {{ $db.existingDsnSecretKey }}
{{- else }}
{{- $host := "" }}{{- $port := "" }}{{- $name := "" }}{{- $user := "" }}{{- $secret := "" }}{{- $key := "" }}{{- $ssl := "disable" }}
{{- if .Values.postgresql.enabled }}
{{- $host = printf "%s-postgresql" .Release.Name }}{{- $port = "5432" }}{{- $name = .Values.postgresql.auth.database }}{{- $user = .Values.postgresql.auth.username }}
{{- $secret = printf "%s-postgresql" .Release.Name }}{{- $key = "postgres-password" }}
{{- else }}
{{- $host = required "Hydra needs PostgreSQL: set postgresql.enabled=true, externalDatabase.host or externalDatabase.existingDsnSecret" $db.host }}
{{- $port = toString $db.port }}{{- $name = $db.database }}{{- $user = $db.username }}{{- $ssl = $db.sslmode }}
{{- $secret = required "externalDatabase.existingSecret is required with externalDatabase.host" $db.existingSecret }}{{- $key = $db.existingSecretPasswordKey }}
{{- end }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $secret }}
      key: {{ $key }}
- name: DSN
  value: "postgres://{{ $user }}:$(DB_PASSWORD)@{{ $host }}:{{ $port }}/{{ $name }}?sslmode={{ $ssl }}"
{{- end }}
{{- end -}}

{{- define "ory-hydra.env" -}}
{{ include "ory-hydra.dbEnv" . }}
- name: SECRETS_SYSTEM
  valueFrom:
    secretKeyRef:
      name: {{ include "ory-hydra.secretName" . }}
      key: secretsSystem
- name: SECRETS_COOKIE
  valueFrom:
    secretKeyRef:
      name: {{ include "ory-hydra.secretName" . }}
      key: secretsCookie
      optional: true
- name: URLS_SELF_ISSUER
  value: {{ .Values.hydra.issuer | quote }}
- name: URLS_LOGIN
  value: {{ .Values.hydra.loginUrl | quote }}
- name: URLS_CONSENT
  value: {{ .Values.hydra.consentUrl | quote }}
- name: SERVE_PUBLIC_PORT
  value: "4444"
- name: SERVE_ADMIN_PORT
  value: "4445"
{{- range $k, $v := .Values.hydra.config }}
- name: {{ $k }}
  value: {{ $v | quote }}
{{- end }}
{{- with .Values.extraEnvVars }}
{{ toYaml . }}
{{- end }}
{{- end -}}
