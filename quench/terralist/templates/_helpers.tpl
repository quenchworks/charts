{{- define "terralist.oauthPrefix" -}}
{{- get (dict "github" "GH" "gitlab" "GL" "bitbucket" "BB" "oidc" "OI") .Values.oauth.provider -}}
{{- end -}}

{{- define "terralist.oauthSecretName" -}}
{{- default (include "quench-common.fullname" .) .Values.oauth.existingSecret -}}
{{- end -}}

{{- define "terralist.validate" -}}
{{- if not (include "terralist.oauthPrefix" .) -}}
{{- fail (printf "oauth.provider must be github, gitlab, bitbucket or oidc, got %q" .Values.oauth.provider) -}}
{{- end -}}
{{- if and (not .Values.oauth.existingSecret) (or (not .Values.oauth.clientId) (not .Values.oauth.clientSecret)) -}}
{{- fail "Terralist needs an OAuth app: set oauth.clientId and oauth.clientSecret, or oauth.existingSecret" -}}
{{- end -}}
{{- if and (ne .Values.database.type "sqlite") (not .Values.database.existingSecret) -}}
{{- fail "database.type postgresql or mysql needs database.existingSecret with the connection URL" -}}
{{- end -}}
{{- end -}}

{{/* the data volume holds SQLite and the local store; any other combination needs none */}}
{{- define "terralist.needsVolume" -}}
{{- if or (eq .Values.database.type "sqlite") (eq .Values.storage.resolver "local") }}true{{ end -}}
{{- end -}}
