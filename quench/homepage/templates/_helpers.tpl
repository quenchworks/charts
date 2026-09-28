{{- define "homepage.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{/* One ConfigMap key per Homepage config file. YAML values are rendered with
     toYaml; a string is taken as the file's literal content. */}}
{{- define "homepage.files" -}}
{{- $c := .Values.config -}}
{{- $f := dict -}}
{{- range $k, $name := dict "settings" "settings.yaml" "services" "services.yaml" "bookmarks" "bookmarks.yaml" "widgets" "widgets.yaml" "kubernetes" "kubernetes.yaml" "docker" "docker.yaml" }}
{{- $v := index $c $k -}}
{{- $_ := set $f $name (ternary $v (toYaml $v) (kindIs "string" $v)) -}}
{{- end -}}
{{- $_ := set $f "custom.css" (default "" $c.customCss) -}}
{{- $_ := set $f "custom.js" (default "" $c.customJs) -}}
{{- toYaml $f -}}
{{- end -}}
