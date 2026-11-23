{{/* The web port: uWSGI on 8080 (plain HTTP; the bundled pyuwsgi has no TLS, terminate it at an Ingress). */}}
{{- define "nautobot.ports" -}}
{{- toJson (list (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{- define "nautobot.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Settings shared by every Nautobot container; Nautobot's settings read them directly. */}}
{{- define "nautobot.env" -}}
{{- $s := include "nautobot.secretName" . -}}
{{- $f := include "quench-common.fullname" . -}}
{{- if .Values.postgresql.enabled }}
- { name: NAUTOBOT_DB_HOST, value: {{ printf "%s-postgresql" .Release.Name | quote }} }
- { name: NAUTOBOT_DB_PORT, value: "5432" }
- { name: NAUTOBOT_DB_NAME, value: {{ .Values.postgresql.auth.database | quote }} }
- { name: NAUTOBOT_DB_USER, value: {{ .Values.postgresql.auth.username | quote }} }
- name: NAUTOBOT_DB_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-postgresql" .Release.Name }}, key: postgres-password }
{{- else }}
- { name: NAUTOBOT_DB_HOST, value: {{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host | quote }} }
- { name: NAUTOBOT_DB_PORT, value: {{ .Values.externalDatabase.port | quote }} }
- { name: NAUTOBOT_DB_NAME, value: {{ .Values.externalDatabase.database | quote }} }
- { name: NAUTOBOT_DB_USER, value: {{ .Values.externalDatabase.username | quote }} }
- name: NAUTOBOT_DB_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ required "externalDatabase.existingSecret is required when postgresql.enabled=false" .Values.externalDatabase.existingSecret }}, key: {{ .Values.externalDatabase.existingSecretPasswordKey }} }
{{- end }}
{{- if .Values.valkey.enabled }}
- { name: NAUTOBOT_REDIS_HOST, value: {{ printf "%s-valkey" .Release.Name | quote }} }
- name: NAUTOBOT_REDIS_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ printf "%s-valkey" .Release.Name }}, key: valkey-password }
{{- else }}
- { name: NAUTOBOT_REDIS_HOST, value: {{ required "externalRedis.host is required when valkey.enabled=false" .Values.externalRedis.host | quote }} }
- { name: NAUTOBOT_REDIS_PORT, value: {{ .Values.externalRedis.port | quote }} }
- { name: NAUTOBOT_REDIS_SSL, value: {{ .Values.externalRedis.ssl | quote }} }
{{- with .Values.externalRedis.existingSecret }}
- name: NAUTOBOT_REDIS_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ . }}, key: {{ $.Values.externalRedis.existingSecretPasswordKey }} }
{{- end }}
{{- end }}
- name: NAUTOBOT_SECRET_KEY
  valueFrom:
    secretKeyRef: { name: {{ $s }}, key: secret-key }
- { name: NAUTOBOT_ALLOWED_HOSTS, value: {{ join " " (concat (list $f (printf "%s.%s" $f .Release.Namespace) (printf "%s.%s.svc" $f .Release.Namespace) "localhost" "127.0.0.1") .Values.allowedHosts) | quote }} }
{{- with .Values.csrfTrustedOrigins }}
- { name: NAUTOBOT_CSRF_TRUSTED_ORIGINS, value: {{ join "," . | quote }} }
{{- end }}
- { name: NAUTOBOT_INSTALLATION_METRICS_ENABLED, value: "False" }
{{- range $k, $v := .Values.settings }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{- end -}}

{{- define "nautobot.mounts" -}}
- { name: tmp, mountPath: /tmp }
- { name: data, mountPath: /var/lib/nautobot }
{{- if .Values.extraConfig }}
- { name: extra-config, mountPath: /etc/nautobot/extra.py, subPath: extra.py, readOnly: true }
{{- end }}
{{- end -}}

{{- define "nautobot.volumes" -}}
- { name: tmp, emptyDir: {} }
- name: data
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

{{- define "nautobot.checksum" -}}
{{- toJson (list (include "nautobot.env" .) .Values.extraConfig) | sha256sum -}}
{{- end -}}
