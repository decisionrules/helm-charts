# DecisionRules Helm Chart Deployment Guide

This chart deploys the DecisionRules application components for OpenShift:

- Client
- Server
- Business Intelligence (optional)
- AI Engine (optional)

MongoDB and Redis are not deployed, managed, or configured by this chart beyond referencing connection values from an existing Kubernetes secret.

## What the chart expects

The application requires an existing secret with these keys:

- `MONGO_DB_URI`
- `BI_MONGO_DB_URI`
- `REDIS_URL`
- `LICENSE_KEY`

Create the secret first, then set `server.existingSecret` to the Secret name:

```yaml
server:
  existingSecret: decisionrules-app-config
```

What goes into `server.existingSecret` is just the Kubernetes Secret name.
It is not a Mongo URL, not a Vault path, and not the secret contents.

The chart will fail to render if `server.existingSecret` is not provided.

## Example values

```yaml
client:
  route:
    host: app.example.com

server:
  existingSecret: decisionrules-app-config
  route:
    host: api.example.com

aiEngine:
  enabled: true
  provider: google-vertex
  family: google
  model: gemini-3-flash-preview
  additionalDataJson: '{"location":"global"}'
  existingSecret: decisionrules-ai-config

businessIntelligence:
  enabled: true
```

## Example secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: decisionrules-app-config
type: Opaque
stringData:
  MONGO_DB_URI: "mongodb://user:password@mongo.example.internal:27017/Decision?authSource=admin"
  BI_MONGO_DB_URI: "mongodb://user:password@mongo-bi.example.internal:27017/DecisionAudit?authSource=admin"
  REDIS_URL: "redis://:password@redis.example.internal:6379"
  LICENSE_KEY: "YOUR-LICENSE-KEY"
```

The matching Helm values would be:

```yaml
server:
  existingSecret: decisionrules-app-config
```

If AI Engine is enabled, create a separate Kubernetes Secret for the AI provider key and point `aiEngine.existingSecret` at that Secret name:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: decisionrules-ai-config
type: Opaque
stringData:
  AIA_SECRET: "YOUR-AI-PROVIDER-API-KEY"
```

```yaml
aiEngine:
  enabled: true
  existingSecret: decisionrules-ai-config
```

## Server sizing

The `server.solver` value selects how the server is sized:

| `server.solver` | Use for | Server CPU / memory per Pod | Autoscaling |
|---|---|---|---|
| `aero` (default) | Aero (V2) solver or mixed V1/V2 traffic | `4000m` / `8Gi` (requests = limits) | 2–5 Pods |
| `gaia` | Classic Gaia (V1) solver only | `1000m` / `1Gi` requests, `2000m` / `2Gi` limits | 2–10 Pods |

Aero uses several CPUs within one process, so it runs best on fewer, larger replicas. To size the server yourself, set `server.resources` and `server.autoscaling.minReplicas` / `maxReplicas`; they take precedence over the profile. See [server sizing](https://docs.decisionrules.io/doc/decisionrules-applications/server-app#minimal-requirements) for details.

### Upgrading from 0.1.x

The default server sizing changed to the `aero` profile. Version 0.1.x used `1000m` / `1Gi` requests, `2000m` / `2Gi` limits and autoscaling 2–10. To keep the previous sizing, set `server.solver: gaia`.

## Install

```bash
helm install decisionrules . \
  -n decisionrules \
  --create-namespace \
  --set server.existingSecret=decisionrules-app-config
```

Or with a values file:

```bash
helm install decisionrules . \
  -n decisionrules \
  --create-namespace \
  -f examples/my-values.yaml
```

## Verify

```bash
oc get pods -n decisionrules
oc get routes -n decisionrules
curl -sk https://$(oc get route decisionrules-server -n decisionrules -o jsonpath='{.spec.host}')/health-check
```

## Notes

- The chart does not create MongoDB, Redis, license, or AI provider secrets.
- The chart does not create MongoDB or Redis services, PVCs, StatefulSets, or init jobs.
- The Server and Business Intelligence containers both read `MONGO_DB_URI` and `BI_MONGO_DB_URI` from the existing secret referenced by `server.existingSecret`.
- Proxy settings apply to Server and AI Engine only. They are not injected into Business Intelligence.
