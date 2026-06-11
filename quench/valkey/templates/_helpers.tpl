{{/* Secret holding the valkey password */}}
{{- define "valkey.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "valkey.secretPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}valkey-password{{- end -}}
{{- end -}}

{{/* Names */}}
{{- define "valkey.primary.fullname" -}}
{{- if eq .Values.architecture "replication" -}}{{ printf "%s-primary" (include "quench-common.fullname" .) }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "valkey.replica.fullname" -}}
{{- printf "%s-replica" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "valkey.configmapName" -}}
{{- if .Values.existingConfigmap -}}{{ .Values.existingConfigmap }}{{- else -}}{{ printf "%s-config" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{- define "valkey.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "valkey.tls.secretName" -}}
{{- .Values.tls.existingSecret -}}
{{- end -}}

{{/*
Shared server container. Call with a dict:
  (dict "root" . "replicaof" "<host>")   replicaof empty for a primary.
*/}}
{{- define "valkey.serverContainer" -}}
{{- $ := .root -}}
{{- $liveness := dict "tcpSocket" (dict "port" "valkey") "initialDelaySeconds" 10 "periodSeconds" 15 -}}
{{- $readiness := dict "exec" (dict "command" (list "valkey-cli" "ping")) "initialDelaySeconds" 5 "periodSeconds" 10 -}}
{{- if $.Values.tls.enabled -}}
{{- $readiness = dict "tcpSocket" (dict "port" "valkey") "initialDelaySeconds" 5 "periodSeconds" 10 -}}
{{- end -}}
- name: valkey
  image: {{ include "quench-common.image" $ }}
  imagePullPolicy: {{ $.Values.image.pullPolicy }}
  securityContext:
    {{- include "quench-common.containerSecurityContext" $ | nindent 4 }}
  {{- if or $.Values.auth.enabled $.Values.extraEnvVars }}
  env:
    {{- if $.Values.auth.enabled }}
    - name: VALKEY_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "valkey.secretName" $ }}
          key: {{ include "valkey.secretPasswordKey" $ }}
    # valkey-cli reads REDISCLI_AUTH (Valkey kept the redis-prefixed cli env vars),
    # so the readiness probe and `kubectl exec ... ping` authenticate automatically.
    - name: REDISCLI_AUTH
      valueFrom:
        secretKeyRef:
          name: {{ include "valkey.secretName" $ }}
          key: {{ include "valkey.secretPasswordKey" $ }}
    {{- end }}
    {{- include "quench-common.extraEnvVars" $ | nindent 4 }}
  {{- end }}
  {{- include "quench-common.envFrom" $ | nindent 2 }}
  args:
    - /etc/valkey/valkey.conf
    - "--dir"
    - "/data"
    {{- if $.Values.auth.enabled }}
    - "--requirepass"
    - "$(VALKEY_PASSWORD)"
    {{- end }}
    {{- if .replicaof }}
    - "--replicaof"
    - {{ .replicaof | quote }}
    {{- if $.Values.auth.enabled }}
    - "--masterauth"
    - "$(VALKEY_PASSWORD)"
    {{- end }}
    {{- end }}
    {{- if $.Values.tls.enabled }}
    - "--port"
    - "0"
    - "--tls-port"
    - "6379"
    - "--tls-cert-file"
    - "/etc/valkey/tls/{{ $.Values.tls.certFilename }}"
    - "--tls-key-file"
    - "/etc/valkey/tls/{{ $.Values.tls.keyFilename }}"
    - "--tls-ca-cert-file"
    - "/etc/valkey/tls/{{ $.Values.tls.caFilename }}"
    - "--tls-auth-clients"
    - {{ ternary "yes" "no" $.Values.tls.authClients | quote }}
    {{- end }}
    {{- range $.Values.extraFlags }}
    - {{ . | quote }}
    {{- end }}
  ports:
    - name: valkey
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
      mountPath: /etc/valkey
      readOnly: true
    {{- if $.Values.tls.enabled }}
    - name: tls
      mountPath: /etc/valkey/tls
      readOnly: true
    {{- end }}
    {{- include "quench-common.extraVolumeMounts" $ | nindent 4 }}
{{- end -}}

{{/* redis_exporter metrics sidecar */}}
{{- define "valkey.metricsContainer" -}}
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
          name: {{ include "valkey.secretName" $ }}
          key: {{ include "valkey.secretPasswordKey" $ }}
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
{{- define "valkey.podVolumes" -}}
{{- $ := .root -}}
- name: tmp
  emptyDir: {}
- name: config
  configMap:
    name: {{ include "valkey.configmapName" $ }}
{{- if $.Values.tls.enabled }}
- name: tls
  secret:
    secretName: {{ include "valkey.tls.secretName" $ }}
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
