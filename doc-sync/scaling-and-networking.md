# Scaling & Load Balancing

How scaling works in the Tech Salary platform on Kubernetes.

---

## Current State

Every deployment is set to `replicas: 1` — one pod per service.
This is sufficient for coursework demo. Below explains how scaling
works in this architecture and what the lecturer expects you to know.

---

## Manual Scaling (works right now)

```bash
# Scale BFF to 3 pods
kubectl scale deployment/bff -n app --replicas=3

# Verify — see 3 bff pods
kubectl get pods -n app -l app=bff

# Scale back down
kubectl scale deployment/bff -n app --replicas=1
```

The moment you scale to 3, the **ClusterIP Service** automatically
load balances traffic across all 3 pods using round-robin:

```
Client request
      ↓
bff ClusterIP (virtual IP, port 4000)
      ↓  kube-proxy distributes via iptables
   ┌──┴──────────┬──────────────┐
 bff-pod-1    bff-pod-2    bff-pod-3
```

No config change needed — the Service selector `app: bff` picks up
every pod with that label automatically.

---

## Which Services Can Scale

| Service | Can Scale? | Reason |
|---|---|---|
| `frontend` | ✅ Yes | Stateless — serves static files from image |
| `bff` | ✅ Yes | Stateless — routes requests, no local state |
| `identity` | ✅ Yes | Stateless — Spring Boot reads/writes DB only |
| `salary-submission` | ✅ Yes | Stateless — Spring Boot reads/writes DB only |
| `vote` | ✅ Yes | Stateless — Node.js reads/writes DB only |
| `search` | ✅ Yes | Stateless — read-only queries |
| `stats` | ✅ Yes | Stateless — read-only queries |
| `postgres` | ❌ No | Stateful — single pod with `ReadWriteOnce` PVC |

This is exactly why the assessment requires **"services must remain
stateless"** — stateless pods can be freely replicated. PostgreSQL
cannot because `ReadWriteOnce` allows only one node to mount the PVC
at a time.

---

## How Traffic is Distributed When Scaled

```
Ingress
  ↓
bff ClusterIP  ← kube-proxy uses iptables rules to pick a pod
  ├── bff-pod-1   (handles request A)
  ├── bff-pod-2   (handles request B)
  └── bff-pod-3   (handles request C)
        ↓
   All pods connect to the same:
   postgres.data.svc.cluster.local:5432
```

Every pod reads the same DB_HOST and DB_PASSWORD from the shared
ConfigMap and Secret. The database is the single source of truth.

---

## Networking Layers

### Layer 1 — External Load Balancer

```
Browser
  ↓
Azure Load Balancer (AKS) / localhost (Docker Desktop)
  ↓
NGINX Ingress Controller  ←  ingress-nginx namespace
```

On AKS the Ingress Controller gets a real public IP from Azure's
load balancer. On Docker Desktop it binds to `localhost`. This is
the **only public entry point**.

### Layer 2 — Ingress (L7 Path-Based Routing)

`k8s/ingress.yaml` routes by URL path:

```
path: /api  →  bff ClusterIP :4000
path: /     →  frontend ClusterIP :80
```

This is **Layer 7 load balancing** — routing decisions are made on
the HTTP URL, not just IP and port.

### Layer 3 — ClusterIP Services (L4 Internal Load Balancing)

All internal services use `type: ClusterIP`:

| Service | Namespace | Port |
|---|---|---|
| `frontend` | app | 80 |
| `bff` | app | 4000 |
| `identity` | app | 8082 |
| `salary-submission` | app | 8081 |
| `vote` | app | 8083 |
| `search` | app | 8084 |
| `stats` | app | 8085 |
| `postgres` | data | 5432 |

kube-proxy intercepts traffic to the ClusterIP virtual IP and
distributes it across all healthy pods — **L4 round-robin**.

### Layer 4 — Cross-Namespace DNS Isolation

Services reach postgres across namespaces via Kubernetes DNS:

```
postgres.data.svc.cluster.local:5432
```

Set in `k8s/app/configmap.yaml`:

```yaml
DB_HOST: postgres.data.svc.cluster.local
```

Pods in `app` cannot reach pods in `data` by pod IP directly.
They must go through the Service DNS name — enforcing
**namespace network isolation**.

### Layer 5 — BFF as API Gateway

The BFF is the single internal router for all frontend traffic:

```
Frontend → BFF :4000
              ↓
    ┌─────────┼──────────┬──────────┬──────────┐
identity  salary-sub   vote      search     stats
 :8082      :8081      :8083      :8084      :8085
```

---

## Full Traffic Flow

```
Browser
  │  HTTP/HTTPS
  ▼
Azure Load Balancer          ← L4, public IP, forwards to node
  │
  ▼
NGINX Ingress Controller     ← L7, reads URL path
  │
  ├── path: /    ──────────► frontend ClusterIP :80
  │
  └── path: /api ──────────► bff ClusterIP :4000
                                  │
                                  ├── /auth/*       → identity :8082
                                  ├── /submissions  → salary-submission :8081
                                  ├── /votes        → vote :8083
                                  ├── /search       → search :8084
                                  └── /stats        → stats :8085
                                                          │
                                             postgres.data.svc.cluster.local:5432
```

---

## Automatic Scaling — HPA (not configured, for reference)

HPA (Horizontal Pod Autoscaler) scales deployments automatically
based on CPU or memory usage. To enable it, two things are needed:

**1. Add resource requests to the deployment:**

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

**2. Create an HPA manifest:**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: bff-hpa
  namespace: app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: bff
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

HPA requires `resources.requests` so Kubernetes knows what 70% means.
Currently not configured because this is a single-node coursework cluster.

---

## Key Points for the Lecturer

| Question | Answer |
|---|---|
| How does load balancing work across replicas? | kube-proxy intercepts ClusterIP traffic and distributes across pod endpoints using iptables — L4 round-robin |
| Why can all 7 services scale but not postgres? | Services are stateless (no disk writes). Postgres has a `ReadWriteOnce` PVC — only one node can mount it |
| What makes a service safe to scale? | No local session state, no local file writes — all state lives in shared PostgreSQL |
| What is needed for auto-scaling? | `resources.requests/limits` in each deployment + a HorizontalPodAutoscaler manifest |
| What is the single scaling bottleneck? | PostgreSQL — the shared stateful component. In production replace with Azure Database for PostgreSQL + PgBouncer connection pooling |
| Why ClusterIP and not LoadBalancer for internal services? | ClusterIP keeps services private — only reachable inside the cluster. LoadBalancer would expose each service publicly with its own IP, which is both insecure and unnecessary |
