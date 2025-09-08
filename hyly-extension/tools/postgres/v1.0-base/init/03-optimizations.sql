-- n8n-specific PostgreSQL Optimizations
-- Performance tuning for n8n workflow execution and data storage

-- Create indexes for commonly queried n8n tables (after they're created)
-- This script will run after n8n creates its tables

-- Function to create index if table exists
CREATE OR REPLACE FUNCTION create_index_if_not_exists(
    t_name text, 
    i_name text, 
    index_sql text
) RETURNS void AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables WHERE tablename = t_name
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_indexes WHERE indexname = i_name
    ) THEN
        EXECUTE index_sql;
        RAISE NOTICE 'Created index: %', i_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Workflow entity optimizations
SELECT create_index_if_not_exists(
    'workflow_entity',
    'idx_workflow_active',
    'CREATE INDEX idx_workflow_active ON workflow_entity(active) WHERE active = true'
);

SELECT create_index_if_not_exists(
    'workflow_entity',
    'idx_workflow_updated',
    'CREATE INDEX idx_workflow_updated ON workflow_entity(updated_at DESC)'
);

-- Execution entity optimizations
SELECT create_index_if_not_exists(
    'execution_entity',
    'idx_execution_workflow_id',
    'CREATE INDEX idx_execution_workflow_id ON execution_entity(workflow_id, started_at DESC)'
);

SELECT create_index_if_not_exists(
    'execution_entity',
    'idx_execution_status',
    'CREATE INDEX idx_execution_status ON execution_entity(status, started_at DESC)'
);

SELECT create_index_if_not_exists(
    'execution_entity',
    'idx_execution_finished',
    'CREATE INDEX idx_execution_finished ON execution_entity(finished) WHERE finished = false'
);

-- Webhook entity optimizations
SELECT create_index_if_not_exists(
    'webhook_entity',
    'idx_webhook_path_method',
    'CREATE INDEX idx_webhook_path_method ON webhook_entity(webhook_path, method)'
);

-- Clean up the helper function
DROP FUNCTION IF EXISTS create_index_if_not_exists;

-- Update table statistics for better query planning
ANALYZE;