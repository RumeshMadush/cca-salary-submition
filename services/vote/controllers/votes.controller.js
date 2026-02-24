const { query, getClient } = require('../db/database');
const axios = require('axios');

// Environment variables
const SALARY_SERVICE_URL = process.env.SALARY_SERVICE_URL || 'http://localhost:8081';
const APPROVAL_THRESHOLD = parseInt(process.env.APPROVAL_THRESHOLD) || 3;

/**
 * Create a new vote and check for auto-approval
 * POST /votes
 */
const createVote = async (req, res) => {
  const { submission_id, vote_type, user_id } = req.body;

  // Validation
  if (!submission_id || !vote_type || !user_id) {
    return res.status(400).json({
      success: false,
      message: 'Missing required fields: submission_id, vote_type, user_id',
    });
  }

  // Validate vote_type
  if (!['upvote', 'downvote', 'UP', 'DOWN'].includes(vote_type)) {
    return res.status(400).json({
      success: false,
      message: 'vote_type must be either UP/DOWN or upvote/downvote',
    });
  }

  // Normalize vote_type to lowercase for database
  const normalizedVoteType = vote_type.toLowerCase() === 'up' ? 'upvote' : 
                             vote_type.toLowerCase() === 'down' ? 'downvote' :
                             vote_type.toLowerCase();

  const client = await getClient();

  try {
    await client.query('BEGIN');

    // Insert vote (UNIQUE constraint prevents duplicate votes from same user)
    const insertVoteQuery = `
      INSERT INTO votes (submission_id, user_id, vote_type)
      VALUES ($1, $2, $3)
      RETURNING id, submission_id, user_id, vote_type, created_at
    `;
    
    const voteResult = await client.query(insertVoteQuery, [
      submission_id,
      user_id,
      normalizedVoteType,
    ]);

    const vote = voteResult.rows[0];
    console.log('Vote created:', vote);

    // Count upvotes and downvotes for this submission
    const countQuery = `
      SELECT 
        COUNT(*) FILTER (WHERE vote_type = 'upvote') as upvotes,
        COUNT(*) FILTER (WHERE vote_type = 'downvote') as downvotes
      FROM votes
      WHERE submission_id = $1
    `;

    const countResult = await client.query(countQuery, [submission_id]);
    const { upvotes, downvotes } = countResult.rows[0];
    
    const upvotesCount = parseInt(upvotes) || 0;
    const downvotesCount = parseInt(downvotes) || 0;
    const netVotes = upvotesCount - downvotesCount;

    console.log(`Vote counts for submission ${submission_id}:`, {
      upvotes: upvotesCount,
      downvotes: downvotesCount,
      netVotes,
      threshold: APPROVAL_THRESHOLD,
    });

    // Check if auto-approval threshold is met
    let approvalTriggered = false;
    if (netVotes >= APPROVAL_THRESHOLD) {
      console.log(`Auto-approval threshold met! Updating submission status to APPROVED...`);
      
      try {
        // Call Salary Submission Service to update status
        const salaryServiceResponse = await axios.patch(
          `${SALARY_SERVICE_URL}/submissions/${submission_id}/status`,
          { status: 'APPROVED' },
          {
            headers: { 'Content-Type': 'application/json' },
            timeout: 5000,
          }
        );

        if (salaryServiceResponse.status === 200) {
          approvalTriggered = true;
          console.log(`Submission ${submission_id} marked as APPROVED`);
        }
      } catch (salaryError) {
        console.error('Error calling Salary Service:', salaryError.message);
        // Don't fail the vote if approval update fails - can be retried
        // But log it for monitoring
      }
    }

    await client.query('COMMIT');

    return res.status(201).json({
      success: true,
      message: 'Vote recorded successfully',
      data: {
        vote,
        voteCounts: {
          upvotes: upvotesCount,
          downvotes: downvotesCount,
          netVotes,
        },
        approvalTriggered,
        status: approvalTriggered ? 'APPROVED' : 'PENDING',
      },
    });
    
  } catch (error) {
    await client.query('ROLLBACK');
    
    // Handle duplicate vote error
    if (error.code === '23505') { // PostgreSQL unique violation error code
      return res.status(409).json({
        success: false,
        message: 'You have already voted on this submission',
      });
    }

    // Handle foreign key violation (submission doesn't exist)
    if (error.code === '23503') {
      return res.status(404).json({
        success: false,
        message: 'Submission not found',
      });
    }

    console.error('Error creating vote:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error while recording vote',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
    
  } finally {
    client.release();
  }
};

/**
 * Get vote counts for a submission
 * GET /votes/:submission_id/counts
 */
const getVoteCounts = async (req, res) => {
  const { submission_id } = req.params;

  try {
    const countQuery = `
      SELECT 
        COUNT(*) FILTER (WHERE vote_type = 'upvote') as upvotes,
        COUNT(*) FILTER (WHERE vote_type = 'downvote') as downvotes,
        COUNT(*) as total_votes
      FROM votes
      WHERE submission_id = $1
    `;

    const result = await query(countQuery, [submission_id]);
    const counts = result.rows[0];

    const upvotes = parseInt(counts.upvotes) || 0;
    const downvotes = parseInt(counts.downvotes) || 0;
    const netVotes = upvotes - downvotes;

    return res.status(200).json({
      success: true,
      data: {
        submission_id,
        upvotes,
        downvotes,
        total_votes: parseInt(counts.total_votes) || 0,
        netVotes,
      },
    });
    
  } catch (error) {
    console.error('Error getting vote counts:', error);
    return res.status(500).json({
      success: false,
      message: 'Error retrieving vote counts',
    });
  }
};

/**
 * Get user's vote for a submission
 * GET /votes/:submission_id/user/:user_id
 */
const getUserVote = async (req, res) => {
  const { submission_id, user_id } = req.params;

  try {
    const voteQuery = `
      SELECT id, submission_id, user_id, vote_type, created_at
      FROM votes
      WHERE submission_id = $1 AND user_id = $2
    `;

    const result = await query(voteQuery, [submission_id, user_id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'No vote found for this user on this submission',
      });
    }

    return res.status(200).json({
      success: true,
      data: result.rows[0],
    });
    
  } catch (error) {
    console.error('Error getting user vote:', error);
    return res.status(500).json({
      success: false,
      message: 'Error retrieving user vote',
    });
  }
};

/**
 * Health check endpoint
 * GET /health
 */
const healthCheck = async (req, res) => {
  try {
    // Test database connection
    await query('SELECT 1');
    
    return res.status(200).json({
      success: true,
      service: 'vote-service',
      status: 'healthy',
      timestamp: new Date().toISOString(),
      database: 'connected',
    });
  } catch (error) {
    return res.status(503).json({
      success: false,
      service: 'vote-service',
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      database: 'disconnected',
      error: error.message,
    });
  }
};

module.exports = {
  createVote,
  getVoteCounts,
  getUserVote,
  healthCheck,
};
