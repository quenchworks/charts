{{- define "traefik.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/*
Assemble the Traefik static-configuration CLI args. Traefik is configured entirely
via flags here (no mounted traefik.yml), so the static config travels with the pod
spec and changes roll the Deployment. Container ports are unprivileged (uid 1001);
the Service maps 80/443 onto them.
*/}}
{{- define "traefik.args" -}}
- "--global.checknewversion=false"
- "--global.sendanonymoususage=false"
- "--log.level={{ .Values.logLevel }}"
- "--ping=true"
- "--entrypoints.web.address=:{{ .Values.ports.web }}"
- "--entrypoints.websecure.address=:{{ .Values.ports.websecure }}"
- "--entrypoints.traefik.address=:{{ .Values.ports.traefik }}"
{{- if .Values.dashboard.enabled }}
- "--api.dashboard=true"
{{- if .Values.dashboard.insecure }}
- "--api.insecure=true"
{{- end }}
{{- end }}
{{- if .Values.providers.kubernetesIngress }}
- "--providers.kubernetesingress=true"
{{- end }}
{{- if .Values.providers.kubernetesCRD }}
- "--providers.kubernetescrd=true"
{{- end }}
{{- if .Values.acme.enabled }}
- "--certificatesresolvers.le.acme.storage={{ .Values.acme.storagePath }}"
- "--certificatesresolvers.le.acme.tlschallenge=true"
{{- end }}
{{- with .Values.extraArgs }}
{{- toYaml . }}
{{- end }}
{{- end -}}
