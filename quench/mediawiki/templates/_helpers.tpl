{{- define "mediawiki.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* sqlite | mysql | postgres, validated once here. */}}
{{- define "mediawiki.db.type" -}}
{{- $t := .Values.database.type -}}
{{- if not (has $t (list "sqlite" "mysql" "postgres")) -}}
{{- fail (printf "database.type must be sqlite, mysql or postgres, got %q" $t) -}}
{{- end -}}
{{- $t -}}
{{- end -}}

{{- define "mediawiki.db.external" -}}
{{- if ne (include "mediawiki.db.type" .) "sqlite" -}}true{{- end -}}
{{- end -}}

{{- define "mediawiki.db.host" -}}
{{- required "database.host is required for mysql and postgres" .Values.database.host -}}
{{- end -}}

{{- define "mediawiki.db.port" -}}
{{- if .Values.database.port -}}{{ .Values.database.port }}{{- else if eq (include "mediawiki.db.type" .) "postgres" -}}5432{{- else -}}3306{{- end -}}
{{- end -}}

{{/* Secret and key holding the DB password (external databases only). */}}
{{- define "mediawiki.db.secretName" -}}
{{- default (include "quench-common.fullname" .) .Values.database.existingSecret -}}
{{- end -}}
{{- define "mediawiki.db.secretKey" -}}
{{- if .Values.database.existingSecret -}}{{ .Values.database.existingSecretPasswordKey }}{{- else -}}db-password{{- end -}}
{{- end -}}

{{- define "mediawiki.admin.secretName" -}}
{{- default (include "quench-common.fullname" .) .Values.mediawiki.admin.existingSecret -}}
{{- end -}}
{{- define "mediawiki.admin.secretKey" -}}
{{- if .Values.mediawiki.admin.existingSecret -}}{{ .Values.mediawiki.admin.existingSecretPasswordKey }}{{- else -}}admin-password{{- end -}}
{{- end -}}

{{/* Where the SQLite files live (the data PVC mount). */}}
{{- define "mediawiki.sqliteDir" -}}/var/lib/mediawiki{{- end -}}

{{/* Env shared by the init container and the wiki container. LocalSettings.php
     reads the secrets from here, so they stay out of the ConfigMap and argv. */}}
{{- define "mediawiki.env" -}}
- name: MW_CONFIG_FILE
  value: /etc/mediawiki/local/LocalSettings.php
- name: MW_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "quench-common.fullname" . }}
      key: secret-key
- name: MW_UPGRADE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "quench-common.fullname" . }}
      key: upgrade-key
{{- if include "mediawiki.db.external" . }}
- name: MW_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "mediawiki.db.secretName" . }}
      key: {{ include "mediawiki.db.secretKey" . }}
{{- end }}
{{- end -}}

{{/* A value as a PHP single-quoted string literal: only \ and ' need escaping. */}}
{{- define "mediawiki.phpstr" -}}
'{{ . | toString | replace "\\" "\\\\" | replace "'" "\\'" }}'
{{- end -}}
