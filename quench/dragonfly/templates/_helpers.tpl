{{/* Secret holding the dragonfly requirepass */}}
{{- define "dragonfly.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "dragonfly.secretPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}dragonfly-password{{- end -}}
{{- end -}}

{{- define "dragonfly.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Names. In standalone the primary is the sole node and keeps the base name so
     upgrades from a standalone release stay stable. */}}
{{- define "dragonfly.primary.fullname" -}}
{{- if eq .Values.architecture "replication" -}}{{ printf "%s-primary" (include "quench-common.fullname" .) }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "dragonfly.replica.fullname" -}}
{{- printf "%s-replica" (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "dragonfly.sentinel.fullname" -}}
{{- printf "%s-sentinel" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Stable DNS of the bootstrap primary (ordinal 0) that Sentinel first monitors
     and that a Sentinel-less replica statically replicates from. */}}
{{- define "dragonfly.primary.bootstrapHost" -}}
{{- $primary := include "dragonfly.primary.fullname" . -}}
{{- printf "%s-0.%s-headless.%s.svc.cluster.local" $primary $primary .Release.Namespace -}}
{{- end -}}

{{/* valkey-sentinel image (Sentinel role only), pinned by digest. Dragonfly ships
     no sentinel binary of its own. */}}
{{- define "dragonfly.sentinelImage" -}}
{{- $img := .Values.sentinel.image -}}
{{- $repo := required "sentinel.image.repository is required" $img.repository -}}
{{- $digest := required "sentinel.image.digest is required (pinned by digest, never a tag)" $img.digest -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}

{{/* Hardened busybox helper image (init containers only), pinned by digest. */}}
{{- define "dragonfly.busyboxImage" -}}
{{- $repo := required "busybox.repository is required" .Values.busybox.repository -}}
{{- $digest := required "busybox.digest is required (pinned by digest, never a tag)" .Values.busybox.digest -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}

{{/* Soft pod anti-affinity spreading a component's pods across nodes. Only used
     when the caller has not supplied its own .Values.affinity. Call with a dict:
     (dict "root" . "component" "sentinel"). */}}
{{- define "dragonfly.defaultAntiAffinity" -}}
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

{{/*
Master-discovery init container (busybox image). Resolves the current master from
Sentinel and writes a Dragonfly flagfile (/etc/dragonfly/node.flg) holding just the
dynamic `--replicaof` — the master pod gets an empty file. The dragonfly container
loads it via --flagfile, so a promoted replica keeps its role and a restarted old
primary rejoins as a replica. Call: (dict "root" . "isPrimary" bool).
*/}}
{{- define "dragonfly.discoverInitContainer" -}}
{{- $ := .root -}}
- name: discover-master
  image: {{ include "dragonfly.busyboxImage" $ }}
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
      value: {{ include "dragonfly.sentinel.fullname" $ | quote }}
    - name: SENTINEL_PORT
      value: {{ $.Values.sentinel.port | quote }}
    - name: MASTER_SET
      value: {{ $.Values.sentinel.masterSet | quote }}
    - name: BOOTSTRAP_HOST
      value: {{ include "dragonfly.primary.bootstrapHost" $ | quote }}
    - name: IS_PRIMARY
      value: {{ .isPrimary | ternary "true" "false" | quote }}
  volumeMounts:
    - name: scripts
      mountPath: /scripts
      readOnly: true
    - name: runtime-config
      mountPath: /etc/dragonfly
{{- end -}}

{{/*
Shared Dragonfly server container. Call with a dict:
  (dict "root" . "replicaof" "<host:port>" "isPrimary" bool "resources" ...)
Standalone keeps the image's env-based entrypoint (unchanged, validated default).
Replication runs the dragonfly binary directly (the entrypoint rebuilds its own arg
list and drops container args, so it cannot carry a --replicaof). When Sentinel HA
is on, the dynamic --replicaof comes from a flagfile the discover-master init
container wrote; without Sentinel, a static --replicaof points at the bootstrap primary.
*/}}
{{- define "dragonfly.serverContainer" -}}
{{- $ := .root -}}
{{- $replication := eq $.Values.architecture "replication" -}}
{{- $ha := and $replication $.Values.sentinel.enabled -}}
{{- $liveness := dict "tcpSocket" (dict "port" "redis") "initialDelaySeconds" 10 "periodSeconds" 15 -}}
{{- $readiness := dict "tcpSocket" (dict "port" "redis") "initialDelaySeconds" 5 "periodSeconds" 10 -}}
- name: dragonfly
  image: {{ include "quench-common.image" $ }}
  imagePullPolicy: {{ $.Values.image.pullPolicy }}
  securityContext:
    {{- include "quench-common.containerSecurityContext" $ | nindent 4 }}
  {{- if $replication }}
  command: ["dragonfly"]
  {{- end }}
  env:
    {{- if not $replication }}
    - name: DRAGONFLY_DATA_DIR
      value: /data
    # Keep epoll on under nonroot/kind/seccomp where io_uring is restricted.
    - name: DRAGONFLY_FORCE_EPOLL
      value: {{ ternary "1" "0" $.Values.config.forceEpoll | quote }}
    # Consistency contract: maxmemory MUST be >= threads * 256MiB or Dragonfly
    # refuses to start. Keep these aligned with the pod limit.
    - name: DRAGONFLY_PROACTOR_THREADS
      value: {{ $.Values.config.threads | quote }}
    - name: DRAGONFLY_MAXMEMORY
      value: {{ $.Values.config.maxmemory | quote }}
    {{- end }}
    {{- if $.Values.auth.enabled }}
    - name: DRAGONFLY_REQUIREPASS
      valueFrom:
        secretKeyRef:
          name: {{ include "dragonfly.secretName" $ }}
          key: {{ include "dragonfly.secretPasswordKey" $ }}
    {{- end }}
    {{- include "quench-common.extraEnvVars" $ | nindent 4 }}
  {{- include "quench-common.envFrom" $ | nindent 2 }}
  {{- if $replication }}
  args:
    - "--dir=/data"
    - "--bind=0.0.0.0"
    - "--port=6379"
    {{- if $.Values.config.forceEpoll }}
    - "--force_epoll"
    {{- end }}
    - "--proactor_threads={{ $.Values.config.threads }}"
    - "--maxmemory={{ $.Values.config.maxmemory }}"
    {{- if $.Values.auth.enabled }}
    - "--requirepass=$(DRAGONFLY_REQUIREPASS)"
    - "--masterauth=$(DRAGONFLY_REQUIREPASS)"
    {{- end }}
    {{- if $ha }}
    # Sentinel HA: discover-master init container writes --replicaof here (empty
    # file when Sentinel elected this pod as master).
    - "--flagfile=/etc/dragonfly/node.flg"
    {{- else if .replicaof }}
    # Static replication (no Sentinel): replicate from the bootstrap primary.
    - "--replicaof={{ .replicaof }}"
    {{- end }}
    {{- range $.Values.extraFlags }}
    - {{ . | quote }}
    {{- end }}
  {{- else }}
  {{- with $.Values.extraFlags }}
  args:
    {{- range . }}
    - {{ . | quote }}
    {{- end }}
  {{- end }}
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
    # Flagfile (--replicaof) written by the discover-master init container.
    - name: runtime-config
      mountPath: /etc/dragonfly
      readOnly: true
    {{- end }}
    {{- include "quench-common.extraVolumeMounts" $ | nindent 4 }}
{{- end -}}

{{/* Shared pod volumes for a data (primary/replica) pod. Call with a dict:
     (dict "root" . "persistence" .Values.primary.persistence). */}}
{{- define "dragonfly.podVolumes" -}}
{{- $ := .root -}}
- name: tmp
  emptyDir: {}
{{- if and (eq $.Values.architecture "replication") $.Values.sentinel.enabled }}
- name: scripts
  configMap:
    name: {{ printf "%s-scripts" (include "dragonfly.sentinel.fullname" $) }}
    defaultMode: 0555
- name: runtime-config
  emptyDir: {}
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

{{/* volumeClaimTemplate block for a data pod. Call: (dict "root" . "persistence" ...). */}}
{{- define "dragonfly.volumeClaimTemplate" -}}
{{- $ := .root -}}
- metadata:
    name: data
    {{- with .persistence.annotations }}
    annotations:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  spec:
    accessModes: {{ .persistence.accessModes }}
    {{- with .persistence.storageClass }}
    storageClassName: {{ . }}
    {{- end }}
    {{- with .persistence.selector }}
    selector:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    resources:
      requests:
        storage: {{ .persistence.size }}
{{- end -}}
