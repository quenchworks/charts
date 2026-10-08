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


{{/* GOMEMLIMIT at 80% of a memory limit given in Mi or Gi, as upstream sets it, so a large
     scan makes the Go GC work harder before the kernel kills the container. */}}
{{- define "ks.gomemlimit" -}}
{{- $m := toString . -}}
{{- $mib := 0 -}}
{{- if hasSuffix "Gi" $m }}{{ $mib = mul (trimSuffix "Gi" $m | int) 1024 }}
{{- else if hasSuffix "Mi" $m }}{{ $mib = trimSuffix "Mi" $m | int }}
{{- else }}{{ fail (printf "memory limit %q must be in Mi or Gi" $m) }}{{ end -}}
{{ div (mul $mib 8) 10 }}MiB
{{- end -}}
