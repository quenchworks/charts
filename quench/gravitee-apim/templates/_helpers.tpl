{{/* Selector labels for one component (gateway, api, console). */}}
{{- define "gravitee.selectorLabels" -}}
{{ include "quench-common.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "gravitee.image" -}}
{{- printf "%s@%s" .repository .digest -}}
{{- end -}}

{{/* The chart Secret: generated passwords, kept across upgrades via lookup. */}}
{{- define "gravitee.secretName" -}}
{{- include "quench-common.fullname" . -}}
{{- end -}}

{{/* Generated values, resolved once per render: an explicit value wins, then what the
     live Secret already holds, then a new random value. */}}
{{- define "gravitee.secrets" -}}
{{- $old := dict -}}
{{- with (lookup "v1" "Secret" .Release.Namespace (include "gravitee.secretName" .)) -}}{{- $old = .data -}}{{- end -}}
{{- $pick := dict -}}
{{- range $key, $spec := dict "admin-password" (list $.Values.admin.password 24) "node-password" (list $.Values.nodeApi.password 24) "jwt-secret" (list $.Values.jwtSecret 64) "encryption-secret" (list $.Values.encryptionSecret 32) -}}
{{- $v := index $spec 0 -}}
{{- if not $v -}}{{- with index $old $key -}}{{- $v = b64dec . -}}{{- end -}}{{- end -}}
{{- if not $v -}}{{- $v = randAlphaNum (index $spec 1) -}}{{- end -}}
{{- $_ := set $pick $key $v -}}
{{- end -}}
{{- toYaml $pick -}}
{{- end -}}

{{/* The MongoDB connection, as env entries for both Java components. The bundled
     MongoDB's root password is read from that chart's own Secret (it generates it, so
     this chart cannot know it at render time); the kubelet expands $(MONGODB_ROOT_PASSWORD).
     The generated password is alphanumeric; set mongodb.auth.rootPassword to one that
     needs no URL escaping. */}}
{{- define "gravitee.mongoEnv" -}}
{{- if .Values.mongodb.enabled -}}
- name: MONGODB_ROOT_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.mongodb.auth.existingSecret | default (printf "%s-mongodb" .Release.Name) }}
      key: {{ ternary (.Values.mongodb.auth.existingSecretPasswordKey | default "mongodb-root-password") "mongodb-root-password" (not (empty .Values.mongodb.auth.existingSecret)) }}
- name: GRAVITEE_MONGODB_URI
  value: {{ printf "mongodb://%s:$(MONGODB_ROOT_PASSWORD)@%s-mongodb:27017/%s?authSource=admin" .Values.mongodb.auth.rootUsername .Release.Name .Values.database | quote }}
{{- else -}}
- name: GRAVITEE_MONGODB_URI
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalMongodb.existingSecret | default (include "gravitee.secretName" .) }}
      key: {{ ternary .Values.externalMongodb.existingSecretUriKey "mongodb-uri" (not (empty .Values.externalMongodb.existingSecret)) }}
{{- end }}
- name: gravitee_repositories_management_type
  value: mongodb
- name: gravitee_repositories_management_mongodb_uri
  value: "$(GRAVITEE_MONGODB_URI)"
{{- end -}}

{{/* Environment shared by the gateway and the management API. */}}
{{- define "gravitee.commonEnv" -}}
- name: GRAVITEE_NODE_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "gravitee.secretName" . }}, key: node-password }
- name: gravitee_services_core_http_host
  value: "0.0.0.0"
- name: gravitee_services_core_http_authentication_users_admin
  value: "$(GRAVITEE_NODE_PASSWORD)"
- name: gravitee_api_properties_encryption_secret
  valueFrom:
    secretKeyRef: { name: {{ include "gravitee.secretName" . }}, key: encryption-secret }
{{- end -}}

{{/* Init container that holds a Java component until the bundled MongoDB answers. Without
     it a component that starts first fails "Error while getting installation", keeps
     running half-started, and only the startup probe restarts it minutes later. */}}
{{- define "gravitee.waitForMongo" -}}
{{- if .Values.mongodb.enabled }}
initContainers:
  - name: wait-for-mongodb
    image: {{ include "gravitee.image" .Values.mongodb.image | quote }}
    imagePullPolicy: {{ .Values.image.pullPolicy }}
    securityContext:
      {{- include "quench-common.containerSecurityContext" . | nindent 6 }}
    env:
      - { name: HOME, value: /tmp }
    command:
      - /bin/sh
      - -c
      - until mongosh --quiet --host {{ printf "%s-mongodb" .Release.Name }} --eval 'db.runCommand({ping:1}).ok' >/dev/null 2>&1; do echo waiting for mongodb; sleep 3; done
    resources:
      requests: { cpu: 10m, memory: 64Mi }
      limits: { cpu: 500m, memory: 256Mi }
    volumeMounts:
      - { name: tmp, mountPath: /tmp }
{{- end }}
{{- end -}}
