{{- define "rekor-tiles.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ default (include "quench-common.fullname" .) .Values.serviceAccount.name }}{{- else -}}{{ default "default" .Values.serviceAccount.name }}{{- end -}}
{{- end -}}

{{- define "rekor-tiles.secretName" -}}
{{- default (printf "%s-signer" (include "quench-common.fullname" .)) .Values.signer.existingSecret -}}
{{- end -}}

{{/* The log origin: signed into every checkpoint, so it must never change. */}}
{{- define "rekor-tiles.hostname" -}}
{{- default (include "quench-common.fullname" .) .Values.hostname -}}
{{- end -}}
