const express = require('express');
const axios = require('axios');
const router = express.Router();

// Service URLs from environment
const IDENTITY_URL = process.env.IDENTITY_URL || 'http://localhost:3001';
const SALARY_URL = process.env.SALARY_URL || 'http://localhost:3002';
const SEARCH_URL = process.env.SEARCH_URL || 'http://localhost:3003';
const STATS_URL = process.env.STATS_URL || 'http://localhost:3004';

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
      // Forward the error response from the service
      throw {
        status: error.response.status,
        data: error.response.data,
      };
    } else if (error.request) {
      // Service didn't respond
      throw {
        status: 503,
        data: {
          success: false,
          message: 'Service temporarily unavailable',
          service: serviceUrl,
        },
      };
    } else {
      // Something else went wrong
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
// PUBLIC ROUTES (No authentication needed)
// ========================================

/**
 * POST /api/auth/signup
 * Forward to Identity Service
 */
router.post('/auth/signup', async (req, res) => {
  try {
    const response = await proxyRequest(IDENTITY_URL, '/auth/signup', 'POST', req.body);
    res.status(response.status).json(response.data);
  } catch (error) {
    res.status(error.status || 500).json(error.data);
  }
});

/**
 * POST /api/auth/login
 * Forward to Identity Service
 */
router.post('/auth/login', async (req, res) => {
  try {
    const response = await proxyRequest(IDENTITY_URL, '/auth/login', 'POST', req.body);
    res.status(response.status).json(response.data);
  } catch (error) {
    res.status(error.status || 500).json(error.data);
  }
});

/**
 * POST /api/submissions
 * Forward to Salary Submission Service (public - anonymous submissions allowed)
 */
router.post('/submissions', async (req, res) => {
  try {
    const response = await proxyRequest(SALARY_URL, '/submissions', 'POST', req.body);
    res.status(response.status).json(response.data);
  } catch (error) {
    res.status(error.status || 500).json(error.data);
  }
});

/**
 * GET /api/submissions/:id
 * Forward to Salary Submission Service
 */
router.get('/submissions/:id', async (req, res) => {
  try {
    const response = await proxyRequest(SALARY_URL, `/submissions/${req.params.id}`, 'GET');
    res.status(response.status).json(response.data);
  } catch (error) {
    res.status(error.status || 500).json(error.data);
  }
});

/**
 * GET /api/search
 * Forward to Search Service
 */
router.get('/search', async (req, res) => {
  try {
    // Forward query parameters
    const queryString = new URLSearchParams(req.query).toString();
    const path = `/search${queryString ? '?' + queryString : ''}`;
    const response = await proxyRequest(SEARCH_URL, path, 'GET');
    res.status(response.status).json(response.data);
  } catch (error) {
    res.status(error.status || 500).json(error.data);
  }
});

/**
 * GET /api/stats
 * Forward to Stats Service
 */
router.get('/stats', async (req, res) => {
  try {
    const queryString = new URLSearchParams(req.query).toString();
    const path = `/stats${queryString ? '?' + queryString : ''}`;
    const response = await proxyRequest(STATS_URL, path, 'GET');
    res.status(response.status).json(response.data);
  } catch (error) {
    res.status(error.status || 500).json(error.data);
  }
});

module.exports = router;
