# DecisionRules Helm Charts for EKS

## Prerequisites

1. A working EKS cluster

2. Redis

3. MongoDB

4. A license key


## Installation

```
helm repo add decisionrules-eks https://decisionrules.github.io/helm-charts/decisionrules-eks/

helm install decisionrules-eks decisionrules-eks/decisionrules-eks -f values.yaml
```


## Secrets

Sensitive configuration — `LICENSE_KEY`, `MONGO_DB_URI`, `REDIS_URL`, and `BI_MONGO_DB_URI` (when BI is enabled) — can be supplied in two ways:

- **`secrets.existingSecret` (recommended for production):** you create a Kubernetes Secret containing these keys, and the chart references it via `secretKeyRef`. Credentials never appear in values files, in the Helm release, or in the rendered pod specs.
- **Plain `env` values (fallback):** if `secrets.existingSecret` is left empty, the values from the `env` section are injected directly as environment variables, as in previous chart versions. Fine for evaluation and development; not recommended for production, since the credentials end up in cleartext in the Deployment spec (visible to anyone who can read Deployments) and in your values file.

When `secrets.existingSecret` is set, it takes precedence: the `env` values for `REDIS_URL`, `MONGO_DB_URI`, `LICENSE_KEY` and `BI_MONGO_DB_URI` are ignored.

### Using an existing Secret

Create a Secret in the release namespace with the required keys:

```bash
kubectl create secret generic decisionrules-config \
  --namespace decisionrules \
  --from-literal=LICENSE_KEY='YOUR-LICENSE-KEY' \
  --from-literal=MONGO_DB_URI='mongodb://user:password@mongo.example.internal:27017/Decision?authSource=admin' \
  --from-literal=REDIS_URL='redis://:password@redis.example.internal:6379' \
  --from-literal=BI_MONGO_DB_URI='mongodb://user:password@mongo.example.internal:27017/DecisionAudit?authSource=admin'
```

Or as a manifest:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: decisionrules-config
  namespace: decisionrules
type: Opaque
stringData:
  LICENSE_KEY: "YOUR-LICENSE-KEY"
  MONGO_DB_URI: "mongodb://user:password@mongo.example.internal:27017/Decision?authSource=admin"
  REDIS_URL: "redis://:password@redis.example.internal:6379"
  BI_MONGO_DB_URI: "mongodb://user:password@mongo.example.internal:27017/DecisionAudit?authSource=admin"
```

Then point the chart at it:

```yaml
secrets:
  existingSecret: decisionrules-config
```

`secrets.existingSecret` is the Kubernetes Secret **name** — not a Mongo URL, not a Vault path, and not the secret contents.

`BI_MONGO_DB_URI` is only required in the Secret when `bi.enabled=true`.

### Using AWS Secrets Manager (External Secrets Operator)

On EKS, the recommended setup is to keep the credentials in AWS Secrets Manager and sync them into the cluster with the [External Secrets Operator](https://external-secrets.io/), authenticated via IRSA:

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: decisionrules
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-central-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa   # ServiceAccount annotated with an IAM role (IRSA)
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: decisionrules-config
  namespace: decisionrules
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: aws-secrets-manager
  target:
    name: decisionrules-config   # the Kubernetes Secret this creates
  data:
    - secretKey: LICENSE_KEY
      remoteRef:
        key: decisionrules/prod   # your Secrets Manager secret name
        property: LICENSE_KEY
    - secretKey: MONGO_DB_URI
      remoteRef:
        key: decisionrules/prod
        property: MONGO_DB_URI
    - secretKey: REDIS_URL
      remoteRef:
        key: decisionrules/prod
        property: REDIS_URL
    - secretKey: BI_MONGO_DB_URI
      remoteRef:
        key: decisionrules/prod
        property: BI_MONGO_DB_URI
```

Any other mechanism that materializes a Kubernetes Secret with these keys works the same way (Sealed Secrets, SOPS, Secrets Store CSI driver with sync, Vault, ...). The chart only needs the Secret to exist in the release namespace.

### Notes

- Avoid passing secrets with `--set` (they end up in your shell history) and do not commit values files containing credentials to version control — with `secrets.existingSecret` there is nothing sensitive to commit.

### Upgrading from 0.2.x

No values changes are required: without `secrets.existingSecret`, the chart renders the same manifests as before. To adopt the Secret-based setup, create the Secret, set `secrets.existingSecret`, and (optionally) remove the sensitive values from your values file.


## Server sizing

The `solver` value selects how the server is sized:

| `solver` | Use for | Server CPU / memory per Pod | Autoscaling |
|---|---|---|---|
| `aero` (default) | Aero (V2) solver or mixed V1/V2 traffic | `4000m` / `8Gi` (requests = limits) | 2–5 Pods |
| `gaia` | Classic Gaia (V1) solver only | `1000m` / `1Gi` requests, `2000m` / `2Gi` limits | 2–10 Pods |

Aero uses several CPUs within one process, so it runs best on fewer, larger replicas. The profiles are defined in `solverProfiles` in `values.yaml`, so you can adjust them, for example `--set solverProfiles.aero.maxReplicas=8`. To size the server yourself regardless of the profile, set `resources.server` and `autoscalingServer.minReplicas` / `maxReplicas`; they take precedence over the profile. See [server sizing](https://docs.decisionrules.io/doc/decisionrules-applications/server-app#minimal-requirements) for details.

### Upgrading from 0.3.x

The default server sizing changed to the `aero` profile. Previous versions used `1000m` / `1Gi` requests, `2000m` / `2Gi` limits and autoscaling 2–10. To keep the previous sizing, set `solver: gaia`.

## Configuration

Example values.yaml:
```
namespace: decisionrules

secrets:
  existingSecret: "decisionrules-config" # recommended; leave "" to use plain env values below

bi:
  enabled: false # set to true to enable audit

env:
  client:
    API_URL: "" # to be filled by user
    BI_API_URL: "" # to be filled by user
  server:
    REDIS_URL: "" # ignored when secrets.existingSecret is set
    MONGO_DB_URI: "" # ignored when secrets.existingSecret is set
    CLIENT_URL: "" # to be filled by user
    API_URL: "" # to be filled by user
    LICENSE_KEY: "" # ignored when secrets.existingSecret is set
  bi:
    BI_MONGO_DB_URI: "" # ignored when secrets.existingSecret is set

solver: aero # or gaia, see Server sizing

images:
  client: decisionrules/client
  server: decisionrules/server
  bi: decisionrules/business-intelligence

resources:
  client:
    requests:
      cpu: 250m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi
  bi:
    requests:
      cpu: 1000m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 4Gi

replicaCount:
  client: 2
  server: 2
  bi: 2

autoscalingServer:
  targetCPUUtilizationPercentage: 60
```

https://docs.decisionrules.io/doc/other-deployment-options/docker-and-on-premise/aws/cache-amazon-elasticache

https://docs.decisionrules.io/doc/other-deployment-options/docker-and-on-premise/kubernetes-setup

https://docs.decisionrules.io/doc/other-deployment-options/docker-and-on-premise/containers-environmental-variables

https://docs.decisionrules.io/doc/business-intelligence/audit-logs
