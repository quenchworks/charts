{{/* The web port: uWSGI's HTTP router on 8081, or uWSGI's HTTPS listener on 8443 with TLS. */}}
{{- define "defectdojo.ports" -}}
{{- if eq (include "quench-common.tls.enabled" .) "true" -}}
{{- toJson (list (dict "name" "https" "port" 8443 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- else -}}
{{- toJson (list (dict "name" "http" "port" 8081 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}
{{- end -}}

{{- define "defectdojo.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Settings shared by every DefectDojo container. DD_DATABASE_URL and DD_CELERY_BROKER_URL are assembled by the
     kubelet ($(VAR) expansion) so passwords never sit in the pod spec; they must be URL-safe (the subcharts generate
     alphanumerics). */}}
{{- define "defectdojo.env" -}}
{{- $s := include "defectdojo.secretName" . -}}
{{- if .Values.postgresql.enabled }}
- { name: DB_HOST, value: {{ printf "%s-postgresql" .Release.Name | quote }} }
- { name: DB_PORT, value: "5432" }
- { name: DB_NAME, value: {{ .Values.postgresql.auth.database | quote }} }
- { name: DB_USER, value: {{ .Values.postgresql.auth.username | quote }} }
- name: DB_PASS
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-postgresql" .Release.Name }}, key: postgres-password }
{{- else }}
- { name: DB_HOST, value: {{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host | quote }} }
- { name: DB_PORT, value: {{ .Values.externalDatabase.port | quote }} }
- { name: DB_NAME, value: {{ .Values.externalDatabase.database | quote }} }
- { name: DB_USER, value: {{ .Values.externalDatabase.username | quote }} }
- name: DB_PASS
  valueFrom:
    secretKeyRef: { name: {{ required "externalDatabase.existingSecret is required when postgresql.enabled=false" .Values.externalDatabase.existingSecret }}, key: {{ .Values.externalDatabase.existingSecretPasswordKey }} }
{{- end }}
- { name: DD_DATABASE_URL, value: "postgresql://$(DB_USER):$(DB_PASS)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)" }
{{- if .Values.valkey.enabled }}
- name: BROKER_PASS
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-valkey" .Release.Name }}, key: valkey-password }
- { name: DD_CELERY_BROKER_URL, value: {{ printf "redis://:$(BROKER_PASS)@%s-valkey:6379/0" .Release.Name | quote }} }
{{- else }}
- name: DD_CELERY_BROKER_URL
  valueFrom:
    secretKeyRef: { name: {{ required "externalBroker.existingSecret is required when valkey.enabled=false" .Values.externalBroker.existingSecret }}, key: {{ .Values.externalBroker.existingSecretKey }} }
{{- end }}
- name: DD_SECRET_KEY
  valueFrom:
    secretKeyRef: { name: {{ $s }}, key: secret-key }
- name: DD_CREDENTIAL_AES_256_KEY
  valueFrom:
    secretKeyRef: { name: {{ $s }}, key: credential-aes-256-key }
- name: DD_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ $s }}, key: admin-password }
- { name: DD_ADMIN_USER, value: {{ .Values.admin.user | quote }} }
- { name: DD_ADMIN_MAIL, value: {{ .Values.admin.email | quote }} }
- { name: DD_ALLOWED_HOSTS, value: {{ join "," (concat (list (include "quench-common.fullname" .) (printf "%s.%s" (include "quench-common.fullname" .) .Release.Namespace) (printf "%s.%s.svc" (include "quench-common.fullname" .) .Release.Namespace) "localhost" "127.0.0.1") .Values.allowedHosts) | quote }} }
{{- with .Values.siteURL }}
- { name: DD_SITE_URL, value: {{ . | quote }} }
{{- end }}
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}

{{/* Writable paths on the read-only root filesystem, mounted into every DefectDojo container. */}}
{{- define "defectdojo.mounts" -}}
- { name: tmp, mountPath: /tmp }
- { name: run, mountPath: /var/run/defectdojo }
- { name: media, mountPath: /app/media }
{{- end -}}
