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
Role checks. Every template asks these instead of reading .Values.role itself, so
the rules live in one place. "true" or empty, for use in `if`.
*/}}
{{- define "apisix.validate" -}}
{{- $role := .Values.role -}}
{{- if not (has $role (list "traditional" "control_plane" "data_plane" "standalone")) -}}
{{- fail (printf "role must be traditional, control_plane, data_plane or standalone, not %q" $role) -}}
{{- end -}}
{{- if and (eq $role "standalone") (not (has .Values.standalone.mode (list "file" "api"))) -}}
{{- fail (printf "standalone.mode must be file or api, not %q" .Values.standalone.mode) -}}
{{- end -}}
{{- if and (has $role (list "data_plane" "standalone")) .Values.etcd.enabled -}}
{{- fail (printf "role=%s runs no etcd of its own: set etcd.enabled=false (a data plane reads the control plane's etcd through etcdClient.hosts)" $role) -}}
{{- end -}}
{{- if and (eq $role "control_plane") (ne .Values.service.type "ClusterIP") -}}
{{- fail "role=control_plane keeps the Admin API inside the cluster: service.type must be ClusterIP (put the LoadBalancer on the data plane release)" -}}
{{- end -}}
{{- if and (eq $role "control_plane") .Values.ingress.enabled -}}
{{- fail "role=control_plane does not proxy: ingress.enabled belongs on a data plane or traditional release" -}}
{{- end -}}
{{- if and (or (eq $role "control_plane") (and (eq $role "standalone") (eq .Values.standalone.mode "api"))) (not .Values.admin.enabled) -}}
{{- fail (printf "role=%s is driven through the Admin API: keep admin.enabled=true" $role) -}}
{{- end -}}
{{- if and .Values.etcdClient.tls.existingSecret .Values.etcdClient.tls.verify (not .Values.etcdClient.tls.sni) -}}
{{- fail "etcdClient.tls.sni is required with verify=true: APISIX sends no server name otherwise and every etcd handshake fails" -}}
{{- end -}}
{{- end -}}

{{- define "apisix.usesEtcd" -}}
{{- if ne .Values.role "standalone" }}true{{ end -}}
{{- end -}}

{{- define "apisix.proxies" -}}
{{- if ne .Values.role "control_plane" }}true{{ end -}}
{{- end -}}

{{/* data_plane cannot run the Admin API (APISIX rejects the config), and file-driven
     standalone has nothing for it to write to. */}}
{{- define "apisix.adminOn" -}}
{{- if and .Values.admin.enabled (not (eq .Values.role "data_plane")) (not (and (eq .Values.role "standalone") (eq .Values.standalone.mode "file"))) }}true{{ end -}}
{{- end -}}

{{/* conf/apisix.yaml for file-driven standalone. APISIX refuses the file without #END. */}}
{{- define "apisix.standaloneYaml" -}}
{{- toYaml (.Values.standalone.config | default dict) }}
#END
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
{{- $role := .Values.role -}}
{{- $deployment := dict -}}
{{- if eq $role "standalone" -}}
{{/* file: APISIX's data_plane role on yaml is its file-driven standalone mode.
     api: traditional on yaml keeps the Admin API, and its /apisix/admin/configs
     endpoint replaces the in-memory config whole. */}}
{{- $r := ternary "data_plane" "traditional" (eq .Values.standalone.mode "file") -}}
{{- $_ := set $deployment "role" $r -}}
{{- $_ := set $deployment (printf "role_%s" $r) (dict "config_provider" "yaml") -}}
{{- else -}}
{{- $_ := set $deployment "role" $role -}}
{{- $_ := set $deployment (printf "role_%s" $role) (dict "config_provider" "etcd") -}}
{{- $etcd := dict
      "host" (include "apisix.etcdHosts" . | fromJsonArray)
      "prefix" .Values.etcdClient.prefix
      "timeout" .Values.etcdClient.timeout -}}
{{- with .Values.etcdClient.tls -}}
{{- if .existingSecret -}}
{{- $tls := dict "cert" "/etc/apisix/etcd-tls/tls.crt" "key" "/etc/apisix/etcd-tls/tls.key" "verify" .verify -}}
{{- if .sni }}{{ $_ := set $tls "sni" .sni }}{{ end -}}
{{- $_ := set $etcd "tls" $tls -}}
{{/* APISIX checks etcd's server certificate against its global trust store. */}}
{{- $_ := set $apisix.ssl "ssl_trusted_certificate" "/etc/apisix/etcd-tls/ca.crt" -}}
{{- end -}}
{{- end -}}
{{- $_ := set $deployment "etcd" $etcd -}}
{{- end -}}
{{- if include "apisix.adminOn" . -}}
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
