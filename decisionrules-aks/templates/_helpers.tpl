{{/*
Server CPU/memory and autoscaling range for the selected rule solver (.Values.solver).
  aero (default): Aero (V2) solver or mixed V1/V2 traffic, fewer and larger replicas.
  gaia: classic Gaia (V1) solver.
resources.server and autoscalingServer.minReplicas/maxReplicas override the profile when set.
*/}}
{{- define "decisionrules.solverProfile" -}}
{{- $solver := .Values.solver | default "aero" -}}
{{- if eq $solver "aero" -}}
resources:
  requests:
    cpu: 4000m
    memory: 8Gi
  limits:
    cpu: 4000m
    memory: 8Gi
minReplicas: 2
maxReplicas: 5
{{- else if eq $solver "gaia" -}}
resources:
  requests:
    cpu: 1000m
    memory: 1Gi
  limits:
    cpu: 2000m
    memory: 2Gi
minReplicas: 2
maxReplicas: 10
{{- else -}}
{{- fail (printf "solver must be \"aero\" or \"gaia\", got %q" $solver) -}}
{{- end -}}
{{- end }}
