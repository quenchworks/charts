{{- define "varnish.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* Name of the ConfigMap holding default.vcl. */}}
{{- define "varnish.configMapName" -}}
{{- printf "%s-vcl" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* Which ConfigMap to mount: an external one wins, else the chart-rendered one. */}}
{{- define "varnish.mountedConfigMap" -}}
{{- if .Values.vcl.existingConfigMap -}}{{ .Values.vcl.existingConfigMap }}{{- else -}}{{ include "varnish.configMapName" . }}{{- end -}}
{{- end -}}

{{/*
The effective VCL: `vcl.raw` verbatim when set, otherwise one generated from
`backend` + `vcl.healthPath`.

Why the health endpoint is in the VCL and not just a probe path: Varnish answers it
from vcl_synth, so liveness/readiness measure VARNISH, not the origin. Probing a
normal URL instead would restart every Varnish pod whenever the backend went down --
exactly when a cache is most useful.

With no backend host, `backend default none;` keeps the VCL valid (a VCL with no
backend at all fails to compile) and every request is answered locally, so the chart
installs and reaches Ready with nothing behind it.
*/}}
{{- define "varnish.vcl" -}}
{{- if .Values.vcl.raw -}}
{{ .Values.vcl.raw }}
{{- else -}}
vcl 4.1;

{{ if .Values.backend.host -}}
backend default {
    .host = "{{ .Values.backend.host }}";
    .port = "{{ .Values.backend.port }}";
}
{{- else -}}
# No backend.host set: Varnish answers every request itself.
backend default none;
{{- end }}

sub vcl_recv {
    # Answered by Varnish itself, so the probes never depend on the origin.
    if (req.url == "{{ .Values.vcl.healthPath }}") {
        return (synth(200, "OK"));
    }
{{- if not .Values.backend.host }}
    return (synth(200, "OK"));
{{- end }}
}

sub vcl_synth {
    if (resp.status == 200) {
        set resp.http.Content-Type = "text/plain; charset=utf-8";
        set resp.body = "varnish OK";
        return (deliver);
    }
    # Anything else falls through to the builtin vcl_synth (error pages).
}
{{- end -}}
{{- end -}}
