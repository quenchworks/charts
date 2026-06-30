{{- define "envoy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding the Envoy bootstrap envoy.yaml. */}}
{{- define "envoy.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Which ConfigMap to mount at /etc/envoy: an external one wins, else the
     chart-rendered bootstrap ConfigMap. */}}
{{- define "envoy.mountedConfigMap" -}}
{{- if .Values.existingConfigMap -}}{{ .Values.existingConfigMap }}{{- else -}}{{ include "envoy.configMapName" . }}{{- end -}}
{{- end -}}

{{/* The --service-cluster value; defaults to the release name. */}}
{{- define "envoy.serviceCluster" -}}
{{- default .Release.Name .Values.serviceCluster -}}
{{- end -}}

{{/* The default Envoy bootstrap: admin on 0.0.0.0:9901 and one example listener
     on :10000 that returns a 200 direct_response so the pod is useful out-of-the-box. */}}
{{- define "envoy.defaultConfig" -}}
admin:
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 9901
static_resources:
  listeners:
    - name: listener_0
      address:
        socket_address:
          address: 0.0.0.0
          port_value: 10000
      filter_chains:
        - filters:
            - name: envoy.filters.network.http_connection_manager
              typed_config:
                "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                stat_prefix: ingress_http
                http_filters:
                  - name: envoy.filters.http.router
                    typed_config:
                      "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
                route_config:
                  name: local_route
                  virtual_hosts:
                    - name: local_service
                      domains: ["*"]
                      routes:
                        - match:
                            prefix: "/"
                          direct_response:
                            status: 200
                            body:
                              inline_string: "QuenchWorks Envoy is ready.\n"
{{- end -}}

{{/* The effective bootstrap: caller-provided config wins, else the default. */}}
{{- define "envoy.config" -}}
{{- if .Values.config -}}{{ .Values.config }}{{- else -}}{{ include "envoy.defaultConfig" . }}{{- end -}}
{{- end -}}
