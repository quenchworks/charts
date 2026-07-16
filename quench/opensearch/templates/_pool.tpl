{{/*
Renders one OpenSearch StatefulSet for a node pool. Called once per pool from
statefulset.yaml. In HA mode there are two pools (master, data); in single mode
there is one unnamed pool that reproduces the pre-0.1 single-node manifest.

Arg is a dict:
  ctx        root context (.)
  pool       "master" | "data" | ""   (""  => single node, bare fullname, no component label)
  cfg        the pool's values map (heapSize, persistence, resources[, replicaCount])
  replicas   replica count
  roles      node.roles CSV, e.g. "cluster_manager" or "data, ingest" ("" => all roles)
  discovery  discovery.type value ("zen" for cluster, "single-node" for single)
  bootstrap  bool: emit cluster.initial_cluster_manager_nodes (master pool only)
*/}}
{{- define "opensearch.statefulset" -}}
{{- $ctx := .ctx -}}
{{- $pool := .pool -}}
{{- $cfg := .cfg -}}
{{- $replicas := .replicas -}}
{{- $fullname := include "quench-common.fullname" $ctx -}}
{{- $name := $fullname -}}
{{- if $pool }}{{- $name = printf "%s-%s" $fullname $pool -}}{{- end -}}
{{- $headless := include "opensearch.headlessName" $ctx -}}
{{- $persistence := $cfg.persistence -}}
{{- $existingClaim := $persistence.existingClaim | default "" -}}
{{- $liveness := dict "tcpSocket" (dict "port" "http") "initialDelaySeconds" 60 "periodSeconds" 20 -}}
{{/* readiness via the cluster health endpoint; the runtime image ships no shell client */}}
{{- $readiness := dict "httpGet" (dict "path" "/_cluster/health" "port" "http") "initialDelaySeconds" 30 "periodSeconds" 10 "failureThreshold" 30 -}}
{{/* Static seed + bootstrap lists: the master pods' stable headless DNS / node names. */}}
{{- $masterReplicas := int $ctx.Values.master.replicaCount -}}
{{- $seedHosts := list -}}
{{- $bootstrapNodes := list -}}
{{- range $i := until $masterReplicas -}}
{{- $seedHosts = append $seedHosts (printf "%s-master-%d.%s" $fullname $i $headless) -}}
{{- $bootstrapNodes = append $bootstrapNodes (printf "%s-master-%d" $fullname $i) -}}
{{- end -}}
{{/* opensearch.yml lines the image appends via OPENSEARCH_CONFIG_EXTRA */}}
{{- $extra := list -}}
{{- if .roles }}{{- $extra = append $extra (printf "node.roles: [%s]" .roles) -}}{{- end -}}
{{- if eq .discovery "zen" -}}
{{- $quoted := list -}}
{{- range $h := $seedHosts }}{{- $quoted = append $quoted (printf "%q" $h) -}}{{- end -}}
{{- $extra = append $extra (printf "discovery.seed_hosts: [%s]" (join ", " $quoted)) -}}
{{- if .bootstrap -}}
{{- $qb := list -}}
{{- range $n := $bootstrapNodes }}{{- $qb = append $qb (printf "%q" $n) -}}{{- end -}}
{{- $extra = append $extra (printf "cluster.initial_cluster_manager_nodes: [%s]" (join ", " $qb)) -}}
{{- end -}}
{{- end -}}
{{- with $ctx.Values.config.extraConfig }}{{- $extra = append $extra . -}}{{- end -}}
{{- $sysctl := and $pool $ctx.Values.sysctls.enabled -}}
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ $name }}
  labels:
    {{- include "quench-common.labels" $ctx | nindent 4 }}
    {{- if $pool }}
    app.kubernetes.io/component: {{ $pool }}
    {{- end }}
spec:
  serviceName: {{ $headless }}
  replicas: {{ $replicas }}
  {{- if $pool }}
  # HA pools bootstrap together (a master can't be Ready before its peers exist),
  # so start pods in parallel rather than the OrderedReady default.
  podManagementPolicy: Parallel
  {{- end }}
  {{- with $ctx.Values.updateStrategy }}
  updateStrategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "quench-common.selectorLabels" $ctx | nindent 6 }}
      {{- if $pool }}
      app.kubernetes.io/component: {{ $pool }}
      {{- end }}
  template:
    metadata:
      {{- include "quench-common.podAnnotations" $ctx | nindent 6 }}
      labels:
        {{- include "quench-common.selectorLabels" $ctx | nindent 8 }}
        {{- if $pool }}
        app.kubernetes.io/component: {{ $pool }}
        {{- end }}
        {{- include "quench-common.podLabels" $ctx | nindent 8 }}
    spec:
      serviceAccountName: {{ include "opensearch.serviceAccountName" $ctx }}
      securityContext:
        {{- include "quench-common.podSecurityContext" $ctx | nindent 8 }}
      {{- include "quench-common.podSpecFields" $ctx | nindent 6 }}
      {{- if and (not $ctx.Values.affinity) (gt (int $replicas) 1) }}
      # Default: spread a pool's pods across nodes (soft, so a single-node kind
      # cluster still schedules). Set .Values.affinity to override entirely.
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchLabels:
                    {{- include "quench-common.selectorLabels" $ctx | nindent 20 }}
                    {{- if $pool }}
                    app.kubernetes.io/component: {{ $pool }}
                    {{- end }}
      {{- end }}
      {{- if or $sysctl $ctx.Values.initContainers }}
      initContainers:
        {{- if $sysctl }}
        # Raise vm.max_map_count for the OpenSearch bootstrap check. Privileged, but
        # only touches a node sysctl and only raises it; runs the pinned image.
        - name: sysctl
          image: {{ include "quench-common.image" $ctx }}
          imagePullPolicy: {{ $ctx.Values.image.pullPolicy }}
          command:
            - /bin/bash
            - -c
            - test "$(cat /proc/sys/vm/max_map_count)" -ge {{ $ctx.Values.sysctls.vmMaxMapCount }} || echo {{ $ctx.Values.sysctls.vmMaxMapCount }} > /proc/sys/vm/max_map_count
          securityContext:
            runAsNonRoot: false
            runAsUser: 0
            privileged: true
            allowPrivilegeEscalation: true
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
              add: ["SYS_ADMIN"]
        {{- end }}
        {{- with $ctx.Values.initContainers }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- end }}
      containers:
        - name: opensearch
          image: {{ include "quench-common.image" $ctx }}
          imagePullPolicy: {{ $ctx.Values.image.pullPolicy }}
          securityContext:
            {{- include "quench-common.containerSecurityContext" $ctx | nindent 12 }}
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            # read-only rootfs: keep config, data, and logs on the writable data volume
            - name: OPENSEARCH_PATH_DATA
              value: /data
            - name: OPENSEARCH_PATH_CONF
              value: /data/conf
            - name: OPENSEARCH_PATH_LOGS
              value: /data/logs
            - name: OPENSEARCH_NODE_NAME
              value: "$(POD_NAME)"
            - name: OPENSEARCH_CLUSTER_NAME
              value: {{ $ctx.Values.config.clusterName | quote }}
            - name: OPENSEARCH_HTTP_PORT
              value: {{ $ctx.Values.service.httpPort | quote }}
            - name: OPENSEARCH_TRANSPORT_PORT
              value: {{ $ctx.Values.service.transportPort | quote }}
            - name: OPENSEARCH_DISCOVERY_TYPE
              value: {{ .discovery | quote }}
            - name: OPENSEARCH_SECURITY_DISABLED
              value: {{ $ctx.Values.config.securityDisabled | quote }}
            - name: OPENSEARCH_JAVA_OPTS
              value: "-Xms{{ $cfg.heapSize }} -Xmx{{ $cfg.heapSize }}"
            {{- with $extra }}
            - name: OPENSEARCH_CONFIG_EXTRA
              value: {{ join "\n" . | quote }}
            {{- end }}
            {{- include "quench-common.extraEnvVars" $ctx | nindent 12 }}
          {{- include "quench-common.envFrom" $ctx | nindent 10 }}
          ports:
            - name: http
              containerPort: {{ $ctx.Values.service.httpPort }}
            - name: transport
              containerPort: {{ $ctx.Values.service.transportPort }}
          {{- include "quench-common.probe" (dict "ctx" $ctx "name" "liveness" "default" $liveness) | nindent 10 }}
          {{- include "quench-common.probe" (dict "ctx" $ctx "name" "readiness" "default" $readiness) | nindent 10 }}
          {{- with $ctx.Values.customStartupProbe }}
          startupProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- include "quench-common.lifecycleHooks" $ctx | nindent 10 }}
          resources:
            {{- toYaml $cfg.resources | nindent 12 }}
          volumeMounts:
            - name: data
              mountPath: /data
            {{- include "quench-common.extraVolumeMounts" $ctx | nindent 12 }}
        {{- include "quench-common.sidecars" $ctx | nindent 8 }}
      {{- if or (and $persistence.enabled $existingClaim) (not $persistence.enabled) $ctx.Values.extraVolumes }}
      volumes:
        {{- if and $persistence.enabled $existingClaim }}
        - name: data
          persistentVolumeClaim:
            claimName: {{ $existingClaim }}
        {{- else if not $persistence.enabled }}
        - name: data
          emptyDir: {}
        {{- end }}
        {{- include "quench-common.extraVolumes" $ctx | nindent 8 }}
      {{- end }}
  {{- if and $persistence.enabled (not $existingClaim) }}
  volumeClaimTemplates:
    - metadata:
        name: data
        {{- with $persistence.annotations }}
        annotations:
          {{- toYaml . | nindent 10 }}
        {{- end }}
      spec:
        accessModes: {{ $persistence.accessModes }}
        {{- with $persistence.storageClass }}
        storageClassName: {{ . }}
        {{- end }}
        {{- with $persistence.selector }}
        selector:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        resources:
          requests:
            storage: {{ $persistence.size }}
  {{- end }}
{{- end -}}
