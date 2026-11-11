{{- define "pinot.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Selector labels for one component: pinot.selector (dict "ctx" . "component" "broker") */}}
{{- define "pinot.selector" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "pinot.zkAddress" -}}
{{- if .Values.zookeeper.enabled -}}
{{ printf "%s-zookeeper:2181" .Release.Name }}
{{- else -}}
{{- required "externalZookeeper.address is required when zookeeper.enabled is false" .Values.externalZookeeper.address -}}
{{- end -}}
{{- end -}}

{{/* A component's in-cluster host: <pod>.<headless service>.<namespace>.svc, set from $(POD_NAME) in args. */}}
{{- define "pinot.podHost" -}}
$(POD_NAME).{{ include "quench-common.fullname" .ctx }}-{{ .component }}.{{ .ctx.Release.Namespace }}.svc.cluster.local
{{- end -}}

{{/* Headless Service + StatefulSet for one component.
     args: dict ctx component values(map) cmd(list) ports(list of {name,port}) probe(path) persist(bool) */}}
{{- define "pinot.component" -}}
{{- $ := .ctx -}}
{{- $c := .component -}}
{{- $v := .values -}}
{{- $sel := dict "ctx" $ "component" $c -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "quench-common.fullname" $ }}-{{ $c }}
  labels:
    {{- include "quench-common.labels" $ | nindent 4 }}
    app.kubernetes.io/component: {{ $c }}
spec:
  clusterIP: None
  # Helix reaches every instance by its pod DNS name before it reports ready
  publishNotReadyAddresses: true
  ports:
    {{- range .ports }}
    - name: {{ .name }}
      port: {{ .port }}
      targetPort: {{ .name }}
    {{- end }}
  selector:
    {{- include "pinot.selector" $sel | nindent 4 }}
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "quench-common.fullname" $ }}-{{ $c }}
  labels:
    {{- include "quench-common.labels" $ | nindent 4 }}
    app.kubernetes.io/component: {{ $c }}
spec:
  replicas: {{ $v.replicas }}
  serviceName: {{ include "quench-common.fullname" $ }}-{{ $c }}
  podManagementPolicy: Parallel
  selector:
    matchLabels:
      {{- include "pinot.selector" $sel | nindent 6 }}
  template:
    metadata:
      {{- with $.Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "pinot.selector" $sel | nindent 8 }}
        {{- include "quench-common.podLabels" $ | nindent 8 }}
    spec:
      serviceAccountName: {{ include "pinot.serviceAccountName" $ }}
      securityContext:
        {{- include "quench-common.podSecurityContext" $ | nindent 8 }}
      {{- include "quench-common.podSpecFields" $ | nindent 6 }}
      containers:
        - name: {{ $c }}
          image: {{ include "quench-common.image" $ }}
          imagePullPolicy: {{ $.Values.image.pullPolicy }}
          securityContext:
            {{- include "quench-common.containerSecurityContext" $ | nindent 12 }}
          args:
            {{- toYaml .cmd | nindent 12 }}
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: JAVA_OPTS
              value: {{ $v.javaOpts | quote }}
            {{- include "quench-common.extraEnvVars" $ | nindent 12 }}
          ports:
            {{- range .ports }}
            - name: {{ .name }}
              containerPort: {{ .port }}
            {{- end }}
          startupProbe:
            httpGet: { path: {{ .probe }}, port: {{ (index .ports 0).name }} }
            periodSeconds: 5
            failureThreshold: 60
          readinessProbe:
            httpGet: { path: {{ .probe }}, port: {{ (index .ports 0).name }} }
            periodSeconds: 10
          livenessProbe:
            httpGet: { path: {{ .probe }}, port: {{ (index .ports 0).name }} }
            periodSeconds: 20
            failureThreshold: 6
          resources:
            {{- toYaml $v.resources | nindent 12 }}
          volumeMounts:
            - name: data
              mountPath: /var/pinot
            # logs, the JVM and segment builds write temp files; the root is read-only
            - name: tmp
              mountPath: /tmp
            {{- include "quench-common.extraVolumeMounts" $ | nindent 12 }}
      volumes:
        - name: tmp
          emptyDir: {}
        {{- if not (and .persist $v.persistence.enabled) }}
        - name: data
          emptyDir: {}
        {{- end }}
        {{- include "quench-common.extraVolumes" $ | nindent 8 }}
  {{- if and .persist $v.persistence.enabled }}
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        {{- with $v.persistence.storageClass }}
        storageClassName: {{ . }}
        {{- end }}
        resources:
          requests:
            storage: {{ $v.persistence.size }}
  {{- end }}
{{- end -}}
