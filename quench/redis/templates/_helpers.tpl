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

{{- define "redis.sentinel.fullname" -}}
{{- printf "%s-sentinel" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Stable DNS of the bootstrap primary (ordinal 0) that Sentinel first monitors. */}}
{{- define "redis.primary.bootstrapHost" -}}
{{- $primary := include "redis.primary.fullname" . -}}
{{- printf "%s-0.%s-headless.%s.svc.cluster.local" $primary $primary .Release.Namespace -}}
{{- end -}}

{{/* Soft pod anti-affinity spreading a component's pods across nodes. Only used
     when the caller has not supplied its own .Values.affinity. Call with a dict:
     (dict "root" . "component" "sentinel"). */}}
{{- define "redis.defaultAntiAffinity" -}}
{{- $ := .root -}}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels:
            {{- include "quench-common.selectorLabels" $ | nindent 12 }}
            app.kubernetes.io/component: {{ .component }}
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

{{/* Hardened busybox helper image (init containers only), pinned by digest. */}}
{{- define "redis.busyboxImage" -}}
{{- $repo := required "busybox.repository is required" .Values.busybox.repository -}}
{{- $digest := required "busybox.digest is required (pinned by digest, never a tag)" .Values.busybox.digest -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}

{{/*
Master-discovery init container (busybox image). Resolves the current master from
Sentinel and writes a runtime redis.conf (base + replicaof) into an emptyDir the
shell-free redis container then loads. Call: (dict "root" . "isPrimary" bool).
*/}}
{{- define "redis.discoverInitContainer" -}}
{{- $ := .root -}}
- name: discover-master
  image: {{ include "redis.busyboxImage" $ }}
  imagePullPolicy: {{ $.Values.busybox.pullPolicy }}
  securityContext:
    {{- include "quench-common.containerSecurityContext" $ | nindent 4 }}
  command: ["sh", "/scripts/start-node.sh"]
  env:
    - name: MY_POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: SENTINEL_SVC
      value: {{ include "redis.sentinel.fullname" $ | quote }}
    - name: SENTINEL_PORT
      value: {{ $.Values.sentinel.port | quote }}
    - name: MASTER_SET
      value: {{ $.Values.sentinel.masterSet | quote }}
    - name: BOOTSTRAP_HOST
      value: {{ include "redis.primary.bootstrapHost" $ | quote }}
    - name: IS_PRIMARY
      value: {{ .isPrimary | ternary "true" "false" | quote }}
  volumeMounts:
    - name: scripts
      mountPath: /scripts
      readOnly: true
    - name: config
      mountPath: /seed
      readOnly: true
    - name: runtime-config
      mountPath: /etc/redis
{{- end -}}

{{/*
Shared server container. Call with a dict:
  (dict "root" . "replicaof" "<host>" "isPrimary" true "resources" ...)
When sentinel HA is on, the pod discovers its master from Sentinel at boot
(start-node.sh) instead of using a static --replicaof, so a promoted replica
keeps its role and a restarted old primary rejoins as a replica.
*/}}
{{- define "redis.serverContainer" -}}
{{- $ := .root -}}
{{- $ha := and (eq $.Values.architecture "replication") $.Values.sentinel.enabled -}}
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
    {{- if and .replicaof (not $ha) }}
    - "--replicaof"
    - {{ .replicaof | quote }}
    {{- end }}
    {{- if and $.Values.auth.enabled (or .replicaof $ha) }}
    - "--masterauth"
    - "$(REDIS_PASSWORD)"
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
    {{- if $ha }}
    # Runtime config written by the discover-master init container (base + replicaof).
    - name: runtime-config
      mountPath: /etc/redis
      readOnly: true
    {{- else }}
    - name: config
      mountPath: /etc/redis
      readOnly: true
    {{- end }}
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
{{- if and (eq $.Values.architecture "replication") $.Values.sentinel.enabled }}
- name: scripts
  configMap:
    name: {{ printf "%s-scripts" (include "redis.sentinel.fullname" $) }}
    defaultMode: 0555
- name: runtime-config
  emptyDir: {}
{{- end }}
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
