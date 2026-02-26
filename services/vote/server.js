const express = require('express');
const cors = require('cors');
require('dotenv').config();

const votesRoutes = require('./routes/votes.routes');
const { healthCheck } = require('./controllers/votes.controller');
const { pool } = require('./db/database');

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3005;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Health check endpoint
app.get('/health', healthCheck);

// API Routes
app.use('/votes', votesRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    service: 'Vote Service',
    version: '1.0.0',
    description: 'Handles voting logic with auto-approval workflow',
    endpoints: {
      health: 'GET /health',
      createVote: 'POST /votes',
      getVoteCounts: 'GET /votes/:submission_id/counts',
      getUserVote: 'GET /votes/:submission_id/user/:user_id',
    },
    status: 'running',
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found',
    path: req.path,
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined,
  });
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM signal received: closing HTTP server');
  await pool.end();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT signal received: closing HTTP server');
  await pool.end();
  process.exit(0);
});

// Start server
app.listen(PORT, () => {
  console.log('='.repeat(50));
  console.log('Vote Service Started');
  console.log('='.repeat(50));
  console.log(`Server running on port: ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Database: ${process.env.DB_NAME || 'vote_db'}`);
  console.log(`Approval Threshold: ${process.env.APPROVAL_THRESHOLD || 3} net upvotes`);
  console.log('='.repeat(50));
});

module.exports = app;
