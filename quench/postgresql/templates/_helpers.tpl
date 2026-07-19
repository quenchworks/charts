{{/* Secret holding the postgres superuser password */}}
{{- define "postgresql.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "postgresql.secretPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}postgres-password{{- end -}}
{{- end -}}

{{- define "postgresql.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Headless service name for the StatefulSet */}}
{{- define "postgresql.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Patroni cluster scope = the DCS key namespace (and cluster-name pod label). */}}
{{- define "postgresql.scope" -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}

{{/* HA service names */}}
{{- define "postgresql.primaryName" -}}
{{- printf "%s-primary" (include "quench-common.fullname" .) -}}
{{- end -}}
{{- define "postgresql.replicaName" -}}
{{- printf "%s-replica" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Soft pod anti-affinity spreading the Patroni members across nodes. Used only
     when the caller has not supplied its own .Values.affinity. */}}
{{- define "postgresql.haAntiAffinity" -}}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels:
            {{- include "quench-common.selectorLabels" . | nindent 12 }}
{{- end -}}
