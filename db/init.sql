-- =============================================================================
-- db/init.sql
-- Tech Salary Transparency Platform — Complete Database Initialization
-- ALL data in one database: salarydb
--   identity schema  — users, refresh_tokens
--   salary schema    — salary_submissions
--   public schema    — votes, vote_counts  (vote service uses bare table names)
-- =============================================================================

\c salarydb

-- =============================================================================
-- SCHEMA SETUP
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS identity;
CREATE SCHEMA IF NOT EXISTS salary;
-- votes tables go into public (PostgreSQL default search_path includes public)

-- =============================================================================
-- SCHEMA: identity  (Identity Service)
-- =============================================================================

CREATE TABLE IF NOT EXISTS identity.users (
    id          BIGSERIAL    PRIMARY KEY,
    username    VARCHAR(50)  UNIQUE NOT NULL,
    email       VARCHAR(100) UNIQUE NOT NULL,
    password    VARCHAR(255) NOT NULL,
    first_name  VARCHAR(50),
    last_name   VARCHAR(50),
    is_active   BOOLEAN      DEFAULT TRUE,
    created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    last_login  TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_identity_users_email    ON identity.users (email);
CREATE INDEX IF NOT EXISTS idx_identity_users_username ON identity.users (username);
CREATE INDEX IF NOT EXISTS idx_identity_users_active   ON identity.users (is_active);

CREATE OR REPLACE FUNCTION identity.fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_updated_at ON identity.users;
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON identity.users
    FOR EACH ROW EXECUTE FUNCTION identity.fn_set_updated_at();

CREATE TABLE IF NOT EXISTS identity.refresh_tokens (
    id         BIGSERIAL    PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES identity.users (id) ON DELETE CASCADE,
    token      VARCHAR(500) UNIQUE NOT NULL,
    expires_at TIMESTAMP    NOT NULL,
    created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    revoked    BOOLEAN      DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_identity_refresh_user  ON identity.refresh_tokens (user_id);
CREATE INDEX IF NOT EXISTS idx_identity_refresh_token ON identity.refresh_tokens (token);

-- =============================================================================
-- SCHEMA: salary  (Salary Submission + Stats + Search Services)
-- =============================================================================

CREATE TABLE IF NOT EXISTS salary.salary_submissions (
    id                  BIGSERIAL    PRIMARY KEY,
    company             VARCHAR(100) NOT NULL,
    job_title           VARCHAR(100) NOT NULL,
    location            VARCHAR(100),
    country             VARCHAR(50),
    city                VARCHAR(50),
    years_of_experience INTEGER      CHECK (years_of_experience >= 0),
    experience_level    VARCHAR(20)  CHECK (experience_level IN
                            ('ENTRY', 'JUNIOR', 'MID', 'SENIOR', 'LEAD')),
    base_salary         DECIMAL(12,2) NOT NULL CHECK (base_salary >= 0),
    bonus               DECIMAL(12,2) DEFAULT 0 CHECK (bonus >= 0),
    stock_options       DECIMAL(12,2) DEFAULT 0 CHECK (stock_options >= 0),
    other_compensation  DECIMAL(12,2) DEFAULT 0 CHECK (other_compensation >= 0),
    total_compensation  DECIMAL(12,2) GENERATED ALWAYS AS
                            (base_salary + bonus + stock_options + other_compensation) STORED,
    currency            VARCHAR(10)  DEFAULT 'LKR',
    employment_type     VARCHAR(20)  DEFAULT 'Full-time',
    anonymize           BOOLEAN      DEFAULT FALSE,
    status              VARCHAR(20)  DEFAULT 'PENDING'
                            CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    upvotes             INTEGER      DEFAULT 0,
    downvotes           INTEGER      DEFAULT 0,
    created_at          TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    approved_at         TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_salary_company    ON salary.salary_submissions (company);
CREATE INDEX IF NOT EXISTS idx_salary_job_title  ON salary.salary_submissions (job_title);
CREATE INDEX IF NOT EXISTS idx_salary_country    ON salary.salary_submissions (country);
CREATE INDEX IF NOT EXISTS idx_salary_exp_level  ON salary.salary_submissions (experience_level);
CREATE INDEX IF NOT EXISTS idx_salary_status     ON salary.salary_submissions (status);
CREATE INDEX IF NOT EXISTS idx_salary_created_at ON salary.salary_submissions (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_salary_approved   ON salary.salary_submissions
    (country, experience_level, total_compensation)
    WHERE status = 'APPROVED';

CREATE INDEX IF NOT EXISTS idx_salary_fts ON salary.salary_submissions
    USING gin (to_tsvector('english', company || ' ' || job_title));

CREATE OR REPLACE FUNCTION salary.fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_submissions_updated_at ON salary.salary_submissions;
CREATE TRIGGER trg_submissions_updated_at
    BEFORE UPDATE ON salary.salary_submissions
    FOR EACH ROW EXECUTE FUNCTION salary.fn_set_updated_at();

CREATE OR REPLACE FUNCTION salary.fn_set_approved_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = 'APPROVED' AND OLD.status IS DISTINCT FROM 'APPROVED' THEN
        NEW.approved_at = CURRENT_TIMESTAMP;
    ELSIF NEW.status <> 'APPROVED' THEN
        NEW.approved_at = NULL;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_submissions_approved_at ON salary.salary_submissions;
CREATE TRIGGER trg_submissions_approved_at
    BEFORE UPDATE ON salary.salary_submissions
    FOR EACH ROW EXECUTE FUNCTION salary.fn_set_approved_at();

-- =============================================================================
-- SCHEMA: public  (Vote Service — uses bare table names resolved via search_path)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.votes (
    id            BIGSERIAL   PRIMARY KEY,
    submission_id BIGINT      NOT NULL,
    user_id       BIGINT      NOT NULL,
    vote_type     VARCHAR(10) NOT NULL CHECK (vote_type IN ('upvote', 'downvote')),
    created_at    TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (submission_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_votes_submission ON public.votes (submission_id);
CREATE INDEX IF NOT EXISTS idx_votes_user       ON public.votes (user_id);
CREATE INDEX IF NOT EXISTS idx_votes_type       ON public.votes (vote_type);
CREATE INDEX IF NOT EXISTS idx_votes_created_at ON public.votes (created_at DESC);

CREATE TABLE IF NOT EXISTS public.vote_counts (
    submission_id  BIGINT    PRIMARY KEY,
    upvote_count   INTEGER   DEFAULT 0,
    downvote_count INTEGER   DEFAULT 0,
    net_score      INTEGER   DEFAULT 0,
    is_approved    BOOLEAN   DEFAULT FALSE,
    approved_at    TIMESTAMP,
    updated_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION public.fn_update_vote_counts()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_sid    BIGINT;
    v_up     INTEGER;
    v_down   INTEGER;
    v_net    INTEGER;
BEGIN
    v_sid := COALESCE(NEW.submission_id, OLD.submission_id);

    SELECT
        COUNT(*) FILTER (WHERE vote_type = 'upvote'),
        COUNT(*) FILTER (WHERE vote_type = 'downvote')
    INTO v_up, v_down
    FROM public.votes
    WHERE submission_id = v_sid;

    v_net := v_up - v_down;

    INSERT INTO public.vote_counts
        (submission_id, upvote_count, downvote_count, net_score)
    VALUES
        (v_sid, v_up, v_down, v_net)
    ON CONFLICT (submission_id) DO UPDATE SET
        upvote_count   = v_up,
        downvote_count = v_down,
        net_score      = v_net,
        updated_at     = CURRENT_TIMESTAMP;

    IF v_net >= 3 THEN
        UPDATE public.vote_counts
        SET is_approved = TRUE,
            approved_at = CURRENT_TIMESTAMP
        WHERE submission_id = v_sid
          AND is_approved = FALSE;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_vote_counts ON public.votes;
CREATE TRIGGER trg_vote_counts
    AFTER INSERT OR UPDATE OR DELETE ON public.votes
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_vote_counts();

CREATE OR REPLACE FUNCTION public.fn_set_votes_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_votes_updated_at ON public.votes;
CREATE TRIGGER trg_votes_updated_at
    BEFORE UPDATE ON public.votes
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_votes_updated_at();

-- =============================================================================
-- SAMPLE DATA
-- =============================================================================

INSERT INTO identity.users (username, email, password, first_name, last_name, is_active)
VALUES
  ('admin',       'admin@example.com', '$2a$10$ta5NUawGJuT8u/v05l0/h.wlR281JfFZbCrufP7n2IvD9Ntb/au7G', 'Admin', 'User',    TRUE),
  ('alice_smith', 'alice@example.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36P4/tvQe', 'Alice', 'Smith', TRUE),
  ('bob_johnson', 'bob@example.com',   '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36P4/tvQe', 'Bob',   'Johnson', TRUE),
  ('carol_white', 'carol@example.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36P4/tvQe', 'Carol', 'White',   TRUE)
ON CONFLICT (email) DO NOTHING;

INSERT INTO salary.salary_submissions
  (company, job_title, location, country, city, experience_level, base_salary, bonus, stock_options, currency, employment_type, anonymize, status)
VALUES
  ('Google',       'Software Engineer',      'Mountain View, CA', 'USA',       'Mountain View', 'MID',    200000, 50000,  100000, 'USD', 'Full-time', FALSE, 'APPROVED'),
  ('Meta',         'Senior Backend Engineer','Menlo Park, CA',    'USA',       'Menlo Park',    'SENIOR', 250000, 75000,  150000, 'USD', 'Full-time', FALSE, 'APPROVED'),
  ('Amazon',       'Solutions Architect',    'Seattle, WA',       'USA',       'Seattle',        'SENIOR', 220000, 60000,  120000, 'USD', 'Full-time', FALSE, 'APPROVED'),
  ('Microsoft',    'Software Engineer 2',    'Redmond, WA',       'USA',       'Redmond',        'JUNIOR', 160000, 40000,   80000, 'USD', 'Full-time', FALSE, 'APPROVED'),
  ('Apple',        'Senior Software Engineer','Cupertino, CA',    'USA',       'Cupertino',      'SENIOR', 240000, 70000,  140000, 'USD', 'Full-time', FALSE, 'APPROVED'),
  ('WSO2',         'Senior Software Engineer','Colombo',          'Sri Lanka', 'Colombo',        'SENIOR', 150000, 30000,       0, 'LKR', 'Full-time', FALSE, 'APPROVED'),
  ('Virtusa',      'Technical Lead',          'Colombo',          'Sri Lanka', 'Colombo',        'SENIOR', 140000, 25000,       0, 'LKR', 'Full-time', FALSE, 'APPROVED'),
  ('Synopsys',     'Senior Engineer',         'Mountain View, CA','USA',       'Mountain View',  'SENIOR', 230000, 65000,  130000, 'USD', 'Full-time', FALSE, 'APPROVED'),
  ('TechCorp Lanka','Software Engineer',      'Colombo',          'Sri Lanka', 'Colombo',        'MID',    100000, 20000,       0, 'LKR', 'Full-time', TRUE,  'PENDING'),
  ('Netflix',      'Staff Engineer',          'Los Gatos, CA',    'USA',       'Los Gatos',      'LEAD',   300000,100000,  200000, 'USD', 'Full-time', FALSE, 'APPROVED')
ON CONFLICT DO NOTHING;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

\echo ''
\echo '===== INITIALIZATION COMPLETE (salarydb) ====='
\echo ''
\dn
\echo ''
\dt identity.*
\dt salary.*
\dt public.votes
\dt public.vote_counts
\echo ''
\echo 'All schemas and tables initialized in salarydb.'
