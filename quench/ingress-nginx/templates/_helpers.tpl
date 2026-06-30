{{/*
Per-resource names, all derived from the release fullname so a single release is
self-consistent and two releases never collide.
*/}}

{{- define "ingress-nginx.controllerName" -}}
{{- printf "%s-controller" (include "quench-common.fullname" .) -}}
{{- end -}}

{{/* The controller ConfigMap nginx-ingress-controller reads global config from
     (passed via --configmap=$(POD_NAMESPACE)/<this>). */}}
{{- define "ingress-nginx.configMapName" -}}
{{- include "ingress-nginx.controllerName" . -}}
{{- end -}}

{{/* The admission webhook Service (apiserver dials :443 -> container webhookPort). */}}
{{- define "ingress-nginx.webhookServiceName" -}}
{{- printf "%s-admission" (include "ingress-nginx.controllerName" .) -}}
{{- end -}}

{{/* The ValidatingWebhookConfiguration name. */}}
{{- define "ingress-nginx.webhookConfigName" -}}
{{- printf "%s-admission" (include "ingress-nginx.controllerName" .) -}}
{{- end -}}

{{/* Secret the cert Jobs create and the controller mounts as its webhook serving
     cert/key (tls.crt / tls.key + ca.crt). */}}
{{- define "ingress-nginx.webhookCertSecretName" -}}
{{- printf "%s-admission" (include "ingress-nginx.controllerName" .) -}}
{{- end -}}

{{/* The leader-election ID. Defaults to the controller name when unset. */}}
{{- define "ingress-nginx.electionID" -}}
{{- default (include "ingress-nginx.controllerName" .) .Values.controller.electionID -}}
{{- end -}}

{{/* ServiceAccount name for the controller. */}}
{{- define "ingress-nginx.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "ingress-nginx.controllerName" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* Controller image, resolved strictly by digest (never a tag). */}}
{{- define "ingress-nginx.image" -}}
{{- include "quench-common.image" . -}}
{{- end -}}

{{/*
LuaJIT seed script for the seed-etc-nginx initContainer. Recursively copies the
image's /etc/nginx (lua scripts, dynamic modules, modsecurity rules, config
templates) into the emptyDir mounted at /seed-etc-nginx, which the controller
then mounts read-write at /etc/nginx. Uses only the image's own LuaJIT: the image
is shell-free and ships no cp, so the walk is done via FFI opendir/readdir and
buffered io.read/write (binary-safe), preserving symlinks. d_type 4 = DIR,
10 = LNK; everything else is copied as a regular file.
*/}}
{{- define "ingress-nginx.seedScript" -}}
local ffi=require("ffi") ffi.cdef[[typedef struct __dirstream DIR; struct dirent{long a;long b;unsigned short c;unsigned char d_type;char d_name[256];}; DIR*opendir(const char*); struct dirent*readdir(DIR*); int closedir(DIR*); int mkdir(const char*,unsigned int); int symlink(const char*,const char*); long readlink(const char*,char*,unsigned long);]] local C=ffi.C local function cf(s,d) local i=io.open(s,"rb") if not i then return end local o=io.open(d,"wb") if not o then i:close() return end while true do local c=i:read(1048576) if not c then break end o:write(c) end i:close() o:close() end local function walk(s,d) C.mkdir(d,tonumber("755",8)) local dh=C.opendir(s) if dh==nil then return end while true do local e=C.readdir(dh) if e==nil then break end local n=ffi.string(e.d_name) if n~="." and n~=".." then local sp=s.."/"..n local dp=d.."/"..n if e.d_type==4 then walk(sp,dp) elseif e.d_type==10 then local b=ffi.new("char[4096]") local k=C.readlink(sp,b,4096) if k>0 then C.symlink(ffi.string(b,k),dp) end else cf(sp,dp) end end end C.closedir(dh) end walk("/etc/nginx","/seed-etc-nginx") C.mkdir("/seed-ingress-controller/ssl",tonumber("755",8)) C.mkdir("/seed-ingress-controller/telemetry",tonumber("755",8)) C.mkdir("/seed-tmp/nginx",tonumber("755",8))
{{- end -}}

{{/*
Generate (or reuse) the admission webhook serving cert. Returns a dict with
keys "ca", "cert", "key" (all PEM). To keep the cert stable across helm upgrades,
it first looks up the existing Secret; only on a fresh install (or when missing)
does it mint a new self-signed CA + serving cert whose SANs cover the webhook
Service's in-cluster DNS names. Call once and reuse:
  {{- $tls := include "ingress-nginx.webhookCerts" . | fromYaml }}
*/}}
{{- define "ingress-nginx.webhookCerts" -}}
{{- $svc := include "ingress-nginx.webhookServiceName" . -}}
{{- $ns := .Release.Namespace -}}
{{- $altNames := list (printf "%s.%s.svc" $svc $ns) (printf "%s.%s.svc.cluster.local" $svc $ns) -}}
{{- $secretName := include "ingress-nginx.webhookCertSecretName" . -}}
{{- $existing := lookup "v1" "Secret" $ns $secretName -}}
{{- if and $existing $existing.data (index $existing.data "tls.crt") (index $existing.data "ca.crt") -}}
ca: {{ index $existing.data "ca.crt" }}
cert: {{ index $existing.data "tls.crt" }}
key: {{ index $existing.data "tls.key" }}
{{- else -}}
{{- $days := int .Values.controller.admissionWebhooks.certValidityDays -}}
{{- $ca := genCA (printf "%s-ca" $svc) $days -}}
{{- $cert := genSignedCert (index $altNames 0) nil $altNames $days $ca -}}
ca: {{ $ca.Cert | b64enc }}
cert: {{ $cert.Cert | b64enc }}
key: {{ $cert.Key | b64enc }}
{{- end -}}
{{- end -}}

{{/* Controller component labels: shared labels + the controller component label. */}}
{{- define "ingress-nginx.controllerLabels" -}}
{{ include "quench-common.labels" . }}
app.kubernetes.io/component: controller
{{- end -}}

{{- define "ingress-nginx.controllerSelectorLabels" -}}
{{ include "quench-common.selectorLabels" . }}
app.kubernetes.io/component: controller
{{- end -}}

{{/* Admission (cert Jobs) component labels. */}}
{{- define "ingress-nginx.admissionLabels" -}}
{{ include "quench-common.labels" . }}
app.kubernetes.io/component: admission-webhook
{{- end -}}
