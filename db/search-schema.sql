-- Search Service Database Schema
-- Database: search_db

-- Connect to the database
\c search_db;

-- Create search_index table (denormalized for fast searching)
CREATE TABLE IF NOT EXISTS search_index (
    id BIGSERIAL PRIMARY KEY,
    submission_id BIGINT UNIQUE NOT NULL,
    company VARCHAR(100) NOT NULL,
    job_title VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    country VARCHAR(50),
    city VARCHAR(50),
    years_of_experience INTEGER,
    base_salary DECIMAL(12,2),
    bonus DECIMAL(12,2),
    stock_options DECIMAL(12,2),
    total_compensation DECIMAL(12,2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'USD',
    employment_type VARCHAR(20),
    vote_count INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'approved',
    created_at TIMESTAMP,
    indexed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    search_vector tsvector  -- Full-text search column
);

-- Create full-text search index
CREATE INDEX idx_search_vector ON search_index USING gin(search_vector);

-- Create regular indexes for filtering
CREATE INDEX idx_search_company ON search_index(company);
CREATE INDEX idx_search_job_title ON search_index(job_title);
CREATE INDEX idx_search_location ON search_index(location);
CREATE INDEX idx_search_total_comp ON search_index(total_compensation);
CREATE INDEX idx_search_experience ON search_index(years_of_experience);
CREATE INDEX idx_search_status ON search_index(status);
CREATE INDEX idx_search_created_at ON search_index(created_at DESC);

-- Composite index for common queries
CREATE INDEX idx_search_company_title ON search_index(company, job_title);

-- Create function to update search_vector
CREATE OR REPLACE FUNCTION update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector = 
        setweight(to_tsvector('english', COALESCE(NEW.company, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.job_title, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.location, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.country, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.city, '')), 'C');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-update search_vector
CREATE TRIGGER update_search_vector_trigger
    BEFORE INSERT OR UPDATE ON search_index
    FOR EACH ROW
    EXECUTE FUNCTION update_search_vector();

-- Create materialized view for statistics
CREATE MATERIALIZED VIEW IF NOT EXISTS salary_statistics AS
SELECT 
    company,
    job_title,
    COUNT(*) as submission_count,
    AVG(total_compensation) as avg_compensation,
    MIN(total_compensation) as min_compensation,
    MAX(total_compensation) as max_compensation,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_compensation) as median_compensation,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_compensation) as percentile_25,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_compensation) as percentile_75,
    MAX(created_at) as last_updated
FROM search_index
WHERE status = 'approved'
GROUP BY company, job_title
HAVING COUNT(*) >= 3;  -- Only show stats with at least 3 submissions

CREATE INDEX idx_salary_stats_company ON salary_statistics(company);
CREATE INDEX idx_salary_stats_job_title ON salary_statistics(job_title);

-- Create view for popular companies
CREATE OR REPLACE VIEW popular_companies AS
SELECT 
    company,
    COUNT(*) as submission_count,
    AVG(total_compensation) as avg_compensation
FROM search_index
WHERE status = 'approved'
GROUP BY company
ORDER BY submission_count DESC
LIMIT 50;

-- Create view for popular job titles
CREATE OR REPLACE VIEW popular_job_titles AS
SELECT 
    job_title,
    COUNT(*) as submission_count,
    AVG(total_compensation) as avg_compensation
FROM search_index
WHERE status = 'approved'
GROUP BY job_title
ORDER BY submission_count DESC
LIMIT 50;

-- Display created tables and views
\dt
\dm
\dv
