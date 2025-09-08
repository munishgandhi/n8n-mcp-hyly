-- PostgreSQL Extensions Initialization
-- This script enables commonly used PostgreSQL extensions
-- It runs automatically when the PostgreSQL container starts

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable cryptographic functions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enable case-insensitive text type
CREATE EXTENSION IF NOT EXISTS "citext";

-- Enable additional string functions
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Enable unaccent for text normalization
CREATE EXTENSION IF NOT EXISTS "unaccent";

-- Enable tablefunc for crosstab queries
CREATE EXTENSION IF NOT EXISTS "tablefunc";

-- Enable hstore for key-value storage
CREATE EXTENSION IF NOT EXISTS "hstore";

-- Enable ltree for hierarchical data
CREATE EXTENSION IF NOT EXISTS "ltree";

-- Log successful initialization
DO $$
BEGIN
    RAISE NOTICE 'PostgreSQL extensions initialized successfully';
END $$;