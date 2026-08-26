{{- define "apisix.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* ConfigMap holding the rendered conf/config.yaml. */}}
{{- define "apisix.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Secret holding the Admin API key, and the key inside it. */}}
{{- define "apisix.adminSecretName" -}}
{{- if .Values.admin.existingSecret -}}{{ .Values.admin.existingSecret }}{{- else -}}{{ printf "%s-admin" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{- define "apisix.adminSecretKey" -}}
{{- if .Values.admin.existingSecret -}}{{ .Values.admin.existingSecretKey }}{{- else -}}admin-key{{- end -}}
{{- end -}}

{{/*
etcd client URLs. The bundled subchart wins when it is on -- its Service is
"<release>-etcd", the same shape argocd uses for its bundled Redis.
*/}}
{{- define "apisix.etcdHosts" -}}
{{- if .Values.etcd.enabled -}}
{{- list (printf "http://%s-etcd:%v" .Release.Name (dig "service" "clientPort" 2379 (.Values.etcd | default dict))) | toJson -}}
{{- else if .Values.etcdClient.hosts -}}
{{- .Values.etcdClient.hosts | toJson -}}
{{- else -}}
{{- fail "APISIX stores its whole configuration in etcd: keep etcd.enabled=true (bundled quench/etcd chart) or set etcdClient.hosts to an existing cluster." -}}
{{- end -}}
{{- end -}}

{{/*
The full conf/config.yaml, built as a map so config.extra can be deep-merged over
it rather than string-concatenated. Rendered into a ConfigMap and mounted over
conf/config.yaml; the image's entrypoint fills the rest of conf/ from its
read-only conf.default/ and then runs `apisix init`.
*/}}
{{- define "apisix.configYaml" -}}
{{- $cp := .Values.containerPorts -}}
{{- $apisix := dict
      "node_listen" (list $cp.http)
      "enable_control" true
      "control" (dict "ip" "0.0.0.0" "port" $cp.control)
      "ssl" (dict "enable" .Values.tls.enabled "listen" (list (dict "port" $cp.https)))
-}}
{{- $deployment := dict
      "role" "traditional"
      "role_traditional" (dict "config_provider" "etcd")
      "etcd" (dict
        "host" (include "apisix.etcdHosts" . | fromJsonArray)
        "prefix" .Values.etcdClient.prefix
        "timeout" .Values.etcdClient.timeout)
-}}
{{- if .Values.admin.enabled -}}
{{/* APISIX interpolates ${{VAR}} out of the environment when it loads config.yaml,
     so the key itself stays in a Secret and never lands in a ConfigMap. */}}
{{- $keyRef := printf "$%sAPISIX_ADMIN_KEY%s" "{{" "}}" -}}
{{- $_ := set $deployment "admin" (dict
      "allow_admin" .Values.admin.allowAdmin
      "admin_listen" (dict "ip" "0.0.0.0" "port" $cp.admin)
      "admin_key" (list (dict "name" "admin" "key" $keyRef "role" "admin"))) -}}
{{- else -}}
{{- $_ := set $apisix "enable_admin" false -}}
{{- end -}}
{{/* nginx creates five temp directories under the APISIX prefix at startup, which
     is a read-only rootfs here, so it would die with
       mkdir() "/usr/local/apisix/client_body_temp" failed (30: Read-only file system)
     APISIX does not template these paths but does expose an http snippet, so all
     five point at /tmp, which the Deployment backs with an emptyDir. */}}
{{- $snippet := join "\n" (list
      "client_body_temp_path /tmp/apisix-client-body-temp;"
      "proxy_temp_path       /tmp/apisix-proxy-temp;"
      "fastcgi_temp_path     /tmp/apisix-fastcgi-temp;"
      "uwsgi_temp_path       /tmp/apisix-uwsgi-temp;"
      "scgi_temp_path        /tmp/apisix-scgi-temp;") -}}
{{- $cfg := dict
      "apisix" $apisix
      "deployment" $deployment
      "nginx_config" (dict "http_configuration_snippet" (printf "%s\n" $snippet))
-}}
{{- if .Values.metrics.enabled -}}
{{/* Prometheus binds 127.0.0.1 by default, which nothing outside the pod can scrape. */}}
{{- $_ := set $cfg "plugin_attr" (dict "prometheus" (dict "export_addr" (dict "ip" "0.0.0.0" "port" $cp.metrics))) -}}
{{- end -}}
{{- $cfg = mergeOverwrite $cfg (deepCopy (.Values.config.extra | default dict)) -}}
{{- toYaml $cfg -}}
{{- end -}}

{{/* --- Ingress controller (optional component) --- */}}

{{- define "apisix.ingressController.name" -}}
{{- printf "%s-ingress-controller" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Its pods need their own selector, since they share the chart's release. */}}
{{- define "apisix.ingressController.selectorLabels" -}}
{{ include "quench-common.selectorLabels" . }}
app.kubernetes.io/component: ingress-controller
{{- end -}}

{{- define "apisix.ingressController.image" -}}
{{- $img := .Values.ingressController.image -}}
{{- $repo := required "ingressController.image.repository is required" $img.repository -}}
{{- $digest := required "ingressController.image.digest is required (QuenchWorks pins by digest, never a tag)" $img.digest -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}

{{- define "apisix.ingressController.configYaml" -}}
{{- $c := .Values.ingressController -}}
{{- $cfg := dict
      "log_level" $c.logLevel
      "probe_addr" (printf ":%v" $c.containerPorts.probe)
      "metrics_addr" (printf ":%v" $c.containerPorts.metrics)
      "leader_election" (dict "disable" false)
      "provider" (dict "type" "apisix" "sync_period" $c.syncPeriod)
-}}
{{- $cfg = mergeOverwrite $cfg (deepCopy ($c.config | default dict)) -}}
{{- toYaml $cfg -}}
{{- end -}}
