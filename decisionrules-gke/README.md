# DecisionRules Helm Chart Deployment Guide (GKE)

This chart deploys the DecisionRules application components to Google Kubernetes Engine (GKE):

- Client
- Server
- Business Intelligence (optional)
- AI Engine (optional)

The client and server are exposed through a single GKE Ingress (Google Cloud Application Load Balancer), with a Google-managed TLS certificate by default.

MongoDB and Redis are not deployed, managed, or configured by this chart beyond referencing connection values from an existing Kubernetes secret. On Google Cloud these are typically MongoDB Atlas and Memorystore for Redis.

## Prerequisites

- A GKE cluster (Standard or Autopilot) with the HTTP Load Balancing add-on enabled (the default).
- A VPC-native cluster (the default for new clusters). The chart uses container-native load balancing (NEGs).
- Two DNS names you control, one for the client and one for the server (e.g. `app.example.com` and `api.example.com`).
- Recommended: a reserved static IP address, so the DNS records do not have to change if the Ingress is recreated:

```bash
gcloud compute addresses create decisionrules-ip --global
gcloud compute addresses describe decisionrules-ip --global --format='value(address)'
```

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
It is not a Mongo URL, not a Secret Manager path, and not the secret contents.

The chart will fail to render if `server.existingSecret` is not provided.

The chart also needs the public hostnames of the client and the server:

```yaml
ingress:
  hosts:
    client: app.example.com
    server: api.example.com
```

## Example values

```yaml
ingress:
  hosts:
    client: app.example.com
    server: api.example.com
  staticIpName: decisionrules-ip

server:
  existingSecret: decisionrules-app-config

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

### Using Google Secret Manager (External Secrets Operator)

On GKE, the recommended setup is to keep the credentials in Google Secret Manager and sync them into the cluster with the [External Secrets Operator](https://external-secrets.io/), authenticated via Workload Identity:

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: gcp-secret-manager
  namespace: decisionrules
spec:
  provider:
    gcpsm:
      projectID: my-gcp-project
      auth:
        workloadIdentity:
          clusterLocation: europe-west1
          clusterName: my-gke-cluster
          serviceAccountRef:
            name: external-secrets-sa   # Kubernetes ServiceAccount allowed to read the secrets via Workload Identity
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: decisionrules-app-config
  namespace: decisionrules
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: gcp-secret-manager
  target:
    name: decisionrules-app-config   # the Kubernetes Secret this creates
  data:
    - secretKey: MONGO_DB_URI
      remoteRef:
        key: decisionrules-mongo-db-uri   # your Secret Manager secret names
    - secretKey: BI_MONGO_DB_URI
      remoteRef:
        key: decisionrules-bi-mongo-db-uri
    - secretKey: REDIS_URL
      remoteRef:
        key: decisionrules-redis-url
    - secretKey: LICENSE_KEY
      remoteRef:
        key: decisionrules-license-key
```

The service account needs the `roles/secretmanager.secretAccessor` role on these secrets. The `decisionrules-ai-config` Secret with `AIA_SECRET` can be synced the same way.

Any other mechanism that materializes a Kubernetes Secret with these keys works the same way (Sealed Secrets, SOPS, Vault, ...). The chart only needs the Secret to exist in the release namespace.

## Exposing the application

By default the chart creates:

- an `Ingress` with class `gce` (external Application Load Balancer) routing `ingress.hosts.client` to the client and `ingress.hosts.server` to the server,
- a `ManagedCertificate` (Google-managed TLS certificate) for both hosts,
- a `FrontendConfig` redirecting HTTP to HTTPS,
- a `BackendConfig` per service, so the load balancer health checks use `/health-check` on the server and `/` on the client.

`CLIENT_URL` and `API_URL` are derived from the hostnames.

After install, point DNS A records for both hosts at the load balancer IP. The managed certificate is provisioned only once DNS resolves to the load balancer, which can take up to 60 minutes. Until then HTTPS requests fail.

### Ingress options

| Value | Description |
|---|---|
| `ingress.className` | `gce` (external, default) or `gce-internal` (internal, VPC only) |
| `ingress.staticIpName` | Reserved static IP name (global for `gce`, regional for `gce-internal`) |
| `ingress.tls.managedCertificate.enabled` | Google-managed certificate (`gce` only) |
| `ingress.tls.secretName` | Kubernetes TLS Secret with your own certificate |
| `ingress.tls.preSharedCerts` | Comma-separated names of certificates uploaded to Google Cloud |
| `ingress.tls.redirectToHttps` | Redirect HTTP to HTTPS (`gce` only) |
| `ingress.tls.sslPolicy` | Google Cloud SSL policy name, e.g. to enforce TLS 1.2+ (`gce` only) |
| `ingress.backendConfig.timeoutSec` | Load balancer backend timeout (default 30s) |
| `ingress.backendConfig.securityPolicy` | Cloud Armor security policy name (`gce` only) |
| `ingress.annotations` | Extra Ingress annotations |

### Internal load balancer

For a VPC-only deployment, use the internal Application Load Balancer. It needs a [proxy-only subnet](https://cloud.google.com/load-balancing/docs/proxy-only-subnets) in the cluster's region. Google-managed certificates are not available for internal load balancers, so supply your own:

```yaml
ingress:
  className: gce-internal
  staticIpName: decisionrules-internal-ip   # regional address
  hosts:
    client: app.internal.example.com
    server: api.internal.example.com
  tls:
    managedCertificate:
      enabled: false
    secretName: decisionrules-tls
```

### Own ingress or Gateway API

Set `ingress.enabled=false` to expose the services yourself (e.g. with Gateway API `HTTPRoute`s). In that case the public URLs must be set explicitly:

```yaml
ingress:
  enabled: false

server:
  apiUrl: https://api.example.com
  clientUrl: https://app.example.com/#
```

The services are `<release>-client-service` (port 4000) and `<release>-server-service` (port 8080).

## Security context

On OpenShift, the restricted SCC enforces non-root containers. GKE has no such default, so the chart sets it explicitly for every component. This is compatible with the Kubernetes `restricted` Pod Security Standard and with typical Gatekeeper / Policy Controller rules:

- `runAsNonRoot: true` with the image's user ID (`runAsUser: 100`, AI Engine `999`)
- `seccompProfile: RuntimeDefault`
- `allowPrivilegeEscalation: false` and all capabilities dropped

The client must use the rootless image (`latest-rootless`, listening on port 4000). To remove a security context, set it to `null` (an empty `{}` is merged with the defaults and has no effect):

```yaml
server:
  podSecurityContext: null
  securityContext: null
```

## Server sizing

The `server.solver` value selects how the server is sized:

| `server.solver` | Use for | Server CPU / memory per Pod | Autoscaling |
|---|---|---|---|
| `aero` (default) | Aero (V2) solver or mixed V1/V2 traffic | `4000m` / `4Gi` (requests = limits) | 2–5 Pods |
| `gaia` | Classic Gaia (V1) solver only | `1000m` / `1Gi` requests, `2000m` / `2Gi` limits | 2–10 Pods |

Aero uses several CPUs within one process, so it runs best on fewer, larger replicas. The profiles are defined in `server.solverProfiles` in `values.yaml`, so you can adjust them, for example `--set server.solverProfiles.aero.maxReplicas=8`. To size the server yourself regardless of the profile, set `server.resources` and `server.autoscaling.minReplicas` / `maxReplicas`; they take precedence over the profile. See [server sizing](https://docs.decisionrules.io/doc/decisionrules-applications/server-app#minimal-requirements) for details.

On GKE Autopilot you pay for the requested resources, so the `aero` profile with two server Pods requests 8 vCPU and 8 GiB for the server alone.

## Install

```bash
helm repo add decisionrules-gke https://decisionrules.github.io/helm-charts/decisionrules-gke
helm repo update
```

```bash
helm install decisionrules decisionrules-gke/decisionrules-gke \
  -n decisionrules \
  --create-namespace \
  --set server.existingSecret=decisionrules-app-config \
  --set ingress.hosts.client=app.example.com \
  --set ingress.hosts.server=api.example.com
```

Or with a values file:

```bash
helm install decisionrules decisionrules-gke/decisionrules-gke \
  -n decisionrules \
  --create-namespace \
  -f examples/my-values.yaml
```

## Verify

```bash
kubectl get pods -n decisionrules
kubectl get ingress -n decisionrules
kubectl get managedcertificate -n decisionrules
curl -s https://api.example.com/health-check
```

If the Ingress shows no address or the backends stay unhealthy, check the Ingress events:

```bash
kubectl describe ingress decisionrules-ingress -n decisionrules
```

### What to expect after install

Google Cloud provisions the load balancer asynchronously. Typical timeline:

| What | Ready after |
|---|---|
| Pods `Running` | 2–5 minutes (Autopilot adds nodes on demand) |
| Ingress `ADDRESS` | 5–10 minutes |
| Backends `HEALTHY` | a few minutes after the address |
| HTTP answers with a redirect to HTTPS | up to 10 more minutes |
| ManagedCertificate `Active` | 15–60 minutes after DNS resolves to the load balancer |

Check the backend health with:

```bash
kubectl get ingress decisionrules-ingress -n decisionrules \
  -o jsonpath='{.metadata.annotations.ingress\.kubernetes\.io/backends}'; echo
```

These are expected and resolve on their own:

- `Translation failed: ... no BackendConfig for service port exists` and `ManagedCertificate ... missing` warnings right after the first install. Helm creates the BackendConfig, FrontendConfig and ManagedCertificate resources a moment after the Ingress, and the GKE controller retries within seconds. Only warnings that keep repeating need attention.
- `Empty reply from server`, `404` or `502` for the first 10–15 minutes after the load balancer is created, while Google distributes its configuration.
- `API_URL health check failed` in the server log when the server starts before the certificate is `Active`. Restart the server once the certificate is active: `kubectl rollout restart deploy/decisionrules-server -n decisionrules`.

## Notes

- The chart does not create MongoDB, Redis, license, or AI provider secrets.
- The chart does not create MongoDB or Redis services, PVCs, StatefulSets, or init jobs.
- The Server and Business Intelligence containers both read `MONGO_DB_URI` and `BI_MONGO_DB_URI` from the existing secret referenced by `server.existingSecret`.
- Proxy settings apply to Server and AI Engine only. They are not injected into Business Intelligence.
- The AI Engine is only reachable inside the cluster and Business Intelligence has no Service; neither is exposed through the Ingress.
