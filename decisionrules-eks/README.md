# DecisionRules Helm Charts for EKS

## Prerequisites

1. A working EKS cluster

2. Redis

https://docs.decisionrules.io/doc/other-deployment-options/docker-and-on-premise/aws/cache-amazon-elasticache

3. MongoDB


4. A license key


## Installation

```
helm repo add decisionrules-eks https://decisionrules.github.io/helm-charts/decisionrules-eks/

helm install decisionrules-eks decisionrules-eks/decisionrules-eks -f values.yaml
```


## Configuration

Example values.yaml:
```
namespace: decisionrules

bi:
  enabled: false # set to true to enable audit

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
  server:
    requests:
      cpu: 1000m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi
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
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 60
```

https://docs.decisionrules.io/doc/other-deployment-options/docker-and-on-premise/kubernetes-setup

https://docs.decisionrules.io/doc/other-deployment-options/docker-and-on-premise/containers-environmental-variables

https://docs.decisionrules.io/doc/business-intelligence/audit-logs
