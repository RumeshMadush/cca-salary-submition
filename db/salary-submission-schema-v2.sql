-- ============================================================================
-- Salary Transparency Platform - Submission Service Database Schema
-- ============================================================================
-- Database: salary_submission_db
-- Version: 1.0.0
-- Description: Complete database schema for salary submission microservice
-- ============================================================================

-- Connect to the database
\c salary_submission_db;

-- ============================================================================
-- DROP EXISTING OBJECTS (for clean installation)
-- ============================================================================


-- Drop tables
DROP TABLE IF EXISTS salary_submissions CASCADE;

-- ============================================================================
-- CREATE MAIN TABLE
-- ============================================================================

CREATE TABLE salary_submissions (
    -- Primary Key
    id BIGSERIAL PRIMARY KEY,
    
    -- Company and Job Information
    company VARCHAR(100) NOT NULL,
    job_title VARCHAR(100) NOT NULL,
    
    -- Location Information
    location VARCHAR(100),
    country VARCHAR(50),
    city VARCHAR(50),
    
    -- Experience Information
    years_of_experience INTEGER CHECK (years_of_experience >= 0),
    experience_level VARCHAR(20) CHECK (experience_level IN ('ENTRY', 'JUNIOR', 'MID', 'SENIOR', 'LEAD')),
    
    -- Compensation Information
    base_salary DECIMAL(12,2) NOT NULL CHECK (base_salary >= 0),
    bonus DECIMAL(12,2) DEFAULT 0 CHECK (bonus >= 0),
    stock_options DECIMAL(12,2) DEFAULT 0 CHECK (stock_options >= 0),
    other_compensation DECIMAL(12,2) DEFAULT 0 CHECK (other_compensation >= 0),
    
    -- Calculated Total Compensation (Generated Column)
    total_compensation DECIMAL(12,2) GENERATED ALWAYS AS 
        (base_salary + bonus + stock_options + other_compensation) STORED,
    
    -- Additional Information
    currency VARCHAR(10) DEFAULT 'USD',
    employment_type VARCHAR(20) DEFAULT 'Full-time',
    
    -- Status and Workflow
    status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP
);

-- Add table comments
COMMENT ON TABLE salary_submissions IS 'Stores anonymized salary submission data from users';
COMMENT ON COLUMN salary_submissions.id IS 'Unique identifier for each submission';
COMMENT ON COLUMN salary_submissions.company IS 'Company name (anonymized)';
COMMENT ON COLUMN salary_submissions.job_title IS 'Job title or role';
COMMENT ON COLUMN salary_submissions.location IS 'Detailed location (removed during anonymization)';
COMMENT ON COLUMN salary_submissions.country IS 'Country code (ISO format)';
COMMENT ON COLUMN salary_submissions.city IS 'City name';
COMMENT ON COLUMN salary_submissions.years_of_experience IS 'Years of experience (generalized during anonymization)';
COMMENT ON COLUMN salary_submissions.experience_level IS 'Experience level category (ENTRY, JUNIOR, MID, SENIOR, LEAD)';
COMMENT ON COLUMN salary_submissions.base_salary IS 'Base annual salary (rounded during anonymization)';
COMMENT ON COLUMN salary_submissions.bonus IS 'Annual bonus amount';
COMMENT ON COLUMN salary_submissions.stock_options IS 'Annual stock/equity value';
COMMENT ON COLUMN salary_submissions.other_compensation IS 'Other compensation (benefits, allowances, etc.)';
COMMENT ON COLUMN salary_submissions.total_compensation IS 'Total annual compensation (auto-calculated)';
COMMENT ON COLUMN salary_submissions.currency IS 'Currency code (ISO 4217)';
COMMENT ON COLUMN salary_submissions.employment_type IS 'Type of employment (Full-time, Part-time, Contract, etc.)';
COMMENT ON COLUMN salary_submissions.status IS 'Submission status (PENDING, APPROVED, REJECTED)';
COMMENT ON COLUMN salary_submissions.created_at IS 'Timestamp when submission was created';
COMMENT ON COLUMN salary_submissions.updated_at IS 'Timestamp when submission was last updated';
COMMENT ON COLUMN salary_submissions.approved_at IS 'Timestamp when submission was approved';

-- ============================================================================
-- CREATE INDEXES
-- ============================================================================

-- Single column indexes for filtering
CREATE INDEX idx_submissions_company ON salary_submissions(company);
CREATE INDEX idx_submissions_job_title ON salary_submissions(job_title);
CREATE INDEX idx_submissions_country ON salary_submissions(country);
CREATE INDEX idx_submissions_city ON salary_submissions(city);
CREATE INDEX idx_submissions_experience_level ON salary_submissions(experience_level);
CREATE INDEX idx_submissions_status ON salary_submissions(status);
CREATE INDEX idx_submissions_currency ON salary_submissions(currency);
CREATE INDEX idx_submissions_employment_type ON salary_submissions(employment_type);

-- Index for sorting and time-based queries
CREATE INDEX idx_submissions_created_at ON salary_submissions(created_at DESC);
CREATE INDEX idx_submissions_approved_at ON salary_submissions(approved_at DESC) WHERE approved_at IS NOT NULL;

-- Index for salary range queries
CREATE INDEX idx_submissions_base_salary ON salary_submissions(base_salary);
CREATE INDEX idx_submissions_total_comp ON salary_submissions(total_compensation);

--- not applied yet----
-- Composite indexes for common query patterns
CREATE INDEX idx_submissions_status_created ON salary_submissions(status, created_at DESC);
CREATE INDEX idx_submissions_country_city ON salary_submissions(country, city);
CREATE INDEX idx_submissions_company_job ON salary_submissions(company, job_title);
CREATE INDEX idx_submissions_exp_salary ON salary_submissions(experience_level, base_salary);
CREATE INDEX idx_submissions_country_exp ON salary_submissions(country, experience_level);
CREATE INDEX idx_submissions_status_country ON salary_submissions(status, country);

-- Full-text search index for company and job title
CREATE INDEX idx_submissions_search ON salary_submissions 
    USING gin(to_tsvector('english', company || ' ' || job_title));

-- Partial index for approved submissions (most queried)
CREATE INDEX idx_submissions_approved ON salary_submissions(country, experience_level, total_compensation) 
    WHERE status = 'APPROVED';

-- ============================================================================
-- CREATE FUNCTIONS
-- ============================================================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_updated_at_column() IS 'Automatically updates the updated_at timestamp on row modification';

-- Function to set approved_at when status changes to APPROVED
CREATE OR REPLACE FUNCTION set_approved_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'APPROVED' AND (OLD.status IS NULL OR OLD.status != 'APPROVED') THEN
        NEW.approved_at = CURRENT_TIMESTAMP;
    ELSIF NEW.status != 'APPROVED' THEN
        NEW.approved_at = NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION set_approved_at() IS 'Automatically sets approved_at timestamp when status changes to APPROVED';

-- Function to refresh all materialized views
CREATE OR REPLACE FUNCTION refresh_salary_statistics()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY salary_statistics_by_experience;
    REFRESH MATERIALIZED VIEW CONCURRENTLY salary_statistics_by_role;
    RAISE NOTICE 'Materialized views refreshed successfully';
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION refresh_salary_statistics() IS 'Refreshes all salary statistics materialized views';

-- ============================================================================
-- CREATE TRIGGERS
-- ============================================================================

-- Trigger to automatically update updated_at timestamp
CREATE TRIGGER update_submissions_updated_at
    BEFORE UPDATE ON salary_submissions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger to set approved_at when status changes to APPROVED
CREATE TRIGGER set_submission_approved_at
    BEFORE UPDATE ON salary_submissions
    FOR EACH ROW
    EXECUTE FUNCTION set_approved_at();

-- ============================================================================
-- CREATE VIEWS
-- ============================================================================

-- View for approved submissions only (public data)
CREATE OR REPLACE VIEW approved_submissions AS
SELECT
    id,
    company,
    job_title,
    country,
    city,
    years_of_experience,
    experience_level,
    base_salary,
    bonus,
    stock_options,
    other_compensation,
    total_compensation,
    currency,
    employment_type,
    created_at,
    approved_at
FROM salary_submissions
WHERE status = 'APPROVED'
ORDER BY created_at DESC;

COMMENT ON VIEW approved_submissions IS 'Public view of approved salary submissions (anonymized data)';

-- ============================================================================
-- CREATE MATERIALIZED VIEWS FOR ANALYTICS
-- ============================================================================

-- Materialized view: Salary statistics by experience level and country
CREATE MATERIALIZED VIEW salary_statistics_by_experience AS
SELECT
    experience_level,
    country,
    currency,
    COUNT(*) as submission_count,
    ROUND(AVG(base_salary), 2) as avg_base_salary,
    ROUND(MIN(base_salary), 2) as min_base_salary,
    ROUND(MAX(base_salary), 2) as max_base_salary,
    ROUND(AVG(total_compensation), 2) as avg_total_compensation,
    ROUND(MIN(total_compensation), 2) as min_total_compensation,
    ROUND(MAX(total_compensation), 2) as max_total_compensation,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_compensation), 2) as p25_compensation,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_compensation), 2) as median_compensation,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_compensation), 2) as p75_compensation,
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY total_compensation), 2) as p90_compensation,
    MAX(created_at) as last_updated
FROM salary_submissions
WHERE status = 'APPROVED'
GROUP BY experience_level, country, currency
HAVING COUNT(*) >= 5; -- Minimum 5 submissions for statistical significance

COMMENT ON MATERIALIZED VIEW salary_statistics_by_experience IS 'Aggregated salary statistics by experience level and country';

-- Create indexes on materialized view
CREATE INDEX idx_stats_exp_level ON salary_statistics_by_experience(experience_level);
CREATE INDEX idx_stats_exp_country ON salary_statistics_by_experience(country);
CREATE INDEX idx_stats_exp_currency ON salary_statistics_by_experience(currency);
CREATE INDEX idx_stats_exp_count ON salary_statistics_by_experience(submission_count DESC);

-- Materialized view: Salary statistics by company, job title, and experience level
CREATE MATERIALIZED VIEW salary_statistics_by_role AS
SELECT
    company,
    job_title,
    experience_level,
    country,
    currency,
    COUNT(*) as submission_count,
    ROUND(AVG(base_salary), 2) as avg_base_salary,
    ROUND(MIN(base_salary), 2) as min_base_salary,
    ROUND(MAX(base_salary), 2) as max_base_salary,
    ROUND(AVG(total_compensation), 2) as avg_total_compensation,
    ROUND(MIN(total_compensation), 2) as min_total_compensation,
    ROUND(MAX(total_compensation), 2) as max_total_compensation,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_compensation), 2) as median_compensation,
    MAX(created_at) as last_updated
FROM salary_submissions
WHERE status = 'APPROVED'
GROUP BY company, job_title, experience_level, country, currency
HAVING COUNT(*) >= 3; -- Minimum 3 submissions for privacy protection

COMMENT ON MATERIALIZED VIEW salary_statistics_by_role IS 'Aggregated salary statistics by company, role, and experience level';

-- Create indexes on materialized view
CREATE INDEX idx_stats_role_company ON salary_statistics_by_role(company);
CREATE INDEX idx_stats_role_job ON salary_statistics_by_role(job_title);
CREATE INDEX idx_stats_role_exp ON salary_statistics_by_role(experience_level);
CREATE INDEX idx_stats_role_country ON salary_statistics_by_role(country);
CREATE INDEX idx_stats_role_count ON salary_statistics_by_role(submission_count DESC);

-- ============================================================================
-- INSERT SAMPLE DATA (for development/testing)
-- ============================================================================

-- Sample submissions for testing
INSERT INTO salary_submissions (
    company, job_title, country, city, years_of_experience, experience_level,
    base_salary, bonus, stock_options, other_compensation, currency, employment_type, status
) VALUES
-- US Tech Companies
('Google', 'Software Engineer', 'US', 'Mountain View', 3, 'JUNIOR', 140000, 20000, 40000, 5000, 'USD', 'Full-time', 'APPROVED'),
('Google', 'Senior Software Engineer', 'US', 'Mountain View', 8, 'SENIOR', 180000, 30000, 75000, 10000, 'USD', 'Full-time', 'APPROVED'),
('Google', 'Staff Software Engineer', 'US', 'San Francisco', 12, 'LEAD', 220000, 50000, 125000, 15000, 'USD', 'Full-time', 'APPROVED'),
('Meta', 'Software Engineer', 'US', 'Menlo Park', 3, 'JUNIOR', 130000, 20000, 40000, 5000, 'USD', 'Full-time', 'APPROVED'),
('Meta', 'Senior Software Engineer', 'US', 'Menlo Park', 8, 'SENIOR', 170000, 30000, 70000, 10000, 'USD', 'Full-time', 'APPROVED'),
('Amazon', 'Software Development Engineer', 'US', 'Seattle', 1, 'ENTRY', 110000, 15000, 25000, 5000, 'USD', 'Full-time', 'APPROVED'),
('Amazon', 'SDE II', 'US', 'Seattle', 5, 'MID', 150000, 25000, 50000, 8000, 'USD', 'Full-time', 'APPROVED'),
('Amazon', 'Principal Engineer', 'US', 'Seattle', 12, 'LEAD', 210000, 40000, 100000, 15000, 'USD', 'Full-time', 'APPROVED'),
('Microsoft', 'Software Engineer', 'US', 'Redmond', 3, 'JUNIOR', 125000, 18000, 35000, 5000, 'USD', 'Full-time', 'APPROVED'),
('Microsoft', 'Senior Software Engineer', 'US', 'Redmond', 8, 'SENIOR', 165000, 28000, 65000, 10000, 'USD', 'Full-time', 'APPROVED'),
('Apple', 'Software Engineer', 'US', 'Cupertino', 5, 'MID', 155000, 25000, 55000, 8000, 'USD', 'Full-time', 'APPROVED'),

-- Sri Lanka Tech Companies
('TechCorp Lanka', 'Software Engineer', 'LK', 'Colombo', 3, 'JUNIOR', 1800000, 300000, 0, 0, 'LKR', 'Full-time', 'APPROVED'),
('TechCorp Lanka', 'Senior Software Engineer', 'LK', 'Colombo', 8, 'SENIOR', 2560000, 520000, 0, 0, 'LKR', 'Full-time', 'APPROVED'),
('TechCorp Lanka', 'Lead Engineer', 'LK', 'Colombo', 12, 'LEAD', 3500000, 700000, 0, 100000, 'LKR', 'Full-time', 'APPROVED'),
('WSO2', 'Software Engineer', 'LK', 'Colombo', 5, 'MID', 2200000, 400000, 0, 50000, 'LKR', 'Full-time', 'APPROVED'),
('Virtusa', 'Senior Software Engineer', 'LK', 'Colombo', 8, 'SENIOR', 2400000, 450000, 0, 50000, 'LKR', 'Full-time', 'APPROVED'),

-- Pending submissions
('Netflix', 'Senior Software Engineer', 'US', 'Los Gatos', 8, 'SENIOR', 190000, 35000, 80000, 10000, 'USD', 'Full-time', 'PENDING'),
('Uber', 'Software Engineer', 'US', 'San Francisco', 5, 'MID', 145000, 22000, 45000, 8000, 'USD', 'Full-time', 'PENDING');

-- ============================================================================
-- REFRESH MATERIALIZED VIEWS
-- ============================================================================

REFRESH MATERIALIZED VIEW salary_statistics_by_experience;
REFRESH MATERIALIZED VIEW salary_statistics_by_role;

-- ============================================================================
-- GRANT PERMISSIONS (adjust as needed for your environment)
-- ============================================================================

-- Grant permissions to application user (replace 'app_user' with your actual username)
-- GRANT SELECT, INSERT, UPDATE ON salary_submissions TO app_user;
-- GRANT SELECT ON approved_submissions TO app_user;
-- GRANT SELECT ON salary_statistics_by_experience TO app_user;
-- GRANT SELECT ON salary_statistics_by_role TO app_user;
-- GRANT USAGE, SELECT ON SEQUENCE salary_submissions_id_seq TO app_user;

-- ============================================================================
-- DISPLAY CREATED OBJECTS
-- ============================================================================

-- Display tables
\dt

-- Display views
\dv

-- Display materialized views
\dm

-- Display indexes
\di

-- Display functions
\df

-- Display table structure
\d salary_submissions

-- Display sample data counts
SELECT 
    status,
    COUNT(*) as count,
    COUNT(DISTINCT country) as countries,
    COUNT(DISTINCT experience_level) as experience_levels
FROM salary_submissions
GROUP BY status
ORDER BY status;

-- Display statistics summary
SELECT * FROM salary_statistics_by_experience ORDER BY country, experience_level;

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================

COMMIT;
