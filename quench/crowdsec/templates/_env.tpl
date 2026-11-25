{{/* crowdsec.env: <dict ctx, part> renders the container env shared by the LAPI and the agent. */}}
{{- define "crowdsec.env" -}}
{{- $ctx := .ctx -}}
- name: AGENT_USERNAME
  valueFrom: { secretKeyRef: { name: {{ printf "%s-agent" (include "quench-common.fullname" $ctx) }}, key: username } }
- name: AGENT_PASSWORD
  valueFrom: { secretKeyRef: { name: {{ printf "%s-agent" (include "quench-common.fullname" $ctx) }}, key: password } }
{{- range $k, $v := .part.env }}
- { name: {{ $k }}, value: {{ $v | quote }} }
{{- end }}
{{ include "quench-common.extraEnvVars" $ctx }}
{{- end -}}
