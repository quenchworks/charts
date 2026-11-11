{{- define "kroxylicious.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "kroxylicious.advertisedHost" -}}
{{- default (printf "%s.%s.svc.cluster.local" (include "quench-common.fullname" .) .Release.Namespace) .Values.gateway.advertisedHost -}}
{{- end -}}

{{/* One port per node id, after the bootstrap port, in nodeIdRanges order. That is how
     portIdentifiesNode assigns them; the Service and the container must list the same. */}}
{{- define "kroxylicious.nodePorts" -}}
{{- $port := add1 (int .Values.gateway.bootstrapPort) -}}
{{- range .Values.gateway.nodeIdRanges -}}
{{- range $id := untilStep (int .start) (add1 (int .end) | int) 1 }}
- name: node-{{ $id }}
  port: {{ $port }}
{{- $port = add1 $port }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "kroxylicious.config" -}}
{{- if .Values.config.raw -}}
{{ .Values.config.raw }}
{{- else -}}
{{- $_ := required "targetCluster.bootstrapServers is required (the Kafka cluster behind the proxy)" .Values.targetCluster.bootstrapServers -}}
management:
  endpoints:
    prometheus: {}
clusterDefinitions:
  - name: target
    bootstrapServers: {{ .Values.targetCluster.bootstrapServers }}
virtualClusters:
  - name: {{ include "quench-common.fullname" . }}
    target:
      cluster: target
    gateways:
      - name: default
        portIdentifiesNode:
          bootstrapAddress: 0.0.0.0:{{ .Values.gateway.bootstrapPort }}
          advertisedBrokerAddressPattern: {{ include "kroxylicious.advertisedHost" . }}
          nodeIdRanges:
            {{- toYaml .Values.gateway.nodeIdRanges | nindent 12 }}
        {{- if include "quench-common.tls.enabled" . }}
        tls:
          key:
            certificateFile: /tls/tls.crt
            privateKeyFile: /tls-pkcs8/tls.key
        {{- end }}
{{- with .Values.filterDefinitions }}
filterDefinitions:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.defaultFilters }}
defaultFilters:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
{{- end -}}
