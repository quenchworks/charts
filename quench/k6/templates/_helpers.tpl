{{- define "k6.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "quench-common.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "k6.configMapName" -}}
{{- .Values.existingConfigMap | default (printf "%s-script" (include "quench-common.fullname" .)) -}}
{{- end -}}

{{/* Full argv: base args plus the flags modelled in values. */}}
{{- define "k6.args" -}}
{{- $a := .Values.args | default list -}}
{{- with .Values.vus }}{{ $a = concat $a (list "--vus" (toString .)) }}{{ end -}}
{{- with .Values.duration }}{{ $a = concat $a (list "--duration" .) }}{{ end -}}
{{- if .Values.api.enabled }}{{ $a = concat $a (list "--address" (printf "0.0.0.0:%v" .Values.api.port)) }}{{ end -}}
{{- with .Values.extraArgs }}{{ $a = concat $a . }}{{ end -}}
{{- toYaml $a -}}
{{- end -}}

{{/*
The pod spec, shared by the Job and the CronJob so the two modes cannot drift. restartPolicy
is Never, not OnFailure: a failed load test is a RESULT to look at, not a transient error to
retry -- retrying would also re-send load.
*/}}
{{- define "k6.podSpec" -}}
restartPolicy: Never
serviceAccountName: {{ include "k6.serviceAccountName" . }}
{{- include "quench-common.imagePullSecrets" . | nindent 0 }}
securityContext:
  {{- include "quench-common.podSecurityContext" . | nindent 2 }}
{{- include "quench-common.podSpecFields" . | nindent 0 }}
{{- include "quench-common.initContainers" . | nindent 0 }}
containers:
  - name: k6
    image: {{ include "quench-common.image" . }}
    imagePullPolicy: {{ .Values.image.pullPolicy }}
    securityContext:
      {{- include "quench-common.containerSecurityContext" . | nindent 6 }}
    args:
      {{- include "k6.args" . | nindent 6 }}
    env:
      {{- include "quench-common.extraEnvVars" . | nindent 6 }}
    {{- include "quench-common.envFrom" . | nindent 4 }}
    {{- if .Values.api.enabled }}
    ports:
      - name: api
        containerPort: {{ .Values.api.port }}
    {{- end }}
    resources:
      {{- toYaml .Values.resources | nindent 6 }}
    volumeMounts:
      - name: scripts
        mountPath: /scripts
        readOnly: true
      {{- include "quench-common.extraVolumeMounts" . | nindent 6 }}
  {{- include "quench-common.sidecars" . | nindent 2 }}
volumes:
  - name: scripts
    configMap:
      name: {{ include "k6.configMapName" . }}
  {{- include "quench-common.extraVolumes" . | nindent 2 }}
{{- end -}}
