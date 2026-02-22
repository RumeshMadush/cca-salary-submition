-- Vote Service Database Schema
-- Database: vote_db

-- Connect to the database
\c vote_db;

-- Create votes table
CREATE TABLE IF NOT EXISTS votes (
    id BIGSERIAL PRIMARY KEY,
    submission_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    vote_type VARCHAR(10) NOT NULL CHECK (vote_type IN ('upvote', 'downvote')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(submission_id, user_id)  -- Prevent duplicate votes from same user
);

-- Create indexes
CREATE INDEX idx_votes_submission_id ON votes(submission_id);
CREATE INDEX idx_votes_user_id ON votes(user_id);
CREATE INDEX idx_votes_vote_type ON votes(vote_type);

-- Create vote_counts table for aggregated data
CREATE TABLE IF NOT EXISTS vote_counts (
    submission_id BIGINT PRIMARY KEY,
    upvote_count INTEGER DEFAULT 0,
    downvote_count INTEGER DEFAULT 0,
    total_score INTEGER DEFAULT 0,
    is_approved BOOLEAN DEFAULT false,
    approved_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create function to update vote counts
CREATE OR REPLACE FUNCTION update_vote_counts()
RETURNS TRIGGER AS $$
DECLARE
    up_count INTEGER;
    down_count INTEGER;
BEGIN
    -- Calculate current vote counts
    SELECT 
        COUNT(*) FILTER (WHERE vote_type = 'upvote'),
        COUNT(*) FILTER (WHERE vote_type = 'downvote')
    INTO up_count, down_count
    FROM votes
    WHERE submission_id = COALESCE(NEW.submission_id, OLD.submission_id);
    
    -- Insert or update vote_counts
    INSERT INTO vote_counts (submission_id, upvote_count, downvote_count, total_score)
    VALUES (
        COALESCE(NEW.submission_id, OLD.submission_id),
        up_count,
        down_count,
        up_count - down_count
    )
    ON CONFLICT (submission_id) 
    DO UPDATE SET 
        upvote_count = up_count,
        downvote_count = down_count,
        total_score = up_count - down_count,
        updated_at = CURRENT_TIMESTAMP;
    
    -- Auto-approve if upvotes >= 5
    IF up_count >= 5 THEN
        UPDATE vote_counts 
        SET is_approved = true,
            approved_at = CURRENT_TIMESTAMP
        WHERE submission_id = COALESCE(NEW.submission_id, OLD.submission_id)
        AND is_approved = false;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update vote counts
CREATE TRIGGER update_vote_counts_trigger
    AFTER INSERT OR UPDATE OR DELETE ON votes
    FOR EACH ROW
    EXECUTE FUNCTION update_vote_counts();

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for votes table
CREATE TRIGGER update_votes_updated_at 
    BEFORE UPDATE ON votes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Display created tables
\dt
