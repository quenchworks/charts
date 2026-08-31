{{- define "mariadb.secretName" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecret }}{{- else -}}{{ include "quench-common.fullname" . }}{{- end -}}
{{- end -}}

{{- define "mariadb.rootPasswordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretRootPasswordKey }}{{- else -}}mariadb-root-password{{- end -}}
{{- end -}}

{{- define "mariadb.passwordKey" -}}
{{- if .Values.auth.existingSecret -}}{{ .Values.auth.existingSecretPasswordKey }}{{- else -}}mariadb-password{{- end -}}
{{- end -}}

{{- define "mariadb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "mariadb.headlessName" -}}
{{- printf "%s-headless" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Per-pod stable FQDN suffix under the headless Service. */}}
{{- define "mariadb.podDomain" -}}
{{- printf "%s.%s.svc.cluster.local" (include "mariadb.headlessName" .) .Release.Namespace -}}
{{- end -}}

{{/* gcomm:// member list — every pod's stable FQDN, comma-separated. */}}
{{- define "mariadb.galeraClusterAddress" -}}
{{- $full := include "quench-common.fullname" . -}}
{{- $domain := include "mariadb.podDomain" . -}}
{{- $members := list -}}
{{- range $i := until (int .Values.galera.replicaCount) -}}
{{- $members = append $members (printf "%s-%d.%s" $full $i $domain) -}}
{{- end -}}
{{- printf "gcomm://%s" (join "," $members) -}}
{{- end -}}

{{/* PDB quorum floor: majority of the galera node count (N/2 + 1). */}}
{{- define "mariadb.galeraQuorum" -}}
{{- add (div (int .Values.galera.replicaCount) 2) 1 -}}
{{- end -}}

{{/* mysqld_exporter sidecar. Talks to the server over the pod's loopback (the flag
     default is localhost:3306, so no address is passed). The password is taken only
     from MYSQLD_EXPORTER_PASSWORD, never a DSN, so special characters need no
     URL-encoding. Shared by the standalone and Galera StatefulSets, so every node
     exposes its own metrics. */}}
{{- define "mariadb.metricsContainer" -}}
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
          name: {{ include "mariadb.secretName" $ }}
          key: {{ include "mariadb.rootPasswordKey" $ }}
  ports:
    - name: metrics
      containerPort: {{ $.Values.metrics.port }}
  resources:
    {{- toYaml $.Values.metrics.resources | nindent 4 }}
{{- end -}}
