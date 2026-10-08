{{/* Pod-level fields shared by every Kubescape component. Our images run as uid 1001
     (upstream's run as 65532); HOME is set to /home/nonroot because the components
     write caches and results under it, and that path is an emptyDir here. */}}
{{- define "ks.podSpec" -}}
automountServiceAccountToken: true
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  runAsGroup: 1001
  fsGroup: 1001
  seccompProfile: { type: RuntimeDefault }
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "ks.containerSecurity" -}}
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  capabilities: { drop: [ALL] }
{{- end -}}

{{- define "ks.env" -}}
- { name: HOME, value: /home/nonroot }
- { name: KS_LOGGER_LEVEL, value: {{ .Values.logger.level | quote }} }
- { name: KS_LOGGER_NAME, value: zap }
{{- end -}}

{{- define "ks.clusterDataMount" -}}
- { name: ks-cloud-config, mountPath: /etc/config/clusterData.json, subPath: clusterData, readOnly: true }
{{- end -}}

{{- define "ks.clusterDataVolume" -}}
- name: ks-cloud-config
  configMap: { name: ks-cloud-config }
{{- end -}}
