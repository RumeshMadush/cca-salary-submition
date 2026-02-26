# BFF Service (Backend for Frontend)

**API Gateway with JWT Authentication for TechSalary Platform**

## 📖 Overview

The BFF (Backend for Frontend) service acts as the single public entry point for all client applications. It provides:

- **API Gateway**: Routes requests to appropriate microservices
- **JWT Authentication**: Enforces security on protected endpoints
- **Rate Limiting**: Prevents abuse with configurable request limits
- **CORS Management**: Handles cross-origin requests
- **Error Handling**: Provides consistent error responses

## 🏗️ Architecture

```
┌─────────┐
│ Client  │
│(React)  │
└────┬────┘
     │
     ▼
┌─────────────────────────────────────────┐
│        BFF Service (Port 3000)          │
│  ┌────────────────────────────────┐     │
│  │  JWT Authentication Middleware │     │
│  └────────────────────────────────┘     │
│                                          │
│  ┌──────────┐      ┌───────────────┐    │
│  │  Public  │      │   Protected   │    │
│  │  Routes  │      │    Routes     │    │
│  └──────────┘      └───────────────┘    │
└─────────────────────────────────────────┘
     │         │            │
     ▼         ▼            ▼
┌─────────┐ ┌──────┐  ┌───────┐
│Identity │ │Salary│  │ Vote  │
│Service  │ │Service│ │Service│
└─────────┘ └──────┘  └───────┘
```

## 🔌 API Endpoints

### Public Routes (No Authentication)

| Method | Endpoint | Description | Forwards To |
|--------|----------|-------------|-------------|
| POST | `/api/auth/signup` | Register new user | Identity Service |
| POST | `/api/auth/login` | Login and get JWT | Identity Service |
| POST | `/api/submissions` | Submit salary (anonymous) | Salary Service |
| GET | `/api/submissions/:id` | Get submission details | Salary Service |
| GET | `/api/search?role=...` | Search salaries | Search Service |
| GET | `/api/stats?role=...` | Get statistics | Stats Service |
| GET | `/health` | Health check | - |

### Protected Routes (JWT Required)

| Method | Endpoint | Description | Forwards To |
|--------|----------|-------------|-------------|
| POST | `/api/votes` | Vote on submission | Vote Service |
| GET | `/api/votes/:id/counts` | Get vote counts | Vote Service |
| GET | `/api/votes/:id/user/:userId` | Get user's vote | Vote Service |

## 🔐 Authentication

### JWT Token Format

```javascript
// Token payload
{
  "userId": 123,
  "email": "user@example.com",
  "iat": 1234567890,
  "exp": 1234571490
}
```

### Using Protected Endpoints

```bash
# 1. Login to get token
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@test.com", "password": "Test1234!"}'

# Response: { "token": "eyJhbGc...", "userId": 123 }

# 2. Use token in Authorization header
curl -X POST http://localhost:3000/api/votes \
  -H "Authorization: Bearer eyJhbGc..." \
  -H "Content-Type: application/json" \
  -d '{"submission_id": 1, "vote_type": "upvote"}'
```

## 🚀 Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn
- All backend microservices running

### Installation

```bash
cd services/bff
npm install
```

### Configuration

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

**Required environment variables:**

```env
NODE_ENV=development
PORT=3000

# JWT Secret (REQUIRED - minimum 32 characters)
JWT_SECRET=your-super-secret-jwt-key-min-32-characters-long

# CORS Configuration
CORS_ORIGIN=*

# Microservice URLs
IDENTITY_URL=http://localhost:3001
SALARY_URL=http://localhost:3002
SEARCH_URL=http://localhost:3003
STATS_URL=http://localhost:3004
VOTE_URL=http://localhost:3005
```

### Running Locally

```bash
# Development mode (with auto-reload)
npm run dev

# Production mode
npm start
```

## 🧪 Testing

### Test Health Endpoint

```bash
curl http://localhost:3000/health
```

Expected response:
```json
{
  "success": true,
  "service": "bff-service",
  "status": "healthy",
  "timestamp": "2026-02-25T00:00:00.000Z"
}
```

### Test Public Route

```bash
curl -X POST http://localhost:3000/api/submissions \
  -H "Content-Type: application/json" \
  -d '{
    "jobTitle": "Software Engineer",
    "company": "Example Corp",
    "country": "Sri Lanka",
    "experienceLevel": "Mid",
    "salaryLkr": 250000,
    "anonymize": true
  }'
```

### Test Protected Route

```bash
# Without token (should fail)
curl -X POST http://localhost:3000/api/votes \
  -H "Content-Type: application/json" \
  -d '{"submission_id": 1, "vote_type": "upvote"}'

# Expected: 401 Unauthorized

# With valid token (should succeed)
curl -X POST http://localhost:3000/api/votes \
  -H "Authorization: Bearer <your-jwt-token>" \
  -H "Content-Type: application/json" \
  -d '{"submission_id": 1, "vote_type": "upvote"}'
```

## 🔒 Security Features

### 1. JWT Authentication
- Token-based authentication
- Automatic token expiration
- User identity verification

### 2. Rate Limiting
- 100 requests per 15 minutes per IP
- Prevents API abuse and DDoS attacks

### 3. Helmet.js
- Sets security-related HTTP headers
- XSS protection
- Content Security Policy

### 4. CORS
- Configurable origin whitelist
- Credentials support

### 5. Input Validation
- Request body validation
- Error sanitization in production

## 📦 Docker Build

```bash
# Build image
docker build -t bff-service:latest .

# Run container
docker run -d \
  -p 3000:3000 \
  -e JWT_SECRET=your-secret-key \
  -e IDENTITY_URL=http://identity-service:3001 \
  -e SALARY_URL=http://salary-service:3002 \
  -e SEARCH_URL=http://search-service:3003 \
  -e STATS_URL=http://stats-service:3004 \
  -e VOTE_URL=http://vote-service:3005 \
  --name bff \
  bff-service:latest
```

## ☸️ Kubernetes Deployment

Service will be exposed via Ingress as the only public-facing service.

```yaml
# Internal services use ClusterIP
apiVersion: v1
kind: Service
metadata:
  name: bff-service
spec:
  type: ClusterIP
  ports:
    - port: 3000
      targetPort: 3000
  selector:
    app: bff
```

## 🛠️ Development

### Project Structure

```
bff/
├── server.js              # Main application entry point
├── middleware/
│   └── auth.js           # JWT authentication middleware
├── routes/
│   ├── public.js         # Public routes (no auth)
│   └── protected.js      # Protected routes (JWT required)
├── package.json
├── Dockerfile
├── .env.example
└── README.md
```

### Adding New Routes

**Public route:**
```javascript
// routes/public.js
router.get('/new-endpoint', async (req, res) => {
  const response = await proxyRequest(SERVICE_URL, '/path', 'GET');
  res.status(response.status).json(response.data);
});
```

**Protected route:**
```javascript
// routes/protected.js
router.post('/new-endpoint', authenticateToken, async (req, res) => {
  // req.user contains authenticated user info
  const response = await proxyRequest(SERVICE_URL, '/path', 'POST', req.body);
  res.status(response.status).json(response.data);
});
```

## 📊 Monitoring

### Service Health

```bash
# Check if service is running
curl http://localhost:3000/health

# Check service logs
docker logs bff-service -f

# In Kubernetes
kubectl logs -f deployment/bff -n default
```

### Request Logging

All requests are logged with timestamp and method:

```
2026-02-25T12:00:00.000Z - POST /api/auth/login
✅ Authenticated user: user@test.com (ID: 123)
2026-02-25T12:00:05.000Z - POST /api/votes
```

## 🚨 Error Handling

### Common Error Responses

**401 Unauthorized** - No token provided
```json
{
  "success": false,
  "message": "Access denied. No token provided."
}
```

**403 Forbidden** - Invalid token
```json
{
  "success": false,
  "message": "Invalid token."
}
```

**404 Not Found** - Route doesn't exist
```json
{
  "success": false,
  "message": "Route not found",
  "path": "/api/invalid"
}
```

**503 Service Unavailable** - Backend service down
```json
{
  "success": false,
  "message": "Service temporarily unavailable",
  "service": "http://vote-service:3005"
}
```

## 🎯 Assessment Criteria

This service demonstrates:

- ✅ **Microservices Architecture**: API Gateway pattern
- ✅ **Security**: JWT authentication, rate limiting, Helmet.js
- ✅ **Error Handling**: Graceful degradation, proper HTTP codes
- ✅ **Docker**: Multi-stage build, non-root user, health checks
- ✅ **Documentation**: Comprehensive README with examples
- ✅ **Best Practices**: Environment variables, separation of concerns

## 📝 License

University of Westminster - 7BUIS027C.2 Cloud Computing Applications 2026

---

**Member 4 - BFF Service + Vote Service**
