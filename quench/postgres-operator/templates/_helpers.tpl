{{/* Every port the operator listens on, as {name, port, servicePort, protocol}: container, Service and NetworkPolicy. */}}
{{- define "postgres-operator.ports" -}}
{{- toJson (list (dict "name" "http" "port" (int .Values.config.api_port) "servicePort" (int .Values.service.port) "protocol" "TCP")) -}}
{{- end -}}

{{/* The operator ConfigMap: values.config over nothing, with the Spilo image and its ids forced from spilo. */}}
{{- define "postgres-operator.config" -}}
{{- $s := .Values.spilo.image -}}
{{- $img := printf "%s@%s" (required "spilo.image.repository is required" $s.repository) (required "spilo.image.digest is required (pinned by digest, never a tag)" $s.digest) -}}
{{- with .Values.image.registry }}{{ $img = printf "%s/%s" (trimSuffix "/" .) $img }}{{ end -}}
{{- $c := merge (dict "docker_image" $img "spilo_runasuser" "101" "spilo_runasgroup" "103" "spilo_fsgroup" "103") (deepCopy .Values.config) -}}
{{- range $k := keys $c | sortAlpha }}
{{ $k }}: {{ index $c $k | toString | quote }}
{{- end }}
{{- end -}}
