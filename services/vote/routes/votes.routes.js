const express = require('express');
const router = express.Router();
const votesController = require('../controllers/votes.controller');

/**
 * @route   POST /votes
 * @desc    Create a new vote (triggers auto-approval if threshold met)
 * @access  Internal (called via BFF with user_id from JWT)
 */
router.post('/', votesController.createVote);

/**
 * @route   GET /votes/:submission_id/counts
 * @desc    Get vote counts for a submission
 * @access  Public
 */
router.get('/:submission_id/counts', votesController.getVoteCounts);

/**
 * @route   GET /votes/:submission_id/user/:user_id
 * @desc    Get user's vote for a specific submission
 * @access  Internal
 */
router.get('/:submission_id/user/:user_id', votesController.getUserVote);

module.exports = router;
