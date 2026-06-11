{{/* Secret holding the redis password */}}
{{- define "redis.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "redis.secretPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}redis-password{{- end -}}
{{- end -}}

{{/* Names */}}
{{- define "redis.primary.fullname" -}}
{{- if eq .Values.architecture "replication" -}}{{ printf "%s-primary" (include "quench-common.fullname" .) }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "redis.replica.fullname" -}}
{{- printf "%s-replica" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "redis.configmapName" -}}
{{- if .Values.existingConfigmap -}}{{ .Values.existingConfigmap }}{{- else -}}{{ printf "%s-config" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{- define "redis.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "redis.tls.secretName" -}}
{{- .Values.tls.existingSecret -}}
{{- end -}}

{{/*
Shared server container. Call with a dict:
  (dict "root" . "replicaof" "<host>")   replicaof empty for a primary.
*/}}
{{- define "redis.serverContainer" -}}
{{- $ := .root -}}
{{- $liveness := dict "tcpSocket" (dict "port" "redis") "initialDelaySeconds" 10 "periodSeconds" 15 -}}
{{- $readiness := dict "exec" (dict "command" (list "redis-cli" "ping")) "initialDelaySeconds" 5 "periodSeconds" 10 -}}
{{- if $.Values.tls.enabled -}}
{{- $readiness = dict "tcpSocket" (dict "port" "redis") "initialDelaySeconds" 5 "periodSeconds" 10 -}}
{{- end -}}
- name: redis
  image: {{ include "quench-common.image" $ }}
  imagePullPolicy: {{ $.Values.image.pullPolicy }}
  securityContext:
    {{- include "quench-common.containerSecurityContext" $ | nindent 4 }}
  {{- if or $.Values.auth.enabled $.Values.extraEnvVars }}
  env:
    {{- if $.Values.auth.enabled }}
    - name: REDIS_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "redis.secretName" $ }}
          key: {{ include "redis.secretPasswordKey" $ }}
    - name: REDISCLI_AUTH
      valueFrom:
        secretKeyRef:
          name: {{ include "redis.secretName" $ }}
          key: {{ include "redis.secretPasswordKey" $ }}
    {{- end }}
    {{- include "quench-common.extraEnvVars" $ | nindent 4 }}
  {{- end }}
  {{- include "quench-common.envFrom" $ | nindent 2 }}
  args:
    - /etc/redis/redis.conf
    - "--dir"
    - "/data"
    {{- if $.Values.auth.enabled }}
    - "--requirepass"
    - "$(REDIS_PASSWORD)"
    {{- end }}
    {{- if .replicaof }}
    - "--replicaof"
    - {{ .replicaof | quote }}
    {{- if $.Values.auth.enabled }}
    - "--masterauth"
    - "$(REDIS_PASSWORD)"
    {{- end }}
    {{- end }}
    {{- if $.Values.tls.enabled }}
    - "--port"
    - "0"
    - "--tls-port"
    - "6379"
    - "--tls-cert-file"
    - "/etc/redis/tls/{{ $.Values.tls.certFilename }}"
    - "--tls-key-file"
    - "/etc/redis/tls/{{ $.Values.tls.keyFilename }}"
    - "--tls-ca-cert-file"
    - "/etc/redis/tls/{{ $.Values.tls.caFilename }}"
    - "--tls-auth-clients"
    - {{ ternary "yes" "no" $.Values.tls.authClients | quote }}
    {{- end }}
    {{- range $.Values.extraFlags }}
    - {{ . | quote }}
    {{- end }}
  ports:
    - name: redis
      containerPort: 6379
  {{- include "quench-common.probe" (dict "ctx" $ "name" "liveness" "default" $liveness) | nindent 2 }}
  {{- include "quench-common.probe" (dict "ctx" $ "name" "readiness" "default" $readiness) | nindent 2 }}
  {{- with $.Values.customStartupProbe }}
  startupProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- include "quench-common.lifecycleHooks" $ | nindent 2 }}
  resources:
    {{- toYaml .resources | nindent 4 }}
  volumeMounts:
    - name: data
      mountPath: /data
    - name: tmp
      mountPath: /tmp
    - name: config
      mountPath: /etc/redis
      readOnly: true
    {{- if $.Values.tls.enabled }}
    - name: tls
      mountPath: /etc/redis/tls
      readOnly: true
    {{- end }}
    {{- include "quench-common.extraVolumeMounts" $ | nindent 4 }}
{{- end -}}

{{/* redis_exporter metrics sidecar */}}
{{- define "redis.metricsContainer" -}}
{{- $ := .root -}}
- name: metrics
  image: {{ printf "%s@%s" $.Values.metrics.image.repository (required "metrics.image.digest is required" $.Values.metrics.image.digest) }}
  imagePullPolicy: {{ $.Values.metrics.image.pullPolicy }}
  securityContext:
    {{- include "quench-common.containerSecurityContext" $ | nindent 4 }}
  env:
    - name: REDIS_ADDR
      value: {{ ternary "rediss://localhost:6379" "redis://localhost:6379" $.Values.tls.enabled | quote }}
    {{- if $.Values.auth.enabled }}
    - name: REDIS_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "redis.secretName" $ }}
          key: {{ include "redis.secretPasswordKey" $ }}
    {{- end }}
    {{- if $.Values.tls.enabled }}
    - name: REDIS_EXPORTER_SKIP_TLS_VERIFICATION
      value: "true"
    {{- end }}
  ports:
    - name: metrics
      containerPort: {{ $.Values.metrics.port }}
  resources:
    {{- toYaml $.Values.metrics.resources | nindent 4 }}
{{- end -}}

{{/* shared pod volumes */}}
{{- define "redis.podVolumes" -}}
{{- $ := .root -}}
- name: tmp
  emptyDir: {}
- name: config
  configMap:
    name: {{ include "redis.configmapName" $ }}
{{- if $.Values.tls.enabled }}
- name: tls
  secret:
    secretName: {{ include "redis.tls.secretName" $ }}
{{- end }}
{{- if and .persistence.enabled .persistence.existingClaim }}
- name: data
  persistentVolumeClaim:
    claimName: {{ .persistence.existingClaim }}
{{- else if not .persistence.enabled }}
- name: data
  emptyDir: {}
{{- end }}
{{- include "quench-common.extraVolumes" $ | nindent 0 }}
{{- end -}}
