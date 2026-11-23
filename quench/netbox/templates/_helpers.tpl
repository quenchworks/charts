{{/* The web port: gunicorn on 8080, serving HTTPS itself from /tls when TLS is on. */}}
{{- define "netbox.ports" -}}
{{- toJson (list (dict "name" (ternary "https" "http" (eq (include "quench-common.tls.enabled" .) "true")) "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "netbox.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Settings shared by every NetBox container; the image's configuration.py reads them. */}}
{{- define "netbox.env" -}}
{{- $s := include "netbox.secretName" . -}}
{{- $f := include "quench-common.fullname" . -}}
{{- if .Values.postgresql.enabled }}
- { name: DB_HOST, value: {{ printf "%s-postgresql" .Release.Name | quote }} }
- { name: DB_PORT, value: "5432" }
- { name: DB_NAME, value: {{ .Values.postgresql.auth.database | quote }} }
- { name: DB_USER, value: {{ .Values.postgresql.auth.username | quote }} }
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-postgresql" .Release.Name }}, key: postgres-password }
{{- else }}
- { name: DB_HOST, value: {{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host | quote }} }
- { name: DB_PORT, value: {{ .Values.externalDatabase.port | quote }} }
- { name: DB_NAME, value: {{ .Values.externalDatabase.database | quote }} }
- { name: DB_USER, value: {{ .Values.externalDatabase.username | quote }} }
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ required "externalDatabase.existingSecret is required when postgresql.enabled=false" .Values.externalDatabase.existingSecret }}, key: {{ .Values.externalDatabase.existingSecretPasswordKey }} }
{{- end }}
{{- if .Values.valkey.enabled }}
- { name: REDIS_HOST, value: {{ printf "%s-valkey" .Release.Name | quote }} }
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-valkey" .Release.Name }}, key: valkey-password }
{{- else }}
- { name: REDIS_HOST, value: {{ required "externalRedis.host is required when valkey.enabled=false" .Values.externalRedis.host | quote }} }
- { name: REDIS_PORT, value: {{ .Values.externalRedis.port | quote }} }
- { name: REDIS_SSL, value: {{ .Values.externalRedis.ssl | quote }} }
{{- with .Values.externalRedis.existingSecret }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ . }}, key: {{ $.Values.externalRedis.existingSecretPasswordKey }} }
{{- end }}
{{- end }}
- name: SECRET_KEY
  valueFrom:
    secretKeyRef: { name: {{ $s }}, key: secret-key }
- name: API_TOKEN_PEPPER
  valueFrom:
    secretKeyRef: { name: {{ $s }}, key: api-token-pepper }
- { name: ALLOWED_HOSTS, value: {{ join " " (concat (list $f (printf "%s.%s" $f .Release.Namespace) (printf "%s.%s.svc" $f .Release.Namespace) "localhost" "127.0.0.1") .Values.allowedHosts) | quote }} }
- { name: MEDIA_ROOT, value: /opt/netbox/media }
- { name: TIME_ZONE, value: {{ .Values.timeZone | quote }} }
- { name: LOGIN_REQUIRED, value: {{ .Values.loginRequired | quote }} }
- { name: METRICS_ENABLED, value: {{ .Values.metrics.enabled | quote }} }
{{- end -}}

{{/* Writable paths on the read-only root filesystem, plus the optional extra configuration. */}}
{{- define "netbox.mounts" -}}
- { name: tmp, mountPath: /tmp }
- { name: media, mountPath: /opt/netbox/media }
{{- if .Values.extraConfig }}
- { name: extra-config, mountPath: /etc/netbox/extra.py, subPath: extra.py, readOnly: true }
{{- end }}
{{- end -}}

{{- define "netbox.volumes" -}}
- { name: tmp, emptyDir: {} }
- name: media
  {{- if .Values.persistence.enabled }}
  persistentVolumeClaim: { claimName: {{ .Values.persistence.existingClaim | default (include "quench-common.fullname" .) }} }
  {{- else }}
  emptyDir: {}
  {{- end }}
{{- if .Values.extraConfig }}
- name: extra-config
  configMap: { name: {{ include "quench-common.fullname" . }}-extra }
{{- end }}
{{- end -}}

{{- define "netbox.checksum" -}}
{{- toJson (list (include "netbox.env" .) .Values.extraConfig .Values.tls) | sha256sum -}}
{{- end -}}
