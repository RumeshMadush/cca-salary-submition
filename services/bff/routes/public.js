const express = require('express');
const axios = require('axios');
const router = express.Router();

// Simple in-memory TTL cache
const cache = new Map();
function cacheGet(key) {
  const entry = cache.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expiresAt) { cache.delete(key); return null; }
  return entry.data;
}
function cacheSet(key, data, ttlMs) {
  cache.set(key, { data, expiresAt: Date.now() + ttlMs });
}

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
 * GET /api/submissions
 * List salary submissions (optionally filtered by status/company/country)
 */
router.get('/submissions', async (req, res) => {
  try {
    const queryString = new URLSearchParams(req.query).toString();
    const path = `/api/salary-submissions${queryString ? '?' + queryString : ''}`;
    const response = await proxyRequest(SALARY_URL, path, 'GET');
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
    const response = await proxyRequest(SALARY_URL, '/api/salary-submissions', 'POST', req.body);
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
    const response = await proxyRequest(SALARY_URL, `/api/salary-submissions/${req.params.id}`, 'GET');
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
    const queryString = new URLSearchParams(req.query).toString();
    const cacheKey = `search:${queryString}`;
    const cached = cacheGet(cacheKey);
    if (cached) return res.json(cached);

    const path = `/api/v1/search${queryString ? '?' + queryString : ''}`;
    const response = await proxyRequest(SEARCH_URL, path, 'GET');
    cacheSet(cacheKey, response.data, 60_000); // 1 minute
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
    const cacheKey = `stats:${queryString}`;
    const cached = cacheGet(cacheKey);
    if (cached) return res.json(cached);

    const path = `/api/stats${queryString ? '?' + queryString : ''}`;
    const response = await proxyRequest(STATS_URL, path, 'GET');
    cacheSet(cacheKey, response.data, 5 * 60_000); // 5 minutes
    res.status(response.status).json(response.data);
  } catch (error) {
    res.status(error.status || 500).json(error.data);
  }
});

module.exports = router;
