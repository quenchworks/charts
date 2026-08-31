{{- define "mysql.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "mysql.rootPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretRootPasswordKey }}{{- else -}}mysql-root-password{{- end -}}
{{- end -}}

{{- define "mysql.passwordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}mysql-password{{- end -}}
{{- end -}}

{{- define "mysql.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "mysql.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Read-only Service name (Group Replication: selects the SECONDARY members). */}}
{{- define "mysql.readonlyName" -}}
{{- printf "%s-readonly" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Per-pod stable FQDN suffix under the headless Service. */}}
{{- define "mysql.podDomain" -}}
{{- printf "%s.%s.svc.cluster.local" (include "mysql.headlessName" .) .Release.Namespace -}}
{{- end -}}

{{/* group_replication_group_seeds — every pod's stable FQDN:33061, comma-separated. */}}
{{- define "mysql.groupSeeds" -}}
{{- $full := include "quench-common.fullname" . -}}
{{- $domain := include "mysql.podDomain" . -}}
{{- $members := list -}}
{{- range $i := until (int .Values.ha.replicaCount) -}}
{{- $members = append $members (printf "%s-%d.%s:33061" $full $i $domain) -}}
{{- end -}}
{{- join "," $members -}}
{{- end -}}

{{/* PDB quorum floor: majority of the group size (N/2 + 1). */}}
{{- define "mysql.haQuorum" -}}
{{- add (div (int .Values.ha.replicaCount) 2) 1 -}}
{{- end -}}

{{/* mysqld_exporter sidecar. Talks to the server over the pod's loopback (the flag
     default is localhost:3306, so no address is passed). The password is taken only
     from MYSQLD_EXPORTER_PASSWORD, never a DSN, so special characters need no
     URL-encoding. Shared by the standalone and Group Replication StatefulSets, so
     every member exposes its own metrics. */}}
{{- define "mysql.metricsContainer" -}}
{{- $ := .root -}}
- name: metrics
  image: {{ printf "%s@%s" $.Values.metrics.image.repository (required "metrics.image.digest is required" $.Values.metrics.image.digest) }}
  imagePullPolicy: {{ $.Values.metrics.image.pullPolicy }}
  securityContext:
    {{- include "quench-common.containerSecurityContext" $ | nindent 4 }}
  args:
    - --mysqld.username=root
    - --web.listen-address=:{{ $.Values.metrics.port }}
    {{- range $.Values.metrics.extraArgs }}
    - {{ . | quote }}
    {{- end }}
  env:
    - name: MYSQLD_EXPORTER_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "mysql.secretName" $ }}
          key: {{ include "mysql.rootPasswordKey" $ }}
  ports:
    - name: metrics
      containerPort: {{ $.Values.metrics.port }}
  resources:
    {{- toYaml $.Values.metrics.resources | nindent 4 }}
{{- end -}}
