{{- define "pgpool.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Backend wiring. When postgresql.enabled the bundled subchart's primary Service is named
"<release>-postgresql" (the subchart's quench-common.fullname resolves against its own
chart name "postgresql") and it is the single node; credentials come from
postgresql.auth. When external, the node list comes from `backends` and the credentials
from `auth`.

pgpool.backendList normalises both into a list of dicts {host, port, weight, flag}.
*/}}
{{- define "pgpool.backendList" -}}
{{- if .Values.postgresql.enabled -}}
{{- list (dict "host" (printf "%s-postgresql" .Release.Name) "port" 5432 "weight" 1 "flag" "ALLOW_TO_FAILOVER") | toJson -}}
{{- else -}}
{{- $out := list -}}
{{- range (required "backends must list at least one PostgreSQL node when postgresql.enabled=false" .Values.backends) -}}
{{- $out = append $out (dict "host" (required "each backends entry needs a host" .host) "port" (default 5432 .port) "weight" (default 1 .weight) "flag" (default "ALLOW_TO_FAILOVER" .flag)) -}}
{{- end -}}
{{- $out | toJson -}}
{{- end -}}
{{- end -}}

{{- define "pgpool.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.auth.database }}{{- end -}}
{{- end -}}

{{- define "pgpool.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.auth.username }}{{- end -}}
{{- end -}}

{{/*
Resolve the backend password (used to build the generated pool_passwd). With the bundled
PG it is the deterministic postgresql.auth.password. With external backends it is the
inline auth.password — when auth.existingSecret is used instead, pool_passwd must be
supplied via poolPasswd.existingSecret (we cannot read a Secret at render time).
*/}}
{{- define "pgpool.db.password" -}}
{{- if .Values.postgresql.enabled -}}
{{- required "postgresql.auth.password is required when postgresql.enabled=true" .Values.postgresql.auth.password -}}
{{- else -}}
{{- .Values.auth.password -}}
{{- end -}}
{{- end -}}

{{/* Name of the Secret holding pool_passwd (chart-managed, or user-provided). */}}
{{- define "pgpool.poolPasswdSecretName" -}}
{{- if .Values.poolPasswd.existingSecret -}}{{ .Values.poolPasswd.existingSecret }}{{- else -}}{{ printf "%s-passwd" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{/* Name of the Secret holding pcp.conf (chart-managed, or user-provided). */}}
{{- define "pgpool.pcpSecretName" -}}
{{- if .Values.pcp.existingSecret -}}{{ .Values.pcp.existingSecret }}{{- else -}}{{ printf "%s-pcp" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding pgpool.conf + pool_hba.conf. */}}
{{- define "pgpool.configMapName" -}}
{{- printf "%s-config" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/*
Render the full pgpool.conf. If pgpool.raw is set it is used verbatim.

Deliberately does NOT set logdir/work_dir: that parameter was renamed
(logdir <= 4.6, work_dir >= 4.7) and an unknown name is a startup FATAL, so we keep
pgpool's default of /tmp for pgpool_status and lock files — /tmp is a writable emptyDir
in the Deployment. Health-check and sr-check passwords are left EMPTY on purpose:
Pgpool-II then resolves them from pool_passwd (a Secret), so no credential ever lands in
this ConfigMap.
*/}}
{{- define "pgpool.conf" -}}
{{- if .Values.pgpool.raw -}}
{{ .Values.pgpool.raw }}
{{- else -}}
{{- $p := .Values.pgpool -}}
backend_clustering_mode = '{{ $p.clusteringMode }}'

listen_addresses = '*'
port = {{ .Values.service.port }}
unix_socket_directories = '/var/run/pgpool'

pcp_listen_addresses = '*'
pcp_port = {{ .Values.service.pcpPort }}
pcp_socket_dir = '/var/run/pgpool'

pid_file_name = '/var/run/pgpool/pgpool.pid'
log_destination = 'stderr'
logging_collector = off
log_min_messages = {{ $p.logMinMessages }}
log_connections = {{ $p.logConnections }}

enable_pool_hba = on
pool_passwd = '/etc/pgpool/pool_passwd'

num_init_children = {{ $p.numInitChildren }}
max_pool = {{ $p.maxPool }}
connection_cache = {{ $p.connectionCache }}
client_idle_limit = {{ $p.clientIdleLimit }}
load_balance_mode = {{ $p.loadBalanceMode }}
{{ range $i, $b := (include "pgpool.backendList" . | fromJsonArray) }}
backend_hostname{{ $i }} = '{{ $b.host }}'
backend_port{{ $i }} = {{ $b.port }}
backend_weight{{ $i }} = {{ $b.weight }}
backend_flag{{ $i }} = '{{ $b.flag }}'
{{- end }}

health_check_period = {{ $p.healthCheckPeriod }}
health_check_timeout = {{ $p.healthCheckTimeout }}
health_check_user = '{{ include "pgpool.db.user" . }}'
health_check_password = ''
health_check_database = '{{ include "pgpool.db.name" . }}'
health_check_max_retries = {{ $p.healthCheckMaxRetries }}
health_check_retry_delay = {{ $p.healthCheckRetryDelay }}

{{- if eq $p.clusteringMode "streaming_replication" }}
sr_check_period = {{ $p.srCheckPeriod }}
sr_check_user = '{{ include "pgpool.db.user" . }}'
sr_check_password = ''
sr_check_database = '{{ include "pgpool.db.name" . }}'
{{/* int64 or Helm's float64 round-trip renders 10000000 as "1e+07", which pgpool rejects. */}}
delay_threshold = {{ $p.delayThreshold | int64 }}
{{- end }}

# Failover is handled by Kubernetes / your PostgreSQL operator, not by shelling out:
# the runtime image has no shell, so no failover_command is configured.
failover_on_backend_error = off
{{- with $p.extraConfig }}

{{ . }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
pool_hba.conf — client authentication for connections arriving at Pgpool-II. Local
(unix socket) connections are trusted so the in-pod pcp/psql tooling works; TCP clients
must authenticate with pgpool.authMethod against pool_passwd.
*/}}
{{- define "pgpool.hba" -}}
# TYPE  DATABASE  USER  ADDRESS       METHOD
local   all       all                 trust
host    all       all   127.0.0.1/32  trust
host    all       all   ::1/128       trust
host    all       all   0.0.0.0/0     {{ .Values.pgpool.authMethod }}
host    all       all   ::/0          {{ .Values.pgpool.authMethod }}
{{- end -}}
