{{/*
Harbor umbrella-chart helpers. Component resources are named "<fullname>-<component>"
(e.g. rtest-harbor-core). The umbrella pins SEVEN images by digest, so it builds each
image reference directly from .Values.images.<component> rather than the single-image
quench-common.image helper.
*/}}

{{- define "harbor.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Per-component resource names. */}}
{{- define "harbor.core" -}}{{ printf "%s-core" (include "quench-common.fullname" .) }}{{- end -}}
{{- define "harbor.jobservice" -}}{{ printf "%s-jobservice" (include "quench-common.fullname" .) }}{{- end -}}
{{- define "harbor.registry" -}}{{ printf "%s-registry" (include "quench-common.fullname" .) }}{{- end -}}
{{- define "harbor.registryctl" -}}{{ printf "%s-registryctl" (include "quench-common.fullname" .) }}{{- end -}}
{{- define "harbor.portal" -}}{{ printf "%s-portal" (include "quench-common.fullname" .) }}{{- end -}}
{{- define "harbor.trivy" -}}{{ printf "%s-trivy" (include "quench-common.fullname" .) }}{{- end -}}
{{- define "harbor.exporter" -}}{{ printf "%s-exporter" (include "quench-common.fullname" .) }}{{- end -}}
{{/* The shared Secret carrying all generated/persisted credentials. */}}
{{- define "harbor.secret" -}}{{ include "quench-common.fullname" . }}{{- end -}}

{{/* Component selector labels — selectorLabels + a component discriminator. */}}
{{- define "harbor.componentLabels" -}}
{{- include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* Resolve a component image strictly by digest (factory contract; never a tag). */}}
{{- define "harbor.image" -}}
{{- $img := index .ctx.Values.images .component -}}
{{- $repo := required (printf "images.%s.repository is required" .component) $img.repository -}}
{{- $digest := required (printf "images.%s.digest is required (Quenchworks pins by digest)" .component) $img.digest -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}

{{/* In-cluster service hostnames (used in env + configs). */}}
{{- define "harbor.core.url" -}}http://{{ include "harbor.core" . }}{{- end -}}
{{- define "harbor.core.localURL" -}}http://{{ include "harbor.core" . }}:{{ .Values.core.service.port }}{{- end -}}
{{- define "harbor.portal.url" -}}http://{{ include "harbor.portal" . }}{{- end -}}
{{- define "harbor.registry.url" -}}http://{{ include "harbor.registry" . }}:{{ .Values.registry.service.port }}{{- end -}}
{{- define "harbor.registryctl.url" -}}http://{{ include "harbor.registryctl" . }}:{{ .Values.registry.registryctl.service.port }}{{- end -}}
{{- define "harbor.jobservice.url" -}}http://{{ include "harbor.jobservice" . }}:{{ .Values.jobservice.service.port }}{{- end -}}
{{- define "harbor.token.url" -}}http://{{ include "harbor.core" . }}:{{ .Values.core.service.port }}/service/token{{- end -}}
{{- define "harbor.trivy.url" -}}http://{{ include "harbor.trivy" . }}:{{ .Values.trivy.service.port }}{{- end -}}
{{/* The front-door proxy Service (the MAIN "harbor" service). */}}
{{- define "harbor.proxy" -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- define "harbor.proxy.url" -}}http://{{ include "harbor.proxy" . }}{{- if ne (.Values.proxy.service.port | toString) "80" }}:{{ .Values.proxy.service.port }}{{- end -}}{{- end -}}

{{/*
The external endpoint clients use (UI redirects + the /v2/ token-service audience).
Precedence: explicit externalURL -> ingress host -> the in-cluster front-door proxy
Service (so token realm + UI redirects resolve through the proxy) -> core as a last
resort if the proxy is disabled.
*/}}
{{- define "harbor.externalURL" -}}
{{- if .Values.externalURL -}}
{{- .Values.externalURL | trimSuffix "/" -}}
{{- else if .Values.ingress.enabled -}}
{{- $scheme := ternary "https" "http" .Values.ingress.tls.enabled -}}
{{- printf "%s://%s" $scheme .Values.ingress.host -}}
{{- else if .Values.proxy.enabled -}}
{{- include "harbor.proxy.url" . -}}
{{- else -}}
{{- include "harbor.core.url" . -}}
{{- end -}}
{{- end -}}

{{/*
CSRF trusted-origin HOSTS for harbor-core (CSRF_TRUSTED_ORIGINS).

QuenchWorks' harbor-core bumped github.com/gorilla/csrf to v1.7.3 (CVE-2025-24358),
which added a strict Origin/Referer check that rejects the browser's http:// Origin
against the server's assumed https://<host>, 403-ing every UI POST /c/login with
"origin invalid". Our harbor-core source patch passes csrf.TrustedOrigins(<hosts>);
gorilla compares HOST-only (scheme-agnostic), so listing the access host(s) here
makes UI login work over http and https.

Result is a comma-separated host list = the EXT_ENDPOINT (externalURL) host, plus
any extra hosts in .Values.core.csrfTrustedOrigins (a list of "host" or "host:port"
entries -- e.g. an alternate DNS name or a port-forward host like 127.0.0.1:8080).
*/}}
{{- define "harbor.csrfTrustedOrigins" -}}
{{- $hosts := list -}}
{{- $ext := include "harbor.externalURL" . -}}
{{- $u := urlParse $ext -}}
{{- with $u.host -}}{{- $hosts = append $hosts . -}}{{- end -}}
{{- range .Values.core.csrfTrustedOrigins -}}
{{- $h := . | toString | trim -}}
{{- if $h -}}{{- $hosts = append $hosts $h -}}{{- end -}}
{{- end -}}
{{- $hosts | uniq | join "," -}}
{{- end -}}

{{/* ---------------- Database wiring (bundled PG or external) ---------------- */}}
{{- define "harbor.db.host" -}}
{{- if .Values.postgresql.enabled -}}{{ printf "%s-postgresql" .Release.Name }}{{- else -}}{{ required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host }}{{- end -}}
{{- end -}}
{{- define "harbor.db.port" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}
{{- define "harbor.db.user" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.username }}{{- else -}}{{ .Values.externalDatabase.user }}{{- end -}}
{{- end -}}
{{- define "harbor.db.name" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.database }}{{- else -}}{{ .Values.externalDatabase.database }}{{- end -}}
{{- end -}}
{{- define "harbor.db.sslmode" -}}
{{- if .Values.postgresql.enabled -}}disable{{- else -}}{{ default "disable" .Values.externalDatabase.sslmode }}{{- end -}}
{{- end -}}
{{- define "harbor.db.password" -}}
{{- if .Values.postgresql.enabled -}}{{ .Values.postgresql.auth.password }}{{- else -}}{{ .Values.externalDatabase.password }}{{- end -}}
{{- end -}}

{{/* ---------------- Redis / Valkey wiring ---------------- */}}
{{- define "harbor.redis.host" -}}
{{- if .Values.valkey.enabled -}}{{ printf "%s-valkey" .Release.Name }}{{- else -}}{{ required "externalCache.host is required when valkey.enabled=false" .Values.externalCache.host }}{{- end -}}
{{- end -}}
{{- define "harbor.redis.port" -}}
{{- if .Values.valkey.enabled -}}6379{{- else -}}{{ .Values.externalCache.port }}{{- end -}}
{{- end -}}
{{- define "harbor.redis.password" -}}
{{- if .Values.valkey.enabled -}}
{{- if .Values.valkey.auth.enabled -}}{{ .Values.valkey.auth.password }}{{- end -}}
{{- else -}}{{ .Values.externalCache.password }}{{- end -}}
{{- end -}}
{{/* The "[:password@]" credential prefix for a redis URL. */}}
{{- define "harbor.redis.cred" -}}
{{- $pw := include "harbor.redis.password" . -}}
{{- if $pw -}}:{{ $pw }}@{{- end -}}
{{- end -}}
{{/* Build a redis URL for a given DB index: redis://[:pw@]host:port/<db> */}}
{{- define "harbor.redis.url" -}}
{{- printf "redis://%s%s:%s/%v" (include "harbor.redis.cred" .ctx) (include "harbor.redis.host" .ctx) (include "harbor.redis.port" .ctx) .db -}}
{{- end -}}
