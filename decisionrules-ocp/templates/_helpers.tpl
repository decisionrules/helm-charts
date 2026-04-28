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
out-of-band via kubectl, ExternalSecrets, Vault, Sealed Secrets, etc.
See the chart README for an ExternalSecret example.
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
API URL
*/}}
{{- define "decisionrules.apiUrl" -}}
{{- if .Values.server.apiUrl -}}
  {{ .Values.server.apiUrl }}
{{- else if .Values.server.route.host -}}
  https://{{ .Values.server.route.host }}
{{- else -}}
  https://api.example.com
{{- end -}}
{{- end }}

{{/*
Client URL
*/}}
{{- define "decisionrules.clientUrl" -}}
{{- if .Values.server.clientUrl -}}
  {{ .Values.server.clientUrl }}
{{- else if .Values.client.route.host -}}
  https://{{ .Values.client.route.host }}/#
{{- else -}}
  https://example.com/#
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
