# Member 4 Assignment – BFF + Vote Service
## 7BUIS027C – Cloud Computing Applications 2026

---

# 🎯 Your Role in the Project

You are responsible for:

1. ✅ BFF Service (Node.js + Express)
2. ✅ Vote Service (Node.js + Express)
3. ✅ Writing the `community` database schema SQL
4. ✅ Enforcing authentication for voting
5. ✅ Contributing to end-to-end testing evidence

You directly contribute to:

- 20 Marks – Service implementation
- 10 Marks – Security enforcement
- Part of 30 Marks – Kubernetes deployment
- 10 Marks – Evidence collection

---

# 🗄 Database Responsibility

You MUST write SQL for:

Schema: `community`

Table: `votes`

---

## Required SQL (submit to Member 1)

```sql
CREATE SCHEMA IF NOT EXISTS community;

CREATE TABLE community.votes (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 submission_id UUID REFERENCES salary.submissions(id) ON DELETE CASCADE,
 user_id UUID NOT NULL,
 vote_type VARCHAR(10) NOT NULL CHECK (vote_type IN ('UP','DOWN')),
 voted_at TIMESTAMP DEFAULT NOW(),
 UNIQUE(submission_id, user_id)
);


# 7BUIS027C – Cloud Computing Applications 2026
# Tech Salary Transparency Platform
## Full Member Responsibility Breakdown

---

# 👥 GROUP STRUCTURE (5 MEMBERS)

PostgreSQL is ONE shared instance  
But THREE logical schemas  

Each schema is owned by a specific member.  
Member 1 deploys the DB but DOES NOT write schema tables.

---

# 🟢 MEMBER 1 – Infrastructure & DevOps

## 🎯 Responsibility
Cloud deployment, Kubernetes setup, database hosting, integration.

## 🛠 Owns
- Azure AKS single-node cluster
- Azure Container Registry (ACR)
- Kubernetes Namespaces (app + data)
- PostgreSQL Deployment
- PersistentVolumeClaim (PVC)
- DB Secret
- ConfigMap & App Secret
- Ingress configuration
- Final integration
- README reproducibility steps

## ❌ Does NOT Own
- Any schema SQL
- Any business logic

## 🧠 Key Tasks
- Create AKS cluster
- Create namespaces
- Deploy PostgreSQL in `data` namespace
- Combine schema SQL from Members 2,3,4 into `init.sql`
- Apply DB schema
- Build & push Docker images
- Apply all manifests
- Ensure pods are Running
- Test ingress routing

## 🎓 Marks Contribution
- 30 Marks (Kubernetes)
- 5 Marks (README / reproducibility)
- Evidence support

---

# 🟢 MEMBER 2 – Salary Submission + Stats

## 🎯 Responsibility
Salary core logic + statistics engine

## 🗄 Owns Schema
`salaries` schema

### Table
salary.submissions

## 🛠 Builds
1. Salary-Submission Service (Spring Boot)
2. Stats Service (Spring Boot)

---

## 📌 Salary Service Requirements

POST /submissions  
- No login required
- Status always = PENDING
- No email accepted
- anonymize flag supported

PATCH /submissions/{id}/status  
- Internal update only

---

## 📌 Stats Service Requirements

GET /stats  
Must calculate:

- Average salary
- Median salary (PERCENTILE_CONT 0.5)
- 75th percentile
- Count of APPROVED records only

Must filter only WHERE status = 'APPROVED'

---

## 🔐 Privacy Rules
- NO email column
- NO user_id column
- Salary table must not link to identity table

---

## 🎓 Marks Contribution
- 20 Marks (Service implementation)
- 15 Marks (Database correctness)
- Evidence Step 1 & 8

---

# 🟢 MEMBER 3 – Identity Service

## 🎯 Responsibility
Authentication + JWT + password security

## 🗄 Owns Schema
identity schema

### Tables
identity.users  
identity.refresh_tokens  

---

## 🛠 Builds
Identity Service (Spring Boot)

---

## 📌 Required Endpoints

POST /auth/signup  
- Hash password using BCrypt  
- Store password_hash only  

POST /auth/login  
- Validate password  
- Generate JWT  
- JWT expiry = 24 hours  
- JWT contains ONLY userId  

GET /auth/validate  
- Validate token  
- Return userId  
- 401 if invalid  

---

## 🔐 Security Rules
- Passwords NEVER plain text
- JWT must NOT contain email
- Only userId inside token

---

## 🎓 Marks Contribution
- 20 Marks (Service)
- 10 Marks (Security)
- Evidence Step 3 & 4

---

# 🟢 MEMBER 4 – BFF + Vote Service

## 🎯 Responsibility
Single entry point + voting logic + auth enforcement

## 🗄 Owns Schema
community schema

### Table
community.votes

---

## 🛠 Builds
1. BFF Service (Node.js + Express)
2. Vote Service (Node.js + Express)

---

# 📌 BFF Responsibilities

- Single public entry point
- Forward requests to internal services
- Enforce authentication for voting
- Attach userId from JWT
- Prevent direct internal service exposure

---

## Public Routes
- POST /auth/signup
- POST /auth/login
- POST /submissions
- GET /search
- GET /stats

## Protected Route
- POST /votes (requires JWT)

If no token → 401  
If invalid token → 401  

---

# 📌 Vote Service Logic

POST /votes  

Steps:
1. Insert vote
2. Update upvotes/downvotes counter
3. If (upvotes - downvotes >= 3)
   → status = APPROVED

Approval threshold = 3 net upvotes

---

## 🔐 Security Rules
- userId only from BFF
- UNIQUE constraint prevents double voting
- Vote service must NOT be public
- Only accessible via BFF

---

## 🎓 Marks Contribution
- 20 Marks (Service)
- 10 Marks (Security enforcement)
- Evidence Step 5

---

# 🟢 MEMBER 5 – Frontend + Search + Report

## 🎯 Responsibility
User interface + search + documentation

## 🛠 Builds
1. React Frontend
2. Search Service (Node.js)
3. Final PDF report

---

# 📌 Search Service Rules

GET /search  

Must:
- Return only status='APPROVED'
- Support filters (role, company, level, country)
- Apply anonymize flag
  - If anonymize = true → show "[Anonymous Company]"

---

# 📌 Frontend Pages

- /
- /submit
- /stats
- /login
- /signup
- /salaries/:id

All API calls must go through BFF only.

---

## 📌 Report Must Include

- System Goal explanation
- Architecture diagram
- Workflow explanation
- Privacy explanation
- Evidence screenshots
- References (Harvard style)

---

## 🎓 Marks Contribution
- 10 Marks (Report)
- 10 Marks (Evidence)
- Service contribution

---

# 📸 EVIDENCE CHECKLIST (ALL MEMBERS)

1. Submit salary → PENDING
2. DB shows PENDING
3. Signup
4. Login → JWT
5. Vote 3 times
6. DB shows APPROVED
7. Search returns result
8. Stats updated

All members must help collect screenshots.

---

# 🧠 FINAL RULES

- ONE PostgreSQL pod
- THREE schemas
- Only BFF publicly exposed
- No email in salary table
- Login required ONLY for voting
- All services containerized
- Deploy to Azure AKS

---

# 🏁 FINAL GOAL

Deliver a fully working:

submission → voting → approval → search → stats

Cloud-native microservices system on Kubernetes.

