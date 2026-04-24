# Docker Desktop Kubernetes — Manual Setup (First Time)

Complete step-by-step guide to run the full Tech Salary platform locally using
Docker Desktop's built-in Kubernetes cluster.

---

## Pre-requisites

1. Docker Desktop installed with **Kubernetes enabled**
   Settings → Kubernetes → Enable Kubernetes → Apply & Restart

2. Confirm the context is correct:

```bash
kubectl config current-context
# must print: docker-desktop

kubectl get nodes
# must show 1 node Ready
```

---

## Step 1 — Install NGINX Ingress Controller

Only needed once. Skip if already installed.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Wait for the controller pod to be Ready (~60s)
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

---

## Step 2 — Create Namespaces

```bash
kubectl apply -f k8s/namespace.yaml

# Verify — should list: ingress-nginx, app, data
kubectl get ns
```

---

## Step 3 — Build all Docker Images Locally

Docker Desktop shares the local Docker daemon with Kubernetes.
Images built here are immediately available to pods — no push required.

```bash
# Run all commands from the repository root
docker build -t techsalary-local/frontend:latest          services/frontend/
docker build -t techsalary-local/bff:latest               services/bff/
docker build -t techsalary-local/salary-submission:latest  services/salary-submission/
docker build -t techsalary-local/identity:latest          services/identity/
docker build -t techsalary-local/vote:latest              services/vote/
docker build -t techsalary-local/search:latest            services/search/
docker build -t techsalary-local/stats:latest             services/stats/

# Verify all 7 images exist
docker images | grep techsalary-local
```

---

## Step 4 — Deploy PostgreSQL

```bash
kubectl apply -f k8s/postgres/postgres-secret.yaml
kubectl apply -f k8s/postgres/postgres-pvc.yaml
kubectl apply -f k8s/postgres/postgres-deployment.yaml

# Wait until the pod is Ready
kubectl wait --for=condition=ready pod \
  -l app=postgres -n data --timeout=120s

# Verify
kubectl get all -n data
```

---

## Step 5 — Initialise the Database simple

```bash
# 3. Initialise database (first time only)
POD=$(kubectl get pod -n data -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec -i -n data $POD -- psql -U salaryapp -d salarydb < db/init.sql
```


---

## Step 6 — Deploy ConfigMap and Secret

```bash
kubectl apply -f k8s/app/configmap.yaml
kubectl apply -f k8s/app/app-secret.yaml

# Verify
kubectl get configmap app-config -n app
kubectl get secret app-secret -n app
```

---

## Step 7 — Deploy all Microservices

```bash
kubectl apply -f k8s/app/frontend-deployment.yaml
kubectl apply -f k8s/app/bff-deployment.yaml
kubectl apply -f k8s/app/salary-submission-deployment.yaml
kubectl apply -f k8s/app/identity-deployment.yaml
kubectl apply -f k8s/app/vote-deployment.yaml
kubectl apply -f k8s/app/search-deployment.yaml
kubectl apply -f k8s/app/stats-deployment.yaml
```

---

## Step 8 — Apply Ingress

```bash
kubectl apply -f k8s/ingress.yaml

# Verify
kubectl get ingress -n app
```

---

## Step 8.5 — Forward Ingress to localhost:8080

Docker Desktop on Mac assigns an internal IP (e.g. `172.22.0.14`) to the
LoadBalancer instead of `localhost`. Run this port-forward in a **dedicated
terminal and leave it open** for the entire session. All traffic still goes
through the ingress routing rules (`/api` → BFF, `/` → frontend).

```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

> All curl commands below use `http://localhost:8080` instead of
> `http://localhost`.

---

## Step 9 — Verify Everything is Running

```bash
kubectl get pods -n app
kubectl get pods -n data
kubectl get svc -n app
kubectl get svc -n data
```

Expected output:

```
NAMESPACE   NAME                          READY   STATUS
app         bff-xxx                       1/1     Running
app         frontend-xxx                  1/1     Running
app         identity-xxx                  1/1     Running
app         salary-submission-xxx         1/1     Running
app         vote-xxx                      1/1     Running
app         search-xxx                    1/1     Running
app         stats-xxx                     1/1     Running
data        postgres-xxx                  1/1     Running
```

---

## Step 10 — Test the Workflow

Run these in order to prove the full system works end-to-end.

### Submit a salary (no login needed)

```bash
curl -X POST http://localhost:8080/api/submissions \
  -H "Content-Type: application/json" \
  -d '{
    "jobTitle": "Software Engineer",
    "company": "WSO2",
    "country": "Sri Lanka",
    "experienceLevel": "MID",
    "baseSalary": 250000,
    "anonymize": true
  }'
# Expect: 201 with status=PENDING
```

### Check DB shows PENDING

```bash
POD=$(kubectl get pod -n data -l app=postgres -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n data $POD -- \
  psql -U salaryapp -d salarydb \
  -c "SELECT id, job_title, status FROM salary.salary_submissions;"
# Expect: status = PENDING
```

### Sign up a user

```bash
curl -X POST http://localhost:8080/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email": "user1@test.com", "password": "Test1234!"}'
# Expect: 200 with userId
```

### Login and get a JWT token

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user1@test.com", "password": "Test1234!"}'
# Expect: { token: "eyJ...", userId: "..." }

# Save for next steps
TOKEN="eyJ..."
SUBMISSION_ID="<id from submit step>"
```

### Vote 3 times (create 3 users, vote once each)

```bash
curl -X POST http://localhost:8080/api/votes \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"submissionId": "'$SUBMISSION_ID'", "voteType": "upvote"}'
# Expect: { message: "Vote recorded" }
```

### Check DB shows APPROVED

```bash
kubectl exec -n data $POD -- \
  psql -U salaryapp -d salarydb \
  -c "SELECT id, job_title, status, upvotes FROM salary.salary_submissions;"
# Expect: status = APPROVED after 3rd net upvote
```

### Search returns the approved salary

```bash
curl "http://localhost:8080/api/search?role=Software+Engineer"
# Expect: JSON array with the approved submission
# anonymize=true → company shows as [Anonymous Company]
```

### Stats reflect the approved salary

```bash
curl "http://localhost:8080/api/stats?role=Software+Engineer"
# Expect: { average, median, p75, total }
```

---

## Useful Debug Commands

```bash
# Logs for any service
kubectl logs -n app deployment/bff
kubectl logs -n app deployment/vote
kubectl logs -n app deployment/identity
kubectl logs -n app deployment/salary-submission
kubectl logs -n app deployment/search
kubectl logs -n app deployment/stats
kubectl logs -n app deployment/frontend

# Follow logs live
kubectl logs -n app deployment/bff -f

# Describe a pod that is not starting (shows Events section)
kubectl describe pod -n app -l app=bff

# Shell into the postgres pod
POD=$(kubectl get pod -n data -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n data $POD -- psql -U salaryapp -d salarydb
```

---

## Rebuild a Single Service

When a service's code changes, rebuild just that image and restart its pod:

```bash
docker build -t techsalary-local/bff:latest services/bff/
kubectl rollout restart deployment/bff -n app
kubectl rollout status deployment/bff -n app
```

---

## Tear Down

```bash
# Remove all app resources
kubectl delete namespace app
kubectl delete namespace data

# Remove ingress controller
kubectl delete namespace ingress-nginx

# Or delete everything and start clean
kubectl delete -f k8s/app/
kubectl delete -f k8s/postgres/
kubectl delete -f k8s/namespace.yaml
kubectl delete -f k8s/ingress.yaml
```


# Chnage 
```bash
kubectl apply -f k8s/app/frontend-deployment.yaml
kubectl rollout status deployment/frontend -n app
```
