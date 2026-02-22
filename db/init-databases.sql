-- Initialize databases for each microservice
-- This script runs automatically when PostgreSQL container starts

-- Create database for Identity Service
CREATE DATABASE identity_db;

-- Create database for Salary Submission Service
CREATE DATABASE salary_submission_db;

-- Create database for Vote Service
CREATE DATABASE vote_db;

-- Create database for Search Service
CREATE DATABASE search_db;

-- Create test databases
CREATE DATABASE identity_db_test;
CREATE DATABASE salary_submission_db_test;
CREATE DATABASE vote_db_test;
CREATE DATABASE search_db_test;

-- Grant privileges (optional - for more restricted access)
-- CREATE USER identity_user WITH PASSWORD 'identity_pass';
-- GRANT ALL PRIVILEGES ON DATABASE identity_db TO identity_user;

-- CREATE USER salary_user WITH PASSWORD 'salary_pass';
-- GRANT ALL PRIVILEGES ON DATABASE salary_submission_db TO salary_user;

-- CREATE USER vote_user WITH PASSWORD 'vote_pass';
-- GRANT ALL PRIVILEGES ON DATABASE vote_db TO vote_user;

-- CREATE USER search_user WITH PASSWORD 'search_pass';
-- GRANT ALL PRIVILEGES ON DATABASE search_db TO search_user;

-- Print confirmation
\echo 'All databases created successfully!'
\echo 'Available databases:'
\l
