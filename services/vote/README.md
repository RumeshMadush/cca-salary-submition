# Vote Service

**Member 4 - Sangeeth**  
Tech Salary Platform - 7BUIS027C Cloud Computing Applications 2026

## 📌 Overview

Vote Service handles the voting logic with auto-approval workflow. When users vote on salary submissions, this service:
- Records votes in the database
- Prevents duplicate voting (same user can't vote twice)
- Counts upvotes and downvotes
- Automatically approves submissions when net upvotes ≥ 3
- Calls Salary Service to update submission status

## 🎯 Responsibilities

- ✅ Record user votes (UP/DOWN)
- ✅ Enforce unique constraint (one vote per user per submission)
- ✅ Calculate net votes (upvotes - downvotes)
- ✅ Trigger auto-approval when threshold met (default: 3 net upvotes)
- ✅ Update submission status via Salary Service API call

## 🔗 API Endpoints

### POST /votes
Create a new vote and check for auto-approval.

**Request Body:**
```json
{
  "submission_id": "uuid",
  "vote_type": "UP",
  "user_id": "uuid-from-jwt"
}
```

**Response (201):**
```json
{
  "success": true,
  "message": "Vote recorded successfully",
  "data": {
    "vote": {
      "id": "uuid",
      "submission_id": "uuid",
      "user_id": "uuid",
      "vote_type": "UP",
      "voted_at": "2026-02-24T10:30:00Z"
    },
    "voteCounts": {
      "upvotes": 3,
      "downvotes": 0,
      "netVotes": 3
    },
    "approvalTriggered": true,
    "status": "APPROVED"
  }
}
```

**Error (409 - Duplicate Vote):**
```json
{
  "success": false,
  "message": "You have already voted on this submission"
}
```

### GET /votes/:submission_id/counts
Get vote counts for a submission.

**Response (200):**
```json
{
  "success": true,
  "data": {
    "submission_id": "uuid",
    "upvotes": 5,
    "downvotes": 1,
    "total_votes": 6,
    "netVotes": 4
  }
}
```

### GET /votes/:submission_id/user/:user_id
Check if a user has voted on a submission.

**Response (200):**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "submission_id": "uuid",
    "user_id": "uuid",
    "vote_type": "UP",
    "voted_at": "2026-02-24T10:30:00Z"
  }
}
```

### GET /health
Health check endpoint.

**Response (200):**
```json
{
  "success": true,
  "service": "vote-service",
  "status": "healthy",
  "timestamp": "2026-02-24T10:30:00Z",
  "database": "connected"
}
```

## 🗄️ Database Schema

Uses the `votes` table from `db/vote-schema.sql`:

```sql
CREATE TABLE votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id UUID NOT NULL,
  user_id UUID NOT NULL,
  vote_type VARCHAR(10) NOT NULL CHECK (vote_type IN ('UP','DOWN')),
  voted_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(submission_id, user_id)
);
```

## 🚀 Local Development

### Prerequisites
- Node.js 18+
- PostgreSQL 15+
- Database schema created (`db/vote-schema.sql`)

### Setup

1. **Install dependencies:**
```bash
cd vote-service
npm install
```

2. **Configure environment:**
```bash
cp .env.example .env
# Edit .env with your database credentials
```

3. **Start the service:**
```bash
npm run dev  # Development with nodemon
npm start    # Production
```

4. **Test the service:**
```bash
# Health check
curl http://localhost:3005/health

# Create a vote
curl -X POST http://localhost:3005/votes \
  -H "Content-Type: application/json" \
  -d '{
    "submission_id": "your-submission-uuid",
    "vote_type": "UP",
    "user_id": "your-user-uuid"
  }'
```

## 🐳 Docker

### Build Image
```bash
docker build -t vote-service:1.0 .
```

### Run Container
```bash
docker run -d \
  --name vote-service \
  -p 3005:3005 \
  -e DB_HOST=postgres \
  -e DB_NAME=vote_db \
  -e DB_USER=postgres \
  -e DB_PASSWORD=yourpassword \
  -e SALARY_SERVICE_URL=http://salary-service:8081 \
  vote-service:1.0
```

## ☸️ Kubernetes Deployment

Manifests will be created in `/k8s/vote-service/`:
- `vote-deployment.yaml` - Deployment configuration
- `vote-service.yaml` - ClusterIP Service (internal only)

## 🔐 Security Notes

- ⚠️ Service is **INTERNAL ONLY** - not exposed via Ingress
- ⚠️ Only accessible through BFF Service
- ⚠️ `user_id` must come from BFF (extracted from JWT)
- ⚠️ Never trust `user_id` from frontend directly

## 🧪 Testing Workflow

1. Create a salary submission (via Salary Service)
2. Get submission_id
3. Vote 3 times with different user_ids
4. Check that status changes to APPROVED
5. Verify in database

## 📊 Auto-Approval Logic

```
Net Votes = Upvotes - Downvotes
If Net Votes >= 3:
  → Call PATCH /submissions/{id}/status
  → Set status = 'APPROVED'
```

## 🔗 Service Dependencies

- **PostgreSQL**: Database connection
- **Salary Service**: Updates submission status when approved

## 📝 Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| PORT | Service port | 3005 |
| DB_HOST | PostgreSQL host | localhost |
| DB_PORT | PostgreSQL port | 5432 |
| DB_NAME | Database name | vote_db |
| DB_USER | Database user | postgres |
| DB_PASSWORD | Database password | postgres |
| SALARY_SERVICE_URL | Salary Service URL | http://salary-submission-service:8081 |
| APPROVAL_THRESHOLD | Net upvotes for approval | 3 |
| NODE_ENV | Environment | development |

## 📈 Marks Contribution

- ✅ **20 Marks** - Service implementation
- ✅ **Part of 30 Marks** - Kubernetes deployment
- ✅ **10 Marks** - Evidence collection (voting workflow)

## 🎯 Success Criteria

- [x] POST /votes creates vote
- [x] Duplicate votes rejected (409)
- [x] Vote counts calculated correctly
- [x] Auto-approval triggers at threshold
- [x] Calls Salary Service to update status
- [x] Database transactions prevent race conditions
- [x] Health check endpoint works
- [x] Dockerized and ready for Kubernetes

---

**Next Steps**: Build BFF Service to expose this service with JWT authentication.
