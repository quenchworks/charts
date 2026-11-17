{{- define "warpgate.secretName" -}}
{{- .Values.admin.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Listeners: name, container port, Service port, enabled. */}}
{{- define "warpgate.ports" -}}
{{- $l := list (dict "name" "https" "port" 8888 "servicePort" (int .Values.service.httpsPort) "on" true) -}}
{{- if .Values.ssh.enabled }}{{ $l = append $l (dict "name" "ssh" "port" 2222 "servicePort" (int .Values.ssh.port) "on" true) }}{{ end -}}
{{- if .Values.mysql.enabled }}{{ $l = append $l (dict "name" "mysql" "port" 33306 "servicePort" (int .Values.mysql.port) "on" true) }}{{ end -}}
{{- if .Values.postgres.enabled }}{{ $l = append $l (dict "name" "postgres" "port" 55432 "servicePort" (int .Values.postgres.port) "on" true) }}{{ end -}}
{{- toJson $l -}}
{{- end -}}
