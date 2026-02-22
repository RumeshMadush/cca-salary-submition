-- Salary Submission Service Database Schema
-- Database: salary_submission_db

-- Connect to the database
\c salary_submission_db;

-- Create salary submissions table
CREATE TABLE IF NOT EXISTS salary_submissions (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    company VARCHAR(100) NOT NULL,
    job_title VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    country VARCHAR(50),
    city VARCHAR(50),
    years_of_experience INTEGER CHECK (years_of_experience >= 0),
    base_salary DECIMAL(12,2) NOT NULL CHECK (base_salary >= 0),
    bonus DECIMAL(12,2) DEFAULT 0 CHECK (bonus >= 0),
    stock_options DECIMAL(12,2) DEFAULT 0 CHECK (stock_options >= 0),
    other_compensation DECIMAL(12,2) DEFAULT 0,
    total_compensation DECIMAL(12,2) GENERATED ALWAYS AS 
        (base_salary + bonus + stock_options + other_compensation) STORED,
    currency VARCHAR(10) DEFAULT 'USD',
    employment_type VARCHAR(20) DEFAULT 'Full-time',
    status VARCHAR(20) DEFAULT 'pending' 
        CHECK (status IN ('pending', 'approved', 'rejected')),
    vote_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP
);

-- Create indexes for better query performance
CREATE INDEX idx_submissions_user_id ON salary_submissions(user_id);
CREATE INDEX idx_submissions_company ON salary_submissions(company);
CREATE INDEX idx_submissions_job_title ON salary_submissions(job_title);
CREATE INDEX idx_submissions_location ON salary_submissions(location);
CREATE INDEX idx_submissions_status ON salary_submissions(status);
CREATE INDEX idx_submissions_total_comp ON salary_submissions(total_compensation);
CREATE INDEX idx_submissions_created_at ON salary_submissions(created_at);

-- Composite index for common queries
CREATE INDEX idx_submissions_status_created ON salary_submissions(status, created_at DESC);

-- Full-text search index
CREATE INDEX idx_submissions_search ON salary_submissions 
    USING gin(to_tsvector('english', company || ' ' || job_title || ' ' || location));

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_submissions_updated_at 
    BEFORE UPDATE ON salary_submissions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create trigger to set approved_at when status changes to approved
CREATE OR REPLACE FUNCTION set_approved_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'approved' AND OLD.status != 'approved' THEN
        NEW.approved_at = CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER set_submission_approved_at 
    BEFORE UPDATE ON salary_submissions
    FOR EACH ROW
    EXECUTE FUNCTION set_approved_at();

-- Create view for approved submissions only
CREATE OR REPLACE VIEW approved_submissions AS
SELECT 
    id,
    company,
    job_title,
    location,
    years_of_experience,
    base_salary,
    bonus,
    stock_options,
    total_compensation,
    currency,
    vote_count,
    created_at,
    approved_at
FROM salary_submissions
WHERE status = 'approved';

-- Create materialized view for statistics (optional - for better performance)
CREATE MATERIALIZED VIEW IF NOT EXISTS salary_statistics AS
SELECT 
    company,
    job_title,
    COUNT(*) as submission_count,
    AVG(total_compensation) as avg_compensation,
    MIN(total_compensation) as min_compensation,
    MAX(total_compensation) as max_compensation,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_compensation) as median_compensation
FROM salary_submissions
WHERE status = 'approved'
GROUP BY company, job_title;

-- Sample data (optional - for development/testing)
-- INSERT INTO salary_submissions (user_id, company, job_title, location, years_of_experience, base_salary, bonus, stock_options) VALUES
-- (1, 'Google', 'Senior Software Engineer', 'San Francisco, CA', 5, 150000, 25000, 50000),
-- (1, 'Meta', 'Software Engineer', 'Menlo Park, CA', 3, 130000, 20000, 40000),
-- (2, 'Amazon', 'Principal Engineer', 'Seattle, WA', 8, 180000, 30000, 60000);

-- Display created tables and views
\dt
\dv
