{{- define "gatekeeper.pod" -}}
{{- $c := .component -}}
{{- with .root -}}
metadata:
  labels:
    {{- include "quench-common.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: {{ $c }}
    gatekeeper.sh/system: "yes"
spec:
  serviceAccountName: {{ include "quench-common.serviceAccountName" . }}
  {{- with .Values.priorityClassName }}
  priorityClassName: {{ . }}
  {{- end }}
  securityContext:
    {{- include "quench-common.podSecurityContext" . | nindent 4 }}
  {{- with .Values.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  containers:
    - name: manager
      image: {{ include "quench-common.image" . }}
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      args:
        {{- include "gatekeeper.commonArgs" . | nindent 8 }}
        {{- if eq $c "webhook" }}
        - --port=8443
        - --operation=webhook
        {{- if .Values.mutatingWebhook.enabled }}
        - --operation=mutation-webhook
        {{- end }}
        {{- range (prepend .Values.exemptNamespaces .Release.Namespace) }}
        - --exempt-namespace={{ . }}
        {{- end }}
        {{- else }}
        - --operation=audit
        - --operation=status
        - --operation=generate
        {{- if .Values.mutatingWebhook.enabled }}
        - --operation=mutation-status
        {{- end }}
        - --audit-interval={{ .Values.audit.interval }}
        # the webhook pods rotate the certificate; audit only reads it
        - --disable-cert-rotation
        {{- end }}
        {{- range .Values.extraArgs }}
        - {{ . | quote }}
        {{- end }}
      env:
        {{- include "gatekeeper.env" . | nindent 8 }}
      ports:
        {{- if eq $c "webhook" }}
        - { name: webhook-server, containerPort: 8443 }
        {{- end }}
        - { name: metrics, containerPort: 8888 }
        - { name: healthz, containerPort: 9090 }
      readinessProbe:
        httpGet: { path: /readyz, port: healthz }
        periodSeconds: 5
      livenessProbe:
        httpGet: { path: /healthz, port: healthz }
        periodSeconds: 10
      resources:
        {{- toYaml (ternary .Values.resources .Values.audit.resources (eq $c "webhook")) | nindent 8 }}
      securityContext:
        {{- include "quench-common.containerSecurityContext" . | nindent 8 }}
      volumeMounts:
        - { name: cert, mountPath: /certs, readOnly: true }
        - { name: tmp, mountPath: /tmp }
        {{- if eq $c "audit" }}
        # audit clears its API cache dir between runs but never creates it
        - { name: audit-cache, mountPath: /tmp/audit }
        {{- end }}
  {{- with .Values.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  volumes:
    - name: cert
      secret: { secretName: gatekeeper-webhook-server-cert, defaultMode: 0440 }
    - name: tmp
      emptyDir: {}
    {{- if eq $c "audit" }}
    - name: audit-cache
      emptyDir: {}
    {{- end }}
{{- end -}}
{{- end -}}
