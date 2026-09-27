{{- define "clamav.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* No LogFile lines: clamd and freshclam open LogFile with O_NOFOLLOW, so
     /dev/stdout fails. In the foreground they log to stdout without one. */}}
{{- define "clamav.clamdConf" -}}
Foreground yes
LogTime yes
LogClean no
DatabaseDirectory /var/lib/clamav
TemporaryDirectory /tmp
TCPSocket 3310
TCPAddr 0.0.0.0
MaxThreads {{ .Values.clamd.maxThreads }}
StreamMaxLength {{ .Values.clamd.streamMaxLength }}
SelfCheck {{ .Values.clamd.selfCheck }}
{{- with .Values.clamd.extraConfig }}
{{ . }}
{{- end }}
{{- end -}}

{{- define "clamav.freshclamConf" -}}
Foreground yes
LogTime yes
DatabaseDirectory /var/lib/clamav
DatabaseMirror {{ .Values.freshclam.mirror }}
{{- with .Values.freshclam.privateMirror }}
PrivateMirror {{ . }}
{{- end }}
Checks {{ .Values.freshclam.checks }}
{{- end -}}
