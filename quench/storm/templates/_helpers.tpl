{{- define "storm.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Selector labels for one component: storm.selector (dict "ctx" . "component" "nimbus") */}}
{{- define "storm.selector" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "storm.nimbusHost" -}}{{ include "quench-common.fullname" . }}-nimbus{{- end -}}

{{- define "storm.zookeeperServers" -}}
{{- if .Values.zookeeper.enabled -}}
{{ list (printf "%s-zookeeper" .Release.Name) | toJson }}
{{- else -}}
{{- if not .Values.externalZookeeper.servers }}{{ fail "externalZookeeper.servers is required when zookeeper.enabled is false" }}{{ end -}}
{{ .Values.externalZookeeper.servers | toJson }}
{{- end -}}
{{- end -}}

{{/* The pod spec every component shares; .component names it, .args are the storm args. */}}
{{- define "storm.podSpec" -}}
{{- $ := .ctx -}}
serviceAccountName: {{ include "storm.serviceAccountName" $ }}
securityContext:
  {{- include "quench-common.podSecurityContext" $ | nindent 2 }}
{{ include "quench-common.podSpecFields" $ }}
{{ include "quench-common.initContainers" $ }}
containers:
  - name: {{ .component }}
    image: {{ include "quench-common.image" $ }}
    imagePullPolicy: {{ $.Values.image.pullPolicy }}
    args: {{ .args | toJson }}
    securityContext:
      {{- include "quench-common.containerSecurityContext" $ | nindent 6 }}
    env:
      - name: POD_IP
        valueFrom: { fieldRef: { fieldPath: status.podIP } }
      {{- include "quench-common.extraEnvVars" $ | nindent 6 }}
    {{- include "quench-common.envFrom" $ | nindent 4 }}
    {{- with .ports }}
    ports:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .probe }}
    readinessProbe:
      {{- toYaml . | nindent 6 }}
    livenessProbe:
      {{- toYaml . | nindent 6 }}
      initialDelaySeconds: 60
    {{- end }}
    {{- include "quench-common.lifecycleHooks" $ | nindent 4 }}
    resources:
      {{- toYaml .resources | nindent 6 }}
    volumeMounts:
      - name: config
        mountPath: /opt/storm/conf/storm.yaml
        subPath: storm.yaml
      - name: data
        mountPath: /data
      - name: tmp
        mountPath: /tmp
      {{- include "quench-common.extraVolumeMounts" $ | nindent 6 }}
  {{- include "quench-common.sidecars" $ | nindent 2 }}
volumes:
  - name: config
    configMap:
      name: {{ include "quench-common.fullname" $ }}
  - name: tmp
    emptyDir: {}
  {{- if not .persistentData }}
  - name: data
    emptyDir: {}
  {{- end }}
  {{- include "quench-common.extraVolumes" $ | nindent 2 }}
{{- end -}}
