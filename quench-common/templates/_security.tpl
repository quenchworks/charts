{{/* Hardened pod-level security context. Locked-down defaults. */}}
{{- define "quench-common.podSecurityContext" -}}
runAsNonRoot: true
runAsUser: 1001
runAsGroup: 1001
fsGroup: 1001
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{/* Hardened container-level security context. */}}
{{- define "quench-common.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
privileged: false
capabilities:
  drop:
    - ALL
{{- end -}}
