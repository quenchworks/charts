{{/* derper's ports: TLS on 443 (it serves TLS only there) and STUN on 3478/udp. */}}
{{- define "derper.ports" -}}
{{- $p := list (dict "name" "https" "port" 443 "servicePort" (int .Values.service.port) "protocol" "TCP") -}}
{{- if .Values.stun.enabled -}}
{{- $p = append $p (dict "name" "stun" "port" 3478 "servicePort" (int .Values.service.stunPort) "protocol" "UDP") -}}
{{- end -}}
{{- toJson $p -}}
{{- end -}}

{{/* derper's command line. */}}
{{- define "derper.args" -}}
- -a=:443
- -http-port=-1
- -stun={{ .Values.stun.enabled }}
- -stun-port=3478
- -certmode=manual
- -certdir=/certs
- -hostname={{ required "hostname is required: the relay's DNS name, which its certificate and clients use" .Values.hostname }}
- -c=/var/lib/derper/derper.json
{{- if .Values.verifyClients }}
- -verify-clients
{{- end }}
{{- range .Values.extraArgs }}
- {{ . | quote }}
{{- end }}
{{- end -}}
