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
