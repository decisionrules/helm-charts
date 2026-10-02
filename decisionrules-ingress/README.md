# DecisionRules Helm Charts with Ingress

## Prerequisites

1. A working Kubernetes cluster

2. Redis

3. MongoDB

4. A license key


## Installation

```
helm repo add decisionrules-ingress https://decisionrules.github.io/helm-charts/decisionrules-ingress/

helm install decisionrules-ingress decisionrules-ingress/decisionrules-ingress -f values.yaml
```


## Server sizing

The `solver` value selects how the server is sized:

| `solver` | Use for | Server CPU / memory per Pod | Autoscaling |
|---|---|---|---|
| `aero` (default) | Aero (V2) solver or mixed V1/V2 traffic | `4000m` / `4Gi` (requests = limits) | 2–5 Pods |
| `gaia` | Classic Gaia (V1) solver only | `1000m` / `1Gi` requests, `2000m` / `2Gi` limits | 2–10 Pods |

Aero uses several CPUs within one process, so it runs best on fewer, larger replicas. The profiles are defined in `solverProfiles` in `values.yaml`, so you can adjust them, for example `--set solverProfiles.aero.maxReplicas=8`. To size the server yourself regardless of the profile, set `resources.server` and `autoscalingServer.minReplicas` / `maxReplicas`; they take precedence over the profile. See [server sizing](https://docs.decisionrules.io/doc/decisionrules-applications/server-app#minimal-requirements) for details.

### Upgrading from 0.2.x

The default server sizing changed to the `aero` profile. Previous versions used `1000m` / `1Gi` requests, `2000m` / `2Gi` limits and autoscaling 2–10. To keep the previous sizing, set `solver: gaia`.

## Configuration

Example values.yaml:
```
namespace: decisionrules

bi:
  enabled: false # set to true to enable audit

domain:
  client: "yourdomain.local" # to be filled by user
  api: "api.yourdomain.local" # to be filled by user
  bi: "bi.yourdomain.local" # to be filled by user

env:
  client:
    API_URL: "" # to be filled by user
    BI_API_URL: "" # to be filled by user
  server:
    REDIS_URL: "" # to be filled by user
    MONGO_DB_URI: "" # to be filled by user
    CLIENT_URL: "" # to be filled by user
    API_URL: "" # to be filled by user
    LICENSE_KEY: "" # to be filled by user
  bi:
    BI_MONGO_DB_URI: "" # to be filled by user

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

https://docs.decisionrules.io/doc/other-deployment-options/docker-and-on-premise/microsoft-azure-setup/cache-azure-cache-for-redis

https://docs.decisionrules.io/doc/other-deployment-options/docker-and-on-premise/microsoft-azure-setup/database-azure-cosmosdb

https://docs.decisionrules.io/doc/other-deployment-options/docker-and-on-premise/kubernetes-setup

https://docs.decisionrules.io/doc/other-deployment-options/docker-and-on-premise/containers-environmental-variables

https://docs.decisionrules.io/doc/business-intelligence/audit-logs

