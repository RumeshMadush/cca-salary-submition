const express = require('express');
const axios = require('axios');
const { authenticateToken } = require('../middleware/auth');
const router = express.Router();

// Service URLs from environment
const VOTE_URL = process.env.VOTE_URL || 'http://localhost:3005';

/**
 * Proxy helper function
 */
const proxyRequest = async (serviceUrl, path, method, data, headers = {}) => {
  try {
    const config = {
      method,
      url: `${serviceUrl}${path}`,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
      timeout: 10000,
    };

    if (data) {
      config.data = data;
    }

    const response = await axios(config);
    return response;
    
  } catch (error) {
    if (error.response) {
      throw {
        status: error.response.status,
        data: error.response.data,
      };
    } else if (error.request) {
      throw {
        status: 503,
        data: {
          success: false,
          message: 'Service temporarily unavailable',
          service: serviceUrl,
        },
      };
    } else {
      throw {
        status: 500,
        data: {
          success: false,
          message: 'Internal gateway error',
          error: error.message,
        },
      };
    }
  }
};

// ========================================
// PROTECTED ROUTES (JWT authentication required)
// ========================================

/**
 * POST /api/votes
 * Forward to Vote Service (requires authentication)
 */
router.post('/votes', authenticateToken, async (req, res) => {
  try {
    // Inject user_id from JWT token
    const voteData = {
      ...req.body,
      user_id: req.user.userId, // Override with authenticated user ID
    };
    
    console.log(`User ${req.user.email} voting on submission ${voteData.submission_id}`);
    
    const response = await proxyRequest(VOTE_URL, '/votes', 'POST', voteData);
    res.status(response.status).json(response.data);
  } catch (error) {
    res.status(error.status || 500).json(error.data);
  }
});

/**
 * GET /api/votes/:submission_id/counts
 * Get vote counts for a submission
 */
router.get('/votes/:submission_id/counts', async (req, res) => {
  try {
    const response = await proxyRequest(VOTE_URL, `/votes/${req.params.submission_id}/counts`, 'GET');
    res.status(response.status).json(response.data);
  } catch (error) {
    res.status(error.status || 500).json(error.data);
  }
});

/**
 * GET /api/votes/:submission_id/user/:user_id
 * Get a specific user's vote on a submission (requires authentication)
 */
router.get('/votes/:submission_id/user/:user_id', authenticateToken, async (req, res) => {
  try {
    // Verify user can only check their own vote
    if (req.user.userId !== parseInt(req.params.user_id)) {
      return res.status(403).json({
        success: false,
        message: 'You can only check your own votes',
      });
    }
    
    const response = await proxyRequest(
      VOTE_URL, 
      `/votes/${req.params.submission_id}/user/${req.params.user_id}`, 
      'GET'
    );
    res.status(response.status).json(response.data);
  } catch (error) {
    res.status(error.status || 500).json(error.data);
  }
});

module.exports = router;
