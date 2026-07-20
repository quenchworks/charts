{{/* Secret holding the MongoDB root password */}}
{{- define "mongodb.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "mongodb.secretPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}mongodb-root-password{{- end -}}
{{- end -}}

{{- define "mongodb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service name for the StatefulSet */}}
{{- define "mongodb.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Per-pod stable FQDN suffix under the headless Service. */}}
{{- define "mongodb.podDomain" -}}
{{- printf "%s.%s.svc.cluster.local" (include "mongodb.headlessName" .) .Release.Namespace -}}
{{- end -}}

{{/* Secret holding the replica-set keyFile (intra-member auth). */}}
{{- define "mongodb.keyFileSecretName" -}}
{{- if .Values.ha.existingKeyFileSecret -}}{{ .Values.ha.existingKeyFileSecret }}{{- else -}}{{ printf "%s-keyfile" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}
{{- define "mongodb.keyFileSecretKey" -}}
{{- if .Values.ha.existingKeyFileSecret -}}{{ .Values.ha.existingKeyFileSecretKey }}{{- else -}}mongodb-keyfile{{- end -}}
{{- end -}}

{{/* Comma-separated replica-set member FQDNs (host:port), used for the connection
     string and rs.initiate(). */}}
{{- define "mongodb.replicaSetMembers" -}}
{{- $full := include "quench-common.fullname" . -}}
{{- $domain := include "mongodb.podDomain" . -}}
{{- $port := .Values.service.port -}}
{{- $members := list -}}
{{- range $i := until (int .Values.ha.replicaCount) -}}
{{- $members = append $members (printf "%s-%d.%s:%d" $full $i $domain (int $port)) -}}
{{- end -}}
{{- join "," $members -}}
{{- end -}}

{{/* rs.initiate() members[] as JS (single-quoted hosts, comma-joined). */}}
{{- define "mongodb.replicaSetMembersJS" -}}
{{- $full := include "quench-common.fullname" . -}}
{{- $domain := include "mongodb.podDomain" . -}}
{{- $port := int .Values.service.port -}}
{{- $out := list -}}
{{- range $i := until (int .Values.ha.replicaCount) -}}
{{- $out = append $out (printf "{_id:%d,host:'%s-%d.%s:%d'}" $i $full $i $domain $port) -}}
{{- end -}}
{{- join "," $out -}}
{{- end -}}
