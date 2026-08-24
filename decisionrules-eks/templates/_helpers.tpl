{{/*
Render one env entry for a sensitive variable.

When secrets.existingSecret is set, the variable is read from that Secret
(key name in the Secret must match the env var name) and the inline value
is ignored. Otherwise the inline value from values.yaml is used directly.

Usage:
  {{- include "decisionrules.secretEnv" (dict "root" $ "key" "MONGO_DB_URI" "value" .Values.env.server.MONGO_DB_URI) | nindent 8 }}
*/}}
{{- define "decisionrules.secretEnv" -}}
- name: {{ .key }}
{{- if .root.Values.secrets.existingSecret }}
  valueFrom:
    secretKeyRef:
      name: {{ .root.Values.secrets.existingSecret }}
      key: {{ .key }}
{{- else }}
  value: {{ .value | quote }}
{{- end }}
{{- end }}
