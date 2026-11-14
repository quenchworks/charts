{{- /* "cdi.image" (list . "cdi-controller"): repository@digest for one CDI component from .Values.images. */ -}}
{{- define "cdi.image" -}}
{{- $root := index . 0 -}}{{- $name := index . 1 -}}
{{- $i := index $root.Values.images $name | required (printf "images.%s is required" $name) -}}
{{- printf "%s@%s" $i.repository $i.digest -}}
{{- end -}}
