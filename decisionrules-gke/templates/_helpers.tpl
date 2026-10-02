{{/*
Common labels
*/}}
{{- define "decisionrules.labels" -}}
app.kubernetes.io/part-of: decisionrules
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{- define "decisionrules.client.labels" -}}
{{ include "decisionrules.labels" . }}
app.kubernetes.io/component: client
{{- end }}

{{- define "decisionrules.server.labels" -}}
{{ include "decisionrules.labels" . }}
app.kubernetes.io/component: server
{{- end }}

{{- define "decisionrules.aiEngine.labels" -}}
{{ include "decisionrules.labels" . }}
app.kubernetes.io/component: ai-engine
{{- end }}

{{- define "decisionrules.businessIntelligence.labels" -}}
{{ include "decisionrules.labels" . }}
app.kubernetes.io/component: business-intelligence
{{- end }}

{{/*
Name of the Secret holding MONGO_DB_URI, BI_MONGO_DB_URI, REDIS_URL, LICENSE_KEY.
The Secret must exist in the release namespace before install. It can be created
out-of-band via kubectl, ExternalSecrets (e.g. from Google Secret Manager), Vault,
Sealed Secrets, etc. See the chart README for an ExternalSecret example.
*/}}
{{- define "decisionrules.connectionSecretName" -}}
{{- required "server.existingSecret is required. Create a Secret in the release namespace with keys MONGO_DB_URI, BI_MONGO_DB_URI, REDIS_URL, and LICENSE_KEY, then set server.existingSecret to its name. See the chart README for an ExternalSecret example." .Values.server.existingSecret -}}
{{- end }}

{{/*
Name of the Secret holding AIA_SECRET. Only resolved when aiEngine.enabled=true,
since the AI engine deployment template is gated on that flag.
*/}}
{{- define "decisionrules.aiEngineSecretName" -}}
{{- required "aiEngine.existingSecret is required when aiEngine.enabled=true. Create a Secret in the release namespace with key AIA_SECRET and set aiEngine.existingSecret to its name." .Values.aiEngine.existingSecret -}}
{{- end }}

{{/*
Ingress hostnames
*/}}
{{- define "decisionrules.clientHost" -}}
{{- required "ingress.hosts.client is required when ingress.enabled=true (e.g. app.example.com)." .Values.ingress.hosts.client -}}
{{- end }}

{{- define "decisionrules.serverHost" -}}
{{- required "ingress.hosts.server is required when ingress.enabled=true (e.g. api.example.com)." .Values.ingress.hosts.server -}}
{{- end }}

{{/*
Ingress resource names
*/}}
{{- define "decisionrules.managedCertificateName" -}}
{{ .Release.Name }}-managed-cert
{{- end }}

{{- define "decisionrules.frontendConfigName" -}}
{{ .Release.Name }}-frontend-config
{{- end }}

{{- define "decisionrules.client.backendConfigName" -}}
{{ .Release.Name }}-client-backend-config
{{- end }}

{{- define "decisionrules.server.backendConfigName" -}}
{{ .Release.Name }}-server-backend-config
{{- end }}

{{/*
Whether a Google-managed certificate is rendered. Returns "true" or "".
Google-managed certificates only work with the external load balancer.
*/}}
{{- define "decisionrules.managedCertificateEnabled" -}}
{{- if and .Values.ingress.enabled .Values.ingress.tls.managedCertificate.enabled -}}
{{- if ne .Values.ingress.className "gce" -}}
{{- fail "ingress.tls.managedCertificate is only supported with ingress.className=gce. For gce-internal, set ingress.tls.managedCertificate.enabled=false and use ingress.tls.secretName or ingress.tls.preSharedCerts." -}}
{{- end -}}
true
{{- end -}}
{{- end }}

{{/*
Whether the Ingress serves HTTPS. Returns "true" or "".
*/}}
{{- define "decisionrules.tlsEnabled" -}}
{{- if and .Values.ingress.enabled (or (include "decisionrules.managedCertificateEnabled" .) .Values.ingress.tls.secretName .Values.ingress.tls.preSharedCerts) -}}
true
{{- end -}}
{{- end }}

{{/*
Whether a FrontendConfig is rendered. Returns "true" or "".
FrontendConfig is only supported with the external load balancer. The HTTPS
redirect is only applied when a certificate is configured.
*/}}
{{- define "decisionrules.frontendConfigEnabled" -}}
{{- if and .Values.ingress.enabled (eq .Values.ingress.className "gce") -}}
{{- if or (and .Values.ingress.tls.redirectToHttps (include "decisionrules.tlsEnabled" .)) .Values.ingress.tls.sslPolicy -}}
true
{{- end -}}
{{- end -}}
{{- end }}

{{/*
URL scheme of the public endpoints
*/}}
{{- define "decisionrules.scheme" -}}
{{- if include "decisionrules.tlsEnabled" . -}}
https
{{- else -}}
http
{{- end -}}
{{- end }}

{{/*
API URL
*/}}
{{- define "decisionrules.apiUrl" -}}
{{- if .Values.server.apiUrl -}}
  {{ .Values.server.apiUrl }}
{{- else if and .Values.ingress.enabled .Values.server.enabled -}}
  {{ include "decisionrules.scheme" . }}://{{ include "decisionrules.serverHost" . }}
{{- else -}}
  {{- fail "server.apiUrl is required when ingress.enabled=false or server.enabled=false (the public URL of the server, e.g. https://api.example.com)." -}}
{{- end -}}
{{- end }}

{{/*
Client URL
*/}}
{{- define "decisionrules.clientUrl" -}}
{{- if .Values.server.clientUrl -}}
  {{ .Values.server.clientUrl }}
{{- else if and .Values.ingress.enabled .Values.client.enabled -}}
  {{ include "decisionrules.scheme" . }}://{{ include "decisionrules.clientHost" . }}/#
{{- else -}}
  {{- fail "server.clientUrl is required when ingress.enabled=false or client.enabled=false (the public URL of the client ending with /#, e.g. https://app.example.com/#)." -}}
{{- end -}}
{{- end }}

{{/*
AI engine URL
*/}}
{{- define "decisionrules.aiEngineUrl" -}}
{{- if .Values.server.aiEngineUrl -}}
  {{ .Values.server.aiEngineUrl }}
{{- else -}}
  http://{{ .Release.Name }}-ai-engine-service.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.aiEngine.port }}
{{- end -}}
{{- end }}

{{/*
Proxy CA bundle path
*/}}
{{- define "decisionrules.proxyCaBundlePath" -}}
{{ .Values.proxy.caBundle.mountPath }}/{{ .Values.proxy.caBundle.fileName }}
{{- end }}

{{/*
Server CPU/memory and autoscaling range for the selected rule solver:
the server.solverProfiles entry named by .Values.server.solver.
server.resources and server.autoscaling.minReplicas/maxReplicas override it when set.
*/}}
{{- define "decisionrules.solverProfile" -}}
{{- $solver := .Values.server.solver | default "aero" -}}
{{- $profiles := .Values.server.solverProfiles | default dict -}}
{{- if not (hasKey $profiles $solver) -}}
{{- fail (printf "server.solver %q has no entry in server.solverProfiles (available: %s)" $solver (keys $profiles | sortAlpha | join ", ")) -}}
{{- end -}}
{{- toYaml (index $profiles $solver) -}}
{{- end }}
