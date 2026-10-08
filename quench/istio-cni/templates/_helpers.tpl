{{/* Pods join the mesh by their own label, or by their namespace's unless they opt out. */}}
{{- define "istio-cni.enablementSelector" -}}
- podSelector:
    matchLabels:
      istio.io/dataplane-mode: ambient
- namespaceSelector:
    matchLabels:
      istio.io/dataplane-mode: ambient
  podSelector:
    matchExpressions:
      - key: istio.io/dataplane-mode
        operator: NotIn
        values: [none]
{{- end -}}
