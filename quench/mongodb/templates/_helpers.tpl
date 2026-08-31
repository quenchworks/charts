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

{{/* percona mongodb_exporter sidecar. Connects over the pod's loopback with
     --mongodb.direct-connect so each member reports ITS OWN state rather than being
     redirected to the replica-set primary by topology discovery. Credentials go in
     as MONGODB_USER/MONGODB_PASSWORD, not inside the URI, so a password with URI
     metacharacters needs no percent-encoding. Shared by the standalone and
     replica-set StatefulSets. */}}
{{- define "mongodb.metricsContainer" -}}
{{- $ := .root -}}
- name: metrics
  image: {{ printf "%s@%s" $.Values.metrics.image.repository (required "metrics.image.digest is required" $.Values.metrics.image.digest) }}
  imagePullPolicy: {{ $.Values.metrics.image.pullPolicy }}
  securityContext:
    {{- include "quench-common.containerSecurityContext" $ | nindent 4 }}
  args:
    - --mongodb.uri=mongodb://localhost:{{ $.Values.service.port }}/admin
    - --mongodb.direct-connect
    - --web.listen-address=:{{ $.Values.metrics.port }}
    {{- /* WITHOUT an explicit --collector.* flag this exporter enables only its
           "general" collector and serves nothing but mongodb_up -- it looks healthy
           and collects nothing. diagnosticdata carries the serverStatus/opcounters/
           WiredTiger bulk; replicasetstatus is added only for a replica set, since
           replSetGetStatus errors on a standalone mongod. Add the expensive
           per-collection collectors (collstats, dbstats, indexstats) or
           --collect-all through metrics.extraArgs. */}}
    - --collector.diagnosticdata
    {{- if eq $.Values.architecture "replicaset" }}
    - --collector.replicasetstatus
    {{- end }}
    {{- range $.Values.metrics.extraArgs }}
    - {{ . | quote }}
    {{- end }}
  {{- if $.Values.auth.enabled }}
  env:
    - name: MONGODB_USER
      value: {{ $.Values.auth.rootUsername | quote }}
    - name: MONGODB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "mongodb.secretName" $ }}
          key: {{ include "mongodb.secretPasswordKey" $ }}
  {{- end }}
  ports:
    - name: metrics
      containerPort: {{ $.Values.metrics.port }}
  resources:
    {{- toYaml $.Values.metrics.resources | nindent 4 }}
{{- end -}}
