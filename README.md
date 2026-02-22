# 📦 techsalary-platform

> **7BUIS027C.2 Cloud Computing Applications 2026**  
> University of Westminster — Group Coursework  
> Due: **16 April 2026, 23:59 IST**

A community-driven tech salary transparency platform for Sri Lanka, built with microservices, Docker, and deployed on a single-node Kubernetes cluster on Azure.

---

## 📋 Table of Contents

- [Branch Strategy](#-branch-strategy)
- [Getting Started](#-getting-started)
- [Project Structure](#-project-structure)
- [Member Responsibilities](#-member-responsibilities)
- [Prerequisites](#-prerequisites)
- [Local Development Setup](#-local-development-setup)
- [Build & Push Docker Images](#-build--push-docker-images)
- [Deploy to Kubernetes](#-deploy-to-kubernetes)
- [Initialize the Database](#-initialize-the-database)
- [Testing the Full Workflow](#-testing-the-full-workflow)
- [Environment Variables](#-environment-variables)

---

## 🌿 Branch Strategy

We use **two long-lived branches** and **member feature branches**.

```
main
├── stg        ← staging — merge here first for testing
│   ├── feature/m1-infra-setup
│   ├── feature/m2-salary-service
│   ├── feature/m3-identity-service
│   ├── feature/m4-bff-vote-service
│   └── feature/m5-frontend-search
└── prod       ← production — only merge from stg after testing passes
```

### Branch Rules

| Branch | Purpose | Who can merge |
|--------|---------|--------------|
| `prod` | Live production deployment on AKS | PR from `stg` only — all members approve |
| `stg` | Staging — integration testing | PR from feature branches — 1 reviewer required |
| `feature/m*-*` | Each member's personal work branch | You own it |

### ⚠️ Rules — Everyone Must Follow

- ❌ **Never commit directly to `stg` or `prod`**
- ❌ **Never force-push to `stg` or `prod`**
- ✅ **Always work on your own feature branch**
- ✅ **Always open a Pull Request to merge into `stg`**
- ✅ **At least 1 other member must review and approve your PR**
- ✅ **Delete your feature branch after the PR is merged**

---

## 🚀 Getting Started

### Step 1 — Clone the Repository

```bash
git clone https://github.com/<your-org>/techsalary-platform.git
cd techsalary-platform
```

### Step 2 — Create Your Personal Feature Branch

Each member creates **their own branch** off `stg`. Use the naming convention below:

```bash
# First, make sure you're on the latest stg
git checkout stg
git pull origin stg

# Create your personal branch
# Replace <member-number> and <short-description>
git checkout -b feature/m1-infra-setup       # Member 1
git checkout -b feature/m2-salary-service    # Member 2
git checkout -b feature/m3-identity-service  # Member 3
git checkout -b feature/m4-bff-vote          # Member 4
git checkout -b feature/m5-frontend-search   # Member 5
```

### Step 3 — Work on Your Branch

```bash
# Make your changes, then stage and commit
git add .
git commit -m "feat(m2): add salary submission POST endpoint"

# Push your branch to remote
git push origin feature/m2-salary-service
```

### Step 4 — Open a Pull Request to `stg`

1. Go to the GitHub repository
2. Click **"Compare & pull request"** on your branch
3. Set the **base branch to `stg`** (not `main`, not `prod`)
4. Fill in the PR description using the template below
5. Request a review from **at least 1 other team member**
6. Once approved, **merge and delete your branch**

#### PR Description Template

```
## What does this PR do?
Brief description of the changes.

## Member
M[ ] — Name

## Service(s) changed
- [ ] frontend
- [ ] bff
- [ ] salary-submission
- [ ] identity
- [ ] vote
- [ ] search
- [ ] stats
- [ ] k8s manifests
- [ ] db schema

## Checklist
- [ ] No hardcoded passwords or secrets
- [ ] No email stored in salary tables
- [ ] .env.example updated if new env vars added
- [ ] Dockerfile tested locally
- [ ] README updated if setup steps changed
```

### Step 5 — Merging `stg` → `prod`

Once all features are integrated and tested on `stg`, **one PR** is opened from `stg` into `prod`. All 5 members should approve this PR before merging.

```bash
# This is done as a team — do NOT do this alone
# Open a PR on GitHub: stg → prod
```

---

## 📁 Project Structure

```
techsalary-platform/
├── README.md
├── .gitignore
├── db/
│   ├── init.sql                        ← Combined by M1 (do not edit manually)
│   ├── identity-schema.sql             ← Written by M3
│   ├── salary-schema.sql               ← Written by M2
│   └── community-schema.sql            ← Written by M4
├── k8s/                                ← All owned by M1
│   ├── namespace.yaml
│   ├── ingress.yaml
│   ├── postgres/
│   │   ├── postgres-pvc.yaml
│   │   ├── postgres-deployment.yaml
│   │   └── postgres-secret.yaml
│   └── app/
│       ├── configmap.yaml
│       ├── app-secret.yaml
│       ├── frontend-deployment.yaml
│       ├── bff-deployment.yaml
│       ├── salary-submission-deployment.yaml
│       ├── identity-deployment.yaml
│       ├── vote-deployment.yaml
│       ├── search-deployment.yaml
│       └── stats-deployment.yaml
└── services/
    ├── frontend/                        ← M5
    ├── bff/                             ← M4
    ├── salary-submission/               ← M2
    ├── identity/                        ← M3
    ├── vote/                            ← M4
    ├── search/                          ← M5
    └── stats/                           ← M2
```

---

## 👥 Member Responsibilities

| Member | Branch | Services | DB Schema |
|--------|--------|----------|-----------|
| M1 | `feature/m1-infra-setup` | K8s manifests, AKS cluster, ACR, PostgreSQL pod, Ingress | Assembles `init.sql` from all schema files |
| M2 | `feature/m2-salary-service` | `salary-submission` (Java), `stats` (Java) | Writes `db/salary-schema.sql` |
| M3 | `feature/m3-identity-service` | `identity` (Java) | Writes `db/identity-schema.sql` |
| M4 | `feature/m4-bff-vote` | `bff` (Node.js), `vote` (Node.js) | Writes `db/community-schema.sql` |
| M5 | `feature/m5-frontend-search` | `frontend` (React), `search` (Node.js) | No schema (read-only queries) |

---

## 🛠 Prerequisites

Install these on your local machine before starting:

```bash
# Check versions
docker --version          # Docker 24+
kubectl version --client  # kubectl 1.28+
az --version              # Azure CLI 2.50+
java --version            # Java 17+
node --version            # Node.js 20+
mvn --version             # Maven 3.8+ (for Java services)
```

---

## 💻 Local Development Setup

Each member can run their service locally against a local PostgreSQL instance.

### 1. Start PostgreSQL locally (Docker)

```bash
docker run -d \
  --name local-postgres \
  -e POSTGRES_USER=salaryapp \
  -e POSTGRES_PASSWORD=SuperSecret123! \
  -e POSTGRES_DB=salarydb \
  -p 5432:5432 \
  postgres:15
```

### 2. Apply the database schemas

```bash
psql -h localhost -U salaryapp -d salarydb -f db/init.sql
```

### 3. Copy the example env file and fill in values

```bash
# For Node.js services (bff, vote, search)
cp services/bff/.env.example services/bff/.env

# For Java services, values go in application.properties
# (already reads from environment — just export the vars)
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=salarydb
export DB_USER=salaryapp
export DB_PASSWORD=SuperSecret123!
export JWT_SECRET=AtLeast32CharLongSecretKeyForJWT!
```

### 4. Run your service locally

```bash
# Node.js services
cd services/bff
npm install
node server.js

# Java services
cd services/identity
./mvnw spring-boot:run

# React frontend
cd services/frontend
npm install
npm run dev
```

---

## 🐳 Build & Push Docker Images

> **Member 1** coordinates this step once all Dockerfiles are ready.

### 1. Login to Azure Container Registry

```bash
az acr login --name techsalaryacr
```

### 2. Build and push all images

```bash
# Run from the root of the repository
for svc in frontend bff salary-submission identity vote search stats; do
  docker build -t techsalaryacr.azurecr.io/$svc:latest services/$svc/
  docker push techsalaryacr.azurecr.io/$svc:latest
  echo "✅ $svc pushed"
done
```

### 3. Verify images in ACR

```bash
az acr repository list --name techsalaryacr --output table
```

---

## ☸️ Deploy to Kubernetes

> Run all commands from the root of the repository.

### 1. Create the AKS cluster (one-time, M1 only)

```bash
az group create --name techsalary-rg --location eastus

az aks create \
  --resource-group techsalary-rg \
  --name techsalary-cluster \
  --node-count 1 \
  --node-vm-size Standard_DS2_v2 \
  --generate-ssh-keys

az aks get-credentials --resource-group techsalary-rg --name techsalary-cluster

# Attach ACR so AKS can pull images
az aks update \
  -n techsalary-cluster \
  -g techsalary-rg \
  --attach-acr techsalaryacr

kubectl get nodes   # should show 1 node Ready
```

### 2. Install NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Wait for external IP (takes ~2 minutes)
kubectl get svc -n ingress-nginx --watch
```

### 3. Apply all manifests

```bash
# Namespaces first
kubectl apply -f k8s/namespace.yaml

# PostgreSQL in data namespace
kubectl apply -f k8s/postgres/

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n data --timeout=120s

# ConfigMap and Secrets
kubectl apply -f k8s/app/configmap.yaml
kubectl apply -f k8s/app/app-secret.yaml

# All microservices
kubectl apply -f k8s/app/

# Ingress
kubectl apply -f k8s/ingress.yaml
```

### 4. Verify everything is running

```bash
kubectl get pods -n app    # all services should be Running
kubectl get pods -n data   # postgres should be Running
kubectl get ingress -n app # should show an external IP
```

---

## 🗄️ Initialize the Database

Run this **after** PostgreSQL pod is Running and **before** starting the other services.

> M1 assembles `db/init.sql` by combining the 3 schema files in this order:
> 1. `db/identity-schema.sql` (from M3)
> 2. `db/salary-schema.sql` (from M2)
> 3. `db/community-schema.sql` (from M4)

```bash
# Copy init.sql into the running PostgreSQL pod
kubectl cp db/init.sql \
  data/$(kubectl get pod -n data -l app=postgres -o jsonpath='{.items[0].metadata.name}'):/init.sql

# Execute the SQL
kubectl exec -n data deployment/postgres -- \
  psql -U salaryapp -d salarydb -f /init.sql

# Verify schemas were created
kubectl exec -n data deployment/postgres -- \
  psql -U salaryapp -d salarydb -c "\dn"
# Should list: identity, salary, community
```

---

## 🧪 Testing the Full Workflow

Run these in order to prove the system works end-to-end. Save screenshots at each step for the report.

### 1. Submit a salary (no login needed)

```bash
curl -X POST http://<EXTERNAL-IP>/api/submissions \
  -H "Content-Type: application/json" \
  -d '{
    "jobTitle": "Software Engineer",
    "company": "WSO2",
    "country": "Sri Lanka",
    "experienceLevel": "Mid",
    "salaryLkr": 250000,
    "anonymize": true
  }'
# ✅ Expect: 201 with id and status="PENDING"
```

### 2. Verify PENDING in database

```bash
kubectl exec -n data deployment/postgres -- \
  psql -U salaryapp -d salarydb \
  -c "SELECT id, job_title, status FROM salary.submissions;"
# ✅ Expect: status = PENDING
```

### 3. Sign up a user

```bash
curl -X POST http://<EXTERNAL-IP>/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{ "email": "user1@test.com", "password": "Test1234!" }'
# ✅ Expect: 200 with userId
```

### 4. Login and get a token

```bash
curl -X POST http://<EXTERNAL-IP>/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{ "email": "user1@test.com", "password": "Test1234!" }'
# ✅ Expect: { token: "eyJ...", userId: "..." }
# Save the token for the next step
TOKEN="eyJ..."
SUBMISSION_ID="<id-from-step-1>"
```

### 5. Vote 3 times (use 3 different accounts to reach threshold)

```bash
# Repeat steps 3-4 to create user2 and user3, then vote with each
curl -X POST http://<EXTERNAL-IP>/api/votes \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ "submissionId": "'$SUBMISSION_ID'", "voteType": "UP" }'
# ✅ Expect: { message: "Vote recorded" }
```

### 6. Verify APPROVED in database

```bash
kubectl exec -n data deployment/postgres -- \
  psql -U salaryapp -d salarydb \
  -c "SELECT id, job_title, status, upvotes FROM salary.submissions;"
# ✅ Expect: status = APPROVED after 3rd upvote
```

### 7. Search returns the approved salary

```bash
curl "http://<EXTERNAL-IP>/api/search?role=Software+Engineer"
# ✅ Expect: JSON array containing the approved submission
# anonymize=true → company shows as [Anonymous Company]
```

### 8. Stats reflect the approved salary

```bash
curl "http://<EXTERNAL-IP>/api/stats?role=Software+Engineer"
# ✅ Expect: { average: 250000, median: 250000, p75: 250000, total: 1 }
```

---

## 🔐 Environment Variables

> **Never hardcode these in source code.** All services read from environment variables injected by Kubernetes ConfigMaps and Secrets.

| Variable | Where | Description |
|----------|-------|-------------|
| `DB_HOST` | ConfigMap | `postgres-service.data.svc.cluster.local` |
| `DB_PORT` | ConfigMap | `5432` |
| `DB_NAME` | ConfigMap | `salarydb` |
| `IDENTITY_URL` | ConfigMap | `http://identity-service:8082` |
| `SALARY_URL` | ConfigMap | `http://salary-submission-service:8081` |
| `VOTE_URL` | ConfigMap | `http://vote-service:8083` |
| `SEARCH_URL` | ConfigMap | `http://search-service:8084` |
| `STATS_URL` | ConfigMap | `http://stats-service:8085` |
| `DB_USER` | Secret | `salaryapp` |
| `DB_PASSWORD` | Secret | Set in `postgres-secret.yaml` |
| `JWT_SECRET` | Secret | Min 32 characters — set in `app-secret.yaml` |

---

## ⚠️ Common Mistakes to Avoid

| ❌ Wrong | ✅ Correct |
|---------|----------|
| Storing email in `salary.submissions` | Only store job data, no PII |
| Storing plain text passwords | Always use BCrypt hash |
| Hardcoding DB password in source code | Read from `${DB_PASSWORD}` env var |
| Committing `.env` files | Add `.env` to `.gitignore` |
| Using LoadBalancer for internal services | Use ClusterIP — only Ingress is public |
| Connecting to `localhost:5432` in K8s | Use `postgres-service.data.svc.cluster.local` |
| Committing directly to `stg` or `prod` | Always use a feature branch + PR |

---

## 📞 Team Contacts

| Member | Role | Branch |
|--------|------|--------|
| Member 1 | Infra / DevOps | `feature/m1-infra-setup` |
| Member 2 | Salary + Stats | `feature/m2-salary-service` |
| Member 3 | Identity | `feature/m3-identity-service` |
| Member 4 | BFF + Vote | `feature/m4-bff-vote` |
| Member 5 | Frontend + Search | `feature/m5-frontend-search` |

---

*University of Westminster — 7BUIS027C.2 Cloud Computing Applications 2026*