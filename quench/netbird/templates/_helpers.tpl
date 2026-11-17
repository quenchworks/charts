{{/* One image reference per component: <repository>@<digest>. */}}
{{- define "netbird.image" -}}
{{- printf "%s@%s" .repository .digest -}}
{{- end -}}

{{- define "netbird.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* <fullname>-<component> */}}
{{- define "netbird.name" -}}
{{- printf "%s-%s" (include "quench-common.fullname" .ctx) .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Selector labels of one component: the release's plus app.kubernetes.io/component. */}}
{{- define "netbird.selectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* The public base URL every component and client uses: https://<domain>. */}}
{{- define "netbird.url" -}}
{{- printf "%s://%s" .Values.publicScheme (required "domain is required (the public host of the dashboard, API, signal and relay)" .Values.domain) -}}
{{- end -}}

{{- define "netbird.port" -}}
{{- if eq .Values.publicScheme "https" }}443{{ else }}80{{ end -}}
{{- end -}}

{{/* PostgreSQL DSN for the NetBird store and the embedded IdP (Dex). Needs $(DB_PASSWORD) from env. */}}
{{- define "netbird.dsnHostPart" -}}
{{- if .Values.postgresql.enabled -}}
host={{ .Release.Name }}-postgresql port=5432 user={{ .Values.postgresql.auth.username }} dbname={{ .Values.postgresql.auth.database }} sslmode=disable
{{- else -}}
host={{ required "externalDatabase.host" .Values.externalDatabase.host }} port={{ .Values.externalDatabase.port }} user={{ .Values.externalDatabase.username }} dbname={{ .Values.externalDatabase.database }} sslmode={{ .Values.externalDatabase.sslmode }}
{{- end -}}
{{- end -}}

{{- define "netbird.dbPasswordEnv" -}}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      {{- if .Values.postgresql.enabled }}
      name: {{ printf "%s-postgresql" .Release.Name }}
      key: postgres-password
      {{- else }}
      name: {{ required "externalDatabase.existingSecret" .Values.externalDatabase.existingSecret }}
      key: {{ .Values.externalDatabase.existingSecretKey }}
      {{- end }}
{{- end -}}

{{/* management.json, in a ConfigMap. Management reads it as a Go template over its environment
     (util.ReadJsonWithEnvSub), so every secret is a {{ .NB_* }} reference filled from the Secret and
     the database password at start. */}}
{{- define "netbird.managementConfig" -}}
{{- $url := include "netbird.url" . -}}
{{- $host := .Values.domain -}}
{{- $port := include "netbird.port" . -}}
{
  "Stuns": [{{- range $i, $s := .Values.stunServers }}{{ if $i }},{{ end }}{"Proto": "udp", "URI": {{ $s | quote }}, "Username": "", "Password": null}{{ end }}],
  "Relay": {
    "Addresses": [{{ printf "%s://%s:%s/relay" (ternary "rels" "rel" (eq .Values.publicScheme "https")) $host $port | quote }}],
    "CredentialsTTL": "24h",
    "Secret": "{{ "{{ ."}}NB_RELAY_SECRET{{" }}" }}"
  },
  "Signal": {
    "Proto": {{ .Values.publicScheme | quote }},
    "URI": {{ printf "%s:%s" $host $port | quote }},
    "Username": "",
    "Password": null
  },
  "ReverseProxy": {
    "TrustedHTTPProxies": {{ .Values.management.trustedProxies | toJson }},
    "TrustedHTTPProxiesCount": {{ len .Values.management.trustedProxies }},
    "TrustedPeers": []
  },
  "DisableDefaultPolicy": false,
  "Datadir": "/var/lib/netbird",
  "DataStoreEncryptionKey": "{{ "{{ ."}}NB_STORE_KEY{{" }}" }}",
  "StoreConfig": {"Engine": "postgres"},
  "EmbeddedIdP": {
    "Enabled": true,
    "Issuer": {{ printf "%s/oauth2" $url | quote }},
    "LocalAddress": "localhost:80",
    "Storage": {"Type": "postgres", "Config": {"DSN": "{{ "{{ ."}}NB_IDP_DSN{{" }}" }}"}},
    "DashboardRedirectURIs": [{{ printf "%s/nb-auth" $url | quote }}, {{ printf "%s/nb-silent-auth" $url | quote }}],
    "DashboardPostLogoutRedirectURIs": [{{ printf "%s/" $url | quote }}],
    "CLIRedirectURIs": ["http://localhost:53000/", "http://localhost:54000/"],
    "Owner": {"Email": {{ .Values.owner.email | quote }}, "Hash": "{{ "{{ ."}}NB_OWNER_HASH{{" }}" }}", "Username": {{ .Values.owner.username | quote }}},
    "SignKeyRefreshEnabled": true,
    "SessionCookieEncryptionKey": "{{ "{{ ."}}NB_IDP_SESSION_COOKIE_ENCRYPTION_KEY{{" }}" }}"
  }
}
{{- end -}}

{{/* Ports per component, for the NetworkPolicy. */}}
{{- define "netbird.ports" -}}
{{- toJson (list
  (dict "port" "http" "protocol" "TCP")
  (dict "port" "metrics" "protocol" "TCP")
  (dict "port" "signal" "protocol" "TCP")
  (dict "port" "relay" "protocol" "TCP")
  (dict "port" "dashboard" "protocol" "TCP")) -}}
{{- end -}}
