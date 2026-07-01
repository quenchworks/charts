{{- define "floci.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the PVC used for persistent storage. */}}
{{- define "floci.pvcName" -}}
{{- if .Values.persistence.existingClaim -}}{{ .Values.persistence.existingClaim }}{{- else -}}{{ printf "%s-data" (include "quench-common.fullname" .) }}{{- end -}}
{{- end -}}

{{/* True when a writable data volume must be mounted (persistence on). */}}
{{- define "floci.persistenceEnabled" -}}
{{- if .Values.persistence.enabled -}}true{{- end -}}
{{- end -}}

{{/*
True (emits "true") when the chart is running in the opt-in, deliberately
NON-HARDENED "full" mode. Every mode branch in the templates keys off this, so the
default "hardened" path stays byte-for-byte identical to before full mode existed.
*/}}
{{- define "floci.fullMode" -}}
{{- if eq .Values.floci.mode "full" -}}true{{- end -}}
{{- end -}}

{{/*
Risk gate. Full mode runs the pod as ROOT and bind-mounts the host Docker socket
(/var/run/docker.sock) -- a node-root / container-escape surface. It must be
explicitly acknowledged with floci.full.acknowledgeRisk=true, or the chart refuses
to render. Included from both the Deployment and NOTES so it ALWAYS evaluates.
*/}}
{{- define "floci.riskGate" -}}
{{- if include "floci.fullMode" . -}}
{{- if ne (.Values.floci.full.acknowledgeRisk | toString) "true" -}}
{{- fail "\n\nfloci.mode=full is REFUSED without acknowledgement.\n\nFull mode is NOT hardened: it runs the floci-full image as ROOT (runAsNonRoot=false, readOnlyRootFilesystem=false) and bind-mounts the host Docker socket /var/run/docker.sock into the pod so Floci can drive the 10 Docker-backed services (Lambda, RDS, ElastiCache, MSK, ECS, EKS, OpenSearch, ECR, DocumentDB, Neptune). A mounted host Docker socket is a node-root / container-escape surface: any workload in this pod can control the node's Docker daemon.\n\nDo NOT use full mode on shared or multi-tenant clusters. If you understand and accept this, set:\n\n  floci.full.acknowledgeRisk: true\n" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Resolve the container image by digest, branching on mode. Hardened mode delegates to
quench-common.image (.Values.image). Full mode pins the separate floci-full image by
digest via .Values.floci.full.image.{repository,digest}.
*/}}
{{- define "floci.image" -}}
{{- if include "floci.fullMode" . -}}
{{- $repo := required "floci.full.image.repository is required for full mode" .Values.floci.full.image.repository -}}
{{- $digest := required "floci.full.image.digest is required for full mode (pinned by digest, never a tag)" .Values.floci.full.image.digest -}}
{{- printf "%s@%s" $repo $digest -}}
{{- else -}}
{{- include "quench-common.image" . -}}
{{- end -}}
{{- end -}}

{{/* image pullPolicy, per mode. */}}
{{- define "floci.imagePullPolicy" -}}
{{- if include "floci.fullMode" . -}}{{ .Values.floci.full.image.pullPolicy | default "IfNotPresent" }}{{- else -}}{{ .Values.image.pullPolicy }}{{- end -}}
{{- end -}}

{{/*
Pod-level security context. Hardened mode uses quench-common's locked-down defaults.
Full mode runs as ROOT (runAsNonRoot=false, runAsUser=0) so the Docker-backed
services can talk to the mounted host socket; callers may still extend via
.Values.podSecurityContext (override keys win).
*/}}
{{- define "floci.podSecurityContext" -}}
{{- if include "floci.fullMode" . -}}
{{- $default := dict "runAsNonRoot" false "runAsUser" 0 "runAsGroup" 0 "fsGroup" 0 "seccompProfile" (dict "type" "RuntimeDefault") -}}
{{- $override := deepCopy (.Values.podSecurityContext | default dict) -}}
{{- toYaml (mergeOverwrite $default $override) -}}
{{- else -}}
{{- include "quench-common.podSecurityContext" . -}}
{{- end -}}
{{- end -}}

{{/*
Container-level security context. Hardened mode uses quench-common's locked-down
defaults (readOnlyRootFilesystem=true, drop ALL, etc). Full mode disables the
read-only root filesystem and runs as root; callers may extend via
.Values.containerSecurityContext (override keys win).
*/}}
{{- define "floci.containerSecurityContext" -}}
{{- if include "floci.fullMode" . -}}
{{- $default := dict "runAsNonRoot" false "runAsUser" 0 "allowPrivilegeEscalation" true "readOnlyRootFilesystem" false "privileged" false -}}
{{- $override := deepCopy (.Values.containerSecurityContext | default dict) -}}
{{- toYaml (mergeOverwrite $default $override) -}}
{{- else -}}
{{- include "quench-common.containerSecurityContext" . -}}
{{- end -}}
{{- end -}}

{{/*
Host Docker socket volume (full mode only). A hostPath to /var/run/docker.sock,
which is what enables Floci's 10 Docker-backed services. Emits nothing in hardened
mode. Include at pod spec volumes level.
*/}}
{{- define "floci.dockerSocketVolume" -}}
{{- if include "floci.fullMode" . -}}
- name: docker-socket
  hostPath:
    path: /var/run/docker.sock
    type: Socket
{{- end -}}
{{- end -}}

{{/*
Host Docker socket volume mount (full mode only), mounted at /var/run/docker.sock.
Include at container volumeMounts level.
*/}}
{{- define "floci.dockerSocketVolumeMount" -}}
{{- if include "floci.fullMode" . -}}
- name: docker-socket
  mountPath: /var/run/docker.sock
{{- end -}}
{{- end -}}
