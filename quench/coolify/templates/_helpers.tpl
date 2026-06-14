{{/*
Coolify umbrella-chart helpers. The control plane is two workloads — the app
(php-fpm + nginx + Horizon + scheduler) and the realtime tier (soketi + terminal) —
named "<fullname>-app" and "<fullname>-realtime". Backing stores are the bundled
postgresql (overridden to postgresql-15) and redis subcharts, or external* fallbacks.

The umbrella pins two images by digest, so it builds each reference from
.Values.images.<component> rather than the single-image quench-common.image helper.
*/}}

{{- define "coolify.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Per-component resource names. */}}
{{- define "coolify.app" -}}{{ printf "%s-app" (include "quench-common.fullname" .) }}{{- end -}}
{{- define "coolify.realtime" -}}{{ printf "%s-realtime" (include "quench-common.fullname" .) }}{{- end -}}
{{/* The shared Secret carrying every generated/persisted credential + the rendered .env. */}}
{{- define "coolify.secret" -}}{{ include "quench-common.fullname" . }}{{- end -}}

{{/* Component selector labels — selectorLabels + a component discriminator. */}}
{{- define "coolify.componentLabels" -}}
{{- include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* Resolve a component image strictly by digest (factory contract; never a tag). */}}
{{- define "coolify.image" -}}
{{- $img := index .ctx.Values.images .component -}}
{{- $repo := required (printf "images.%s.repository is required" .component) $img.repository -}}
{{- $digest := required (printf "images.%s.digest is required (Quenchworks pins by digest)" .component) $img.digest -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}

{{/* In-cluster Service hostnames. */}}
{{- define "coolify.app.url" -}}http://{{ include "coolify.app" . }}:{{ .Values.app.service.port }}{{- end -}}

{{/* The public URL Coolify builds redirects against (APP_URL). */}}
{{- define "coolify.externalURL" -}}
{{- if .Values.app.url -}}
{{- .Values.app.url | trimSuffix "/" -}}
{{- else if .Values.ingress.enabled -}}
{{- $scheme := ternary "https" "http" .Values.ingress.tls.enabled -}}
{{- printf "%s://%s" $scheme .Values.ingress.host -}}
{{- else -}}
{{- include "coolify.app.url" . -}}
{{- end -}}
{{- end -}}

{{/* ---------------- Database wiring (bundled PG15 or external) ---------------- */}}
{{- define "coolify.db.host" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host }}{{- end -}}
{{- end -}}
{{- define "coolify.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}
{{- define "coolify.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}
{{- define "coolify.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}
{{- define "coolify.db.password" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.password }}{{- else -}}{{ .Values.externalDatabase.password }}{{- end -}}
{{- end -}}

{{/* ---------------- Redis wiring (bundled or external) ---------------- */}}
{{- define "coolify.redis.host" -}}
{{- if .Values.redis.enabled -}}{{ printf "%s-redis" .Release.Name }}{{- else -}}{{ required "externalRedis.host is required when redis.enabled=false" .Values.externalRedis.host }}{{- end -}}
{{- end -}}
{{- define "coolify.redis.port" -}}
{{- if .Values.redis.enabled -}}6379{{- else -}}{{ .Values.externalRedis.port }}{{- end -}}
{{- end -}}
{{- define "coolify.redis.password" -}}
{{- if .Values.redis.enabled -}}
{{- if .Values.redis.auth.enabled -}}{{ .Values.redis.auth.password }}{{- end -}}
{{- else -}}{{ .Values.externalRedis.password }}{{- end -}}
{{- end -}}
