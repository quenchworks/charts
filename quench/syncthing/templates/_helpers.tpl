{{/* Every port Syncthing listens on, as {name, port, servicePort, protocol}: container, Service and
     NetworkPolicy. Sync runs on 22000 over TCP (TLS) and UDP (QUIC). */}}
{{- define "syncthing.ports" -}}
{{- toJson (list
  (dict "name" "gui" "port" 8384 "servicePort" (int .Values.service.guiPort) "protocol" "TCP")
  (dict "name" "sync-tcp" "port" 22000 "servicePort" (int .Values.service.syncPort) "protocol" "TCP")
  (dict "name" "sync-quic" "port" 22000 "servicePort" (int .Values.service.syncPort) "protocol" "UDP")) -}}
{{- end -}}

{{- define "syncthing.pvcName" -}}
{{- .Values.persistence.existingClaim | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "syncthing.secretName" -}}
{{- .Values.gui.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{- define "syncthing.scheme" -}}
{{- if include "quench-common.tls.enabled" . }}https{{ else }}http{{ end -}}
{{- end -}}
