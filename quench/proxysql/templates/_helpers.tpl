{{- define "proxysql.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
proxysql.cnf. Takes (dict "ctx" . "adminPassword" $pw) so the Secret template
computes the password once: a generated value would differ between two calls.
Strings go through `quote`, whose escapes (\" and \\) are valid libconfig.
*/}}
{{- define "proxysql.cnf" -}}
{{- $v := .ctx.Values -}}
datadir="/var/lib/proxysql"

admin_variables=
{
  admin_credentials={{ printf "admin:admin;%s:%s" $v.admin.username .adminPassword | quote }}
  mysql_ifaces="0.0.0.0:6032"
}

mysql_variables=
{
  threads={{ $v.threads }}
  max_connections={{ $v.maxConnections }}
  interfaces="0.0.0.0:6033"
  default_schema="information_schema"
  monitor_username={{ $v.monitor.username | quote }}
  monitor_password={{ $v.monitor.password | quote }}
}

mysql_servers=
(
{{- range $i, $s := $v.mysqlServers }}
  {{- if $i }},{{ end }}
  { address={{ $s.hostname | quote }}, port={{ $s.port | default 3306 }}, hostgroup={{ $s.hostgroup | default 0 }}, weight={{ $s.weight | default 1 }} }
{{- end }}
)

mysql_users=
(
{{- range $i, $u := $v.mysqlUsers }}
  {{- if $i }},{{ end }}
  { username={{ $u.username | quote }}, password={{ $u.password | quote }}, default_hostgroup={{ $u.defaultHostgroup | default 0 }}, active=1 }
{{- end }}
)

mysql_replication_hostgroups=
(
{{- range $i, $r := $v.replicationHostgroups }}
  {{- if $i }},{{ end }}
  { writer_hostgroup={{ $r.writerHostgroup }}, reader_hostgroup={{ $r.readerHostgroup }} }
{{- end }}
)
{{- with $v.extraConfig }}

{{ . }}
{{- end }}
{{- end -}}
