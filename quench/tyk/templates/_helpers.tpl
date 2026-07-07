{{/* ServiceAccount name for the tyk pod. */}}
{{- define "tyk.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "quench-common.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Redis host. With the bundled subchart the primary Service is named
"<release>-redis" (the subchart reuses quench-common.fullname with chart name
"redis"); otherwise it is the externally provided host.
*/}}
{{- define "tyk.redisHost" -}}
{{- if .Values.redis.enabled -}}
{{- printf "%s-redis" .Release.Name -}}
{{- else -}}
{{- required "externalRedis.host is required when redis.enabled=false" .Values.externalRedis.host -}}
{{- end -}}
{{- end -}}

{{/* Redis port. Bundled subchart Service listens on 6379. */}}
{{- define "tyk.redisPort" -}}
{{- if .Values.redis.enabled -}}6379{{- else -}}{{ .Values.externalRedis.port }}{{- end -}}
{{- end -}}

{{/* --- Gateway secrets (api-secret / node-secret) --------------------------- */}}

{{- define "tyk.apiSecretName" -}}
{{- if .Values.gateway.existingSecret -}}{{ .Values.gateway.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "tyk.apiSecretKey" -}}
{{- if .Values.gateway.existingSecret -}}{{ .Values.gateway.existingSecretApiKey }}{{- else -}}api-secret{{- end -}}
{{- end -}}

{{- define "tyk.nodeSecretName" -}}
{{- if .Values.gateway.existingSecret -}}{{ .Values.gateway.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "tyk.nodeSecretKey" -}}
{{- if .Values.gateway.existingSecret -}}{{ .Values.gateway.existingSecretNodeKey }}{{- else -}}node-secret{{- end -}}
{{- end -}}

{{/*
Gateway control-API secret: explicit value, else the one already persisted in our
Secret, else a fresh random one. Referenced only from the Secret template so it
stays stable across upgrades.
*/}}
{{- define "tyk.apiSecret" -}}
{{- if .Values.gateway.secret -}}
{{- .Values.gateway.secret -}}
{{- else -}}
{{- $name := include "quench-common.fullname" . -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $name -}}
{{- if and $existing (index (default dict $existing.data) "api-secret") -}}
{{- index $existing.data "api-secret" | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Node secret: explicit value, else persisted, else random. */}}
{{- define "tyk.nodeSecret" -}}
{{- if .Values.gateway.nodeSecret -}}
{{- .Values.gateway.nodeSecret -}}
{{- else -}}
{{- $name := include "quench-common.fullname" . -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $name -}}
{{- if and $existing (index (default dict $existing.data) "node-secret") -}}
{{- index $existing.data "node-secret" | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* --- Redis password ------------------------------------------------------- */}}

{{/* Secret + key carrying the Redis password consumed as TYK_GW_STORAGE_PASSWORD. */}}
{{- define "tyk.redisPasswordSecretName" -}}
{{- if and (not .Values.redis.enabled) .Values.externalRedis.existingSecret -}}
{{- .Values.externalRedis.existingSecret -}}
{{- else -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "tyk.redisPasswordKey" -}}
{{- if and (not .Values.redis.enabled) .Values.externalRedis.existingSecret -}}
{{- .Values.externalRedis.existingSecretPasswordKey -}}
{{- else -}}
redis-password
{{- end -}}
{{- end -}}

{{/* Redis password value stored in the chart's own Secret (shared with the subchart). */}}
{{- define "tyk.redisPasswordValue" -}}
{{- if .Values.redis.enabled -}}
{{- if .Values.redis.auth.enabled -}}
{{- required "redis.auth.password is required (it is shared with tyk's storage.password) when redis.auth.enabled=true" .Values.redis.auth.password -}}
{{- end -}}
{{- else -}}
{{- .Values.externalRedis.password -}}
{{- end -}}
{{- end -}}

{{/* Whether this chart owns a Secret carrying the redis-password key. */}}
{{- define "tyk.ownsRedisPassword" -}}
{{- if not (and (not .Values.redis.enabled) .Values.externalRedis.existingSecret) -}}true{{- end -}}
{{- end -}}

{{/* Whether this chart creates its own Secret at all. */}}
{{- define "tyk.createsSecret" -}}
{{- $ownsGateway := not .Values.gateway.existingSecret -}}
{{- $ownsRedis := eq (include "tyk.ownsRedisPassword" .) "true" -}}
{{- if or $ownsGateway $ownsRedis -}}true{{- end -}}
{{- end -}}
