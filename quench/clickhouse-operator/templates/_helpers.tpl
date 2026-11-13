{{- define "clickhouse-operator.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "clickhouse-operator.exporterImage" -}}
{{- printf "%s@%s" .Values.metricsExporter.image.repository .Values.metricsExporter.image.digest -}}
{{- end -}}

{{- define "clickhouse-operator.ports" -}}
{{- toJson (list (dict "name" "op-metrics" "port" 9999 "protocol" "TCP") (dict "name" "ch-metrics" "port" 8888 "protocol" "TCP")) -}}
{{- end -}}

{{/* The nine upstream config folders: ConfigMap suffix and mount path under /etc/clickhouse-operator. */}}
{{- define "clickhouse-operator.configDirs" -}}
{{- toJson (list
  (dict "dir" "etc-clickhouse-operator-files" "mount" "")
  (dict "dir" "etc-clickhouse-operator-confd-files" "mount" "chi/conf.d")
  (dict "dir" "etc-clickhouse-operator-configd-files" "mount" "chi/config.d")
  (dict "dir" "etc-clickhouse-operator-templatesd-files" "mount" "chi/templates.d")
  (dict "dir" "etc-clickhouse-operator-usersd-files" "mount" "chi/users.d")
  (dict "dir" "etc-keeper-operator-confd-files" "mount" "chk/conf.d")
  (dict "dir" "etc-keeper-operator-configd-files" "mount" "chk/keeper_config.d")
  (dict "dir" "etc-keeper-operator-templatesd-files" "mount" "chk/templates.d")
  (dict "dir" "etc-keeper-operator-usersd-files" "mount" "chk/users.d")) -}}
{{- end -}}

{{- define "clickhouse-operator.env" -}}
- name: OPERATOR_POD_NODE_NAME
  valueFrom: { fieldRef: { fieldPath: spec.nodeName } }
- name: OPERATOR_POD_NAME
  valueFrom: { fieldRef: { fieldPath: metadata.name } }
- name: OPERATOR_POD_NAMESPACE
  valueFrom: { fieldRef: { fieldPath: metadata.namespace } }
- name: OPERATOR_POD_IP
  valueFrom: { fieldRef: { fieldPath: status.podIP } }
- name: OPERATOR_POD_SERVICE_ACCOUNT
  valueFrom: { fieldRef: { fieldPath: spec.serviceAccountName } }
- name: WATCH_NAMESPACES
  value: {{ (.Values.watchNamespaces | default (list ".*")) | join "," | quote }}
{{- end -}}

{{- define "clickhouse-operator.mounts" -}}
{{- $fn := include "quench-common.fullname" . -}}
{{- range (include "clickhouse-operator.configDirs" . | fromJsonArray) }}
- name: {{ .dir }}
  mountPath: /etc/clickhouse-operator{{ if .mount }}/{{ .mount }}{{ end }}
{{- end }}
- { name: ipc, mountPath: /etc/clickhouse-operator-ipc }
{{- end -}}
