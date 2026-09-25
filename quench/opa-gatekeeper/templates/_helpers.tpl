{{- define "gatekeeper.vwh" -}}{{ include "quench-common.fullname" . }}-validating{{- end -}}
{{- define "gatekeeper.mwh" -}}{{ include "quench-common.fullname" . }}-mutating{{- end -}}

{{/* shared by the webhook and audit containers */}}
{{- define "gatekeeper.env" -}}
- name: POD_NAMESPACE
  valueFrom: { fieldRef: { fieldPath: metadata.namespace } }
- name: POD_NAME
  valueFrom: { fieldRef: { fieldPath: metadata.name } }
- name: NAMESPACE
  valueFrom: { fieldRef: { fieldPath: metadata.namespace } }
- name: CONTAINER_NAME
  value: manager
{{- end -}}

{{- define "gatekeeper.commonArgs" -}}
- --logtostderr
- --cert-service-name={{ include "quench-common.fullname" . }}-webhook
- --validating-webhook-configuration-name={{ include "gatekeeper.vwh" . }}
- --mutating-webhook-configuration-name={{ include "gatekeeper.mwh" . }}
{{- range .Values.disabledBuiltins }}
- --disable-opa-builtin={{ . }}
{{- end }}
{{- end -}}
