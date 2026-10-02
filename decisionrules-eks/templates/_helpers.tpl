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

{{/*
Server CPU/memory and autoscaling range for the selected rule solver:
the solverProfiles entry named by .Values.solver.
resources.server and autoscalingServer.minReplicas/maxReplicas override it when set.
*/}}
{{- define "decisionrules.solverProfile" -}}
{{- $solver := .Values.solver | default "aero" -}}
{{- $profiles := .Values.solverProfiles | default dict -}}
{{- if not (hasKey $profiles $solver) -}}
{{- fail (printf "solver %q has no entry in solverProfiles (available: %s)" $solver (keys $profiles | sortAlpha | join ", ")) -}}
{{- end -}}
{{- toYaml (index $profiles $solver) -}}
{{- end }}
