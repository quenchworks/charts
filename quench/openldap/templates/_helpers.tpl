{{/* Secret holding the slapd rootdn (admin) password */}}
{{- define "openldap.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "openldap.secretPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}admin-password{{- end -}}
{{- end -}}

{{- define "openldap.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service name for the StatefulSet */}}
{{- define "openldap.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* slapd rootdn, e.g. cn=admin,dc=example,dc=org */}}
{{- define "openldap.adminDN" -}}
{{- printf "cn=%s,%s" .Values.auth.adminUsername .Values.ldap.baseDN -}}
{{- end -}}

{{/* The dc attribute value of the base entry: the first RDN's value.
     dc=example,dc=org -> example */}}
{{- define "openldap.baseDCValue" -}}
{{- .Values.ldap.baseDN | splitList "," | first | splitList "=" | last | trim -}}
{{- end -}}

{{/* Config that the bootstrap init container renders, shared through an emptyDir */}}
{{- define "openldap.configFile" -}}/opt/quench/openldap/slapd.conf{{- end -}}
