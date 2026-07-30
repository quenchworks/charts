{{/*
  ---------------------------------------------------------------------------
  ONE ARGO CD PER NAMESPACE -- and why the config objects are NOT release-named.
  ---------------------------------------------------------------------------
  Argo CD looks its own configuration up by FIXED name (common/common.go):
  argocd-cm, argocd-rbac-cm, argocd-cmd-params-cm, argocd-secret,
  argocd-ssh-known-hosts-cm, argocd-tls-certs-cm, argocd-gpg-keys-cm,
  argocd-notifications-cm, argocd-notifications-secret. Those names are compiled
  in and not configurable, so this chart emits them verbatim. Consequence: exactly
  one Argo CD release per namespace. Workloads, Services, ServiceAccounts and RBAC
  ARE release-prefixed (quench-common.fullname), and every cross-component address
  is passed explicitly as a flag rather than relying on Argo CD's own
  argocd-repo-server:8081 / argocd-redis:6379 defaults, so two releases in two
  namespaces do not talk to each other.
*/}}

{{- define "argocd.server.fullname"     -}}{{ printf "%s-server"     (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "argocd.repoServer.fullname" -}}{{ printf "%s-repo-server" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "argocd.controller.fullname" -}}{{ printf "%s-application-controller" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "argocd.appset.fullname"     -}}{{ printf "%s-applicationset-controller" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "argocd.notifications.fullname" -}}{{ printf "%s-notifications-controller" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" }}{{- end -}}

{{/* ServiceAccounts. One per component, because their RBAC differs by an order of
     magnitude: the application controller holds cluster-admin-equivalent rights
     (it applies arbitrary manifests), the repo server holds none at all. */}}
{{- define "argocd.server.sa"     -}}{{ if .Values.serviceAccount.create }}{{ include "argocd.server.fullname" . }}{{ else }}{{ default "default" .Values.serviceAccount.server }}{{ end }}{{- end -}}
{{- define "argocd.repoServer.sa" -}}{{ if .Values.serviceAccount.create }}{{ include "argocd.repoServer.fullname" . }}{{ else }}{{ default "default" .Values.serviceAccount.repoServer }}{{ end }}{{- end -}}
{{- define "argocd.controller.sa" -}}{{ if .Values.serviceAccount.create }}{{ include "argocd.controller.fullname" . }}{{ else }}{{ default "default" .Values.serviceAccount.controller }}{{ end }}{{- end -}}
{{- define "argocd.appset.sa"     -}}{{ if .Values.serviceAccount.create }}{{ include "argocd.appset.fullname" . }}{{ else }}{{ default "default" .Values.serviceAccount.applicationSet }}{{ end }}{{- end -}}
{{- define "argocd.notifications.sa" -}}{{ if .Values.serviceAccount.create }}{{ include "argocd.notifications.fullname" . }}{{ else }}{{ default "default" .Values.serviceAccount.notifications }}{{ end }}{{- end -}}

{{/* Cluster-scoped RBAC names are namespace-suffixed: ClusterRoles are global, and
     Argo CD is routinely installed in more than one namespace of the same cluster. */}}
{{- define "argocd.clusterName" -}}
{{- printf "%s-%s" (include "quench-common.fullname" .) .Release.Namespace | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* ---------------------------------------------------------------------------
     REDIS. Argo CD is not usable without it: the application controller writes
     every resource tree and every app state into it and the API server reads them
     back, so it is a hard runtime dependency, not a cache you can skip.
     We do NOT vendor a second Redis into this chart -- the quench/redis chart is
     pulled in as a subchart (redis.enabled, default true) so it is the same
     hardened, digest-pinned, 0-CVE image and the same HA story as everywhere else
     in the catalog. externalRedis.host takes precedence for a BYO instance.
   --------------------------------------------------------------------------- */}}
{{- define "argocd.redis.host" -}}
{{- if .Values.externalRedis.host -}}
{{- .Values.externalRedis.host -}}
{{- else if .Values.redis.enabled -}}
{{- printf "%s-redis" .Release.Name -}}
{{- else -}}
{{- required "Argo CD requires Redis: set redis.enabled=true (bundled quench/redis) or externalRedis.host." .Values.externalRedis.host -}}
{{- end -}}
{{- end -}}

{{- define "argocd.redis.port" -}}
{{- if and (not .Values.externalRedis.host) .Values.redis.enabled -}}6379{{- else -}}{{ .Values.externalRedis.port }}{{- end -}}
{{- end -}}

{{- define "argocd.redis.addr" -}}
{{- printf "%s:%s" (include "argocd.redis.host" .) (include "argocd.redis.port" . | toString) -}}
{{- end -}}

{{- define "argocd.redis.db" -}}
{{- if and (not .Values.externalRedis.host) .Values.redis.enabled -}}0{{- else -}}{{ .Values.externalRedis.db }}{{- end -}}
{{- end -}}

{{/* Does Redis need a password at all? The bundled subchart turns auth on by
     default, so the answer is normally yes. */}}
{{- define "argocd.redis.hasPassword" -}}
{{- if .Values.externalRedis.host -}}
{{- if or .Values.externalRedis.password .Values.externalRedis.existingSecret -}}true{{- end -}}
{{- else if and .Values.redis.enabled ((.Values.redis.auth | default dict).enabled | default true) -}}true
{{- end -}}
{{- end -}}

{{- define "argocd.redis.secretName" -}}
{{- if .Values.externalRedis.host -}}
{{- if .Values.externalRedis.existingSecret -}}{{ .Values.externalRedis.existingSecret }}{{- else -}}{{ printf "%s-external-redis" (include "quench-common.fullname" .) }}{{- end -}}
{{- else -}}
{{- printf "%s-redis" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "argocd.redis.secretKey" -}}
{{- if and .Values.externalRedis.host .Values.externalRedis.existingSecret -}}
{{- .Values.externalRedis.existingSecretPasswordKey -}}
{{- else -}}redis-password{{- end -}}
{{- end -}}

{{/* REDIS_PASSWORD env, shared by the server, the repo server, the application
     controller and the notifications controller. Emits nothing when Redis has no
     password, so the components fall back to an unauthenticated connection. */}}
{{- define "argocd.redis.env" -}}
- name: REDIS_SERVER
  value: {{ include "argocd.redis.addr" . | quote }}
- name: REDISDB
  value: {{ include "argocd.redis.db" . | quote }}
{{- if include "argocd.redis.hasPassword" . }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "argocd.redis.secretName" . }}
      key: {{ include "argocd.redis.secretKey" . }}
{{- end }}
{{- end -}}

{{/* gRPC address of the repo server, passed explicitly instead of leaning on
     Argo CD's compiled-in argocd-repo-server:8081 default. */}}
{{- define "argocd.repoServer.addr" -}}
{{- printf "%s:%d" (include "argocd.repoServer.fullname" .) (int .Values.repoServer.service.port) -}}
{{- end -}}

{{/* Volumes every component that touches git or TLS shares: the three
     operator-supplied ConfigMaps (fixed names -- see the header) plus writable
     scratch, because the rootfs is read-only. */}}
{{- define "argocd.configVolumes" -}}
- name: ssh-known-hosts
  configMap:
    name: argocd-ssh-known-hosts-cm
    optional: true
- name: tls-certs
  configMap:
    name: argocd-tls-certs-cm
    optional: true
- name: gpg-keys
  configMap:
    name: argocd-gpg-keys-cm
    optional: true
- name: gpg-keyring
  emptyDir: {}
- name: tmp
  emptyDir: {}
{{- end -}}

{{- define "argocd.configVolumeMounts" -}}
- name: ssh-known-hosts
  mountPath: /app/config/ssh
- name: tls-certs
  mountPath: /app/config/tls
- name: gpg-keys
  mountPath: /app/config/gpg/source
- name: gpg-keyring
  mountPath: /app/config/gpg/keys
- name: tmp
  mountPath: /tmp
{{- end -}}
