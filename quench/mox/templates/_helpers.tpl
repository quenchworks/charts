{{/* Service ports and the unprivileged container ports they map to. Implicit-TLS ports only with TLS. */}}
{{- define "mox.ports" -}}
{{- $tls := eq (include "quench-common.tls.enabled" .) "true" -}}
{{- $p := list (dict "name" "smtp" "port" 2525 "servicePort" (int .Values.service.ports.smtp) "protocol" "TCP")
               (dict "name" "submission" "port" 2587 "servicePort" (int .Values.service.ports.submission) "protocol" "TCP")
               (dict "name" "imap" "port" 1143 "servicePort" (int .Values.service.ports.imap) "protocol" "TCP")
               (dict "name" "http" "port" 8080 "servicePort" (int .Values.service.ports.http) "protocol" "TCP") -}}
{{- if $tls }}
{{- $p = append $p (dict "name" "submissions" "port" 4465 "servicePort" (int .Values.service.ports.submissions) "protocol" "TCP") }}
{{- $p = append $p (dict "name" "imaps" "port" 9993 "servicePort" (int .Values.service.ports.imaps) "protocol" "TCP") }}
{{- end }}
{{- toJson $p -}}
{{- end -}}

{{- define "mox.secretName" -}}
{{- .Values.secret.existingSecret | default (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* mox.conf (sconf: tab-indented). Rewritten on every start: it is chart-managed. */}}
{{- define "mox.static" -}}
{{- $tls := eq (include "quench-common.tls.enabled" .) "true" -}}
DataDir: ../data
LogLevel: {{ .Values.logLevel }}
User: mox
Hostname: {{ required "hostname is required" .Values.hostname }}
AdminPasswordFile: adminpasswd
Postmaster:
	Account: {{ (index .Values.accounts 0).name }}
	Mailbox: Postmaster
Listeners:
	public:
		IPs:
			- 0.0.0.0
		Hostname: {{ .Values.hostname }}
{{- if $tls }}
		TLS:
			KeyCerts:
				-
					CertFile: /tls/tls.crt
					KeyFile: /tls/tls.key
{{- end }}
		SMTP:
			Enabled: true
			Port: 2525
{{- if not $tls }}
			NoSTARTTLS: true
{{- end }}
		Submission:
			Enabled: true
			Port: 2587
{{- if not $tls }}
			NoRequireSTARTTLS: true
{{- end }}
{{- if $tls }}
		Submissions:
			Enabled: true
			Port: 4465
{{- end }}
		IMAP:
			Enabled: true
			Port: 1143
{{- if not $tls }}
			NoRequireSTARTTLS: true
{{- end }}
{{- if $tls }}
		IMAPS:
			Enabled: true
			Port: 9993
{{- end }}
		AccountHTTP:
			Enabled: true
			Port: 8080
			Forwarded: {{ .Values.forwardedHeaders }}
		AdminHTTP:
			Enabled: true
			Port: 8080
			Forwarded: {{ .Values.forwardedHeaders }}
		WebmailHTTP:
			Enabled: true
			Port: 8080
			Forwarded: {{ .Values.forwardedHeaders }}
		WebAPIHTTP:
			Enabled: true
			Port: 8080
			Forwarded: {{ .Values.forwardedHeaders }}
		MetricsHTTP:
			Enabled: true
			Port: 8010
{{- end -}}

{{/* domains.conf: written on the first start only; afterwards the admin web UI owns it. */}}
{{- define "mox.domains" -}}
Domains:
	{{ required "domain is required" .Values.domain }}: nil
Accounts:
{{- range .Values.accounts }}
	{{ .name }}:
		Domain: {{ $.Values.domain }}
		Destinations:
{{- range .addresses }}
			{{ . }}: nil
{{- end }}
{{- end }}
{{- end -}}
