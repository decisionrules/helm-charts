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
