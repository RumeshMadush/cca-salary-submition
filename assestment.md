# 7BUIS027C – Cloud Computing Applications 2026
## Tech Salary Transparency Platform – Microservices + Kubernetes Deployment

---

# 📌 Module Information

Module: 7BUIS027C.2 – Cloud Computing Applications  
University: University of Westminster  
Weighting: 50%  
Submission: PDF Report + Working Kubernetes Deployment + Viva  
Due Date: 16 April 2026  

This project implements a **cloud-native microservices system** deployed on a **single-node Azure Kubernetes cluster**, fulfilling all required learning outcomes.

---

# 🎯 System Goal

Build a **community-driven salary transparency platform for Sri Lanka tech industry**.

Inspired by:
- TechPays (Europe)
- https://techsalary.tldr.lk

The system must allow:

- Anonymous salary submission (NO login required)
- Login required only for community actions (voting)
- Privacy protection via schema separation
- Voting-based approval workflow
- Search only approved salaries
- Statistics based only on approved salaries

---

# 🔁 Required Workflow

The system MUST implement this exact workflow:

1. Salary submission (status = PENDING)
2. User signup
3. User login → receive JWT
4. Vote on submission
5. When net upvotes ≥ 3 → mark as APPROVED
6. Search returns APPROVED records only
7. Stats update using APPROVED salaries only

---

# 🏗 Architecture Overview

System architecture (as per coursework specification):

User → HTTPS  
→ Load Balancer  
→ Kubernetes Ingress  
→ Frontend  
→ BFF (single entry point)  
→ Internal Microservices  

Microservices:

- Frontend (React + Vite)
- BFF Service (Node.js)
- Salary-Submission Service (Spring Boot)
- Identity Service (Spring Boot)
- Vote Service (Node.js)
- Search Service (Node.js)
- Stats Service (Spring Boot)
- PostgreSQL (Single instance, 3 schemas)

---

# 🗄 Database Design (Single PostgreSQL Instance)

ONE PostgreSQL pod  
THREE logical schemas  

## identity schema
- users
- refresh_tokens

## salary schema
- submissions

## community schema
- votes

CRITICAL RULES:

- No email column inside salary.submissions
- Salary table must NOT reference user_id
- Passwords must be hashed (BCrypt)
- Privacy by design

---

# 🔐 Security Requirements

- JWT-based authentication
- Passwords stored as BCrypt hash
- BFF validates JWT before allowing voting
- Only BFF exposed publicly
- Internal services must NOT be exposed
- Secrets stored in Kubernetes Secret
- DB credentials NOT hardcoded
- JWT must contain only userId (NOT email)

---

# 🧱 Microservices Breakdown

## 1️⃣ Frontend (React + Vite)
- Calls ONLY BFF
- Pages:
  - / (Search)
  - /submit
  - /stats
  - /login
  - /signup
  - /salaries/:id

---

## 2️⃣ BFF Service (Node.js + Express)
Single entry point for frontend.

Responsibilities:
- Route requests
- Enforce authentication
- Forward requests to services
- Attach userId from JWT

Protected routes:
- POST /votes

Public routes:
- POST /auth/signup
- POST /auth/login
- POST /submissions
- GET /search
- GET /stats

---

## 3️⃣ Salary Submission Service (Spring Boot)

POST /submissions
- Always store status = PENDING
- No email accepted
- Apply anonymize flag

PATCH /submissions/{id}/status
- Internal use only

---

## 4️⃣ Identity Service (Spring Boot)

POST /auth/signup
POST /auth/login
GET /auth/validate

- BCrypt password hashing
- JWT expiry = 24 hours
- JWT contains only userId

---

## 5️⃣ Vote Service (Node.js)

POST /votes

Logic:
- Insert vote
- Update upvotes/downvotes
- If (upvotes - downvotes >= 3)
  → status = APPROVED

---

## 6️⃣ Search Service (Node.js)

GET /search

Rules:
- Return only status='APPROVED'
- If anonymize = true → hide company name

---

## 7️⃣ Stats Service (Spring Boot)

GET /stats

Calculate:
- Average
- Median (PERCENTILE_CONT 0.5)
- P75 (PERCENTILE_CONT 0.75)
- Total approved count

Only from APPROVED records.

---

# ☁ Kubernetes Requirements (30 Marks)

- Single-node Azure AKS cluster
- Separate namespaces:
  - app
  - data
- Each service:
  - Separate Deployment
  - ClusterIP Service
- PostgreSQL:
  - Deployment
  - PersistentVolumeClaim
  - Secret
- Ingress:
  - Route / → frontend
  - Route /api → BFF
- Use ConfigMaps + Secrets
- Include readinessProbes
- Services must remain stateless

---

# 🐳 Docker Requirements

Each service must include:

- Production Dockerfile
- Multi-stage builds for Java
- Proper exposed ports
- No hardcoded credentials

---

# 📸 Evidence Required (10 Marks)

Must provide screenshots showing:

1. Submit salary → PENDING
2. DB shows PENDING
3. User signup success
4. User login returns JWT
5. Vote 3 times
6. DB shows APPROVED
7. Search returns approved salary
8. Stats updated

---

# 📊 Marking Criteria Alignment

| Requirement | Marks |
|-------------|-------|
| Workflow explanation | 10 |
| Service implementation | 20 |
| Kubernetes deployment | 30 |
| Database schema correctness | 15 |
| Security & privacy | 10 |
| Evidence screenshots | 10 |
| Reproducible manifests & README | 5 |
| TOTAL | 100 |

---

# 🚀 How to Build & Deploy

## 1️⃣ Build Docker Images

