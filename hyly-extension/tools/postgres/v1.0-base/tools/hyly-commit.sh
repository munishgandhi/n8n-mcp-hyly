#!/bin/bash
# Simple workflow: Work directly in PostgreSQL, then commit when ready

ACTION="${1:-export}"

case "$ACTION" in
  export)
    echo "📸 Exporting current Hyly extension state..."
    
    # Export ALL objects from hyly schema using psql
    docker exec hyly-n8n-postgres psql -U n8n -d n8n -t -A -c "
      SELECT 
        '-- Hyly Extension for n8n' || E'\\n' ||
        '-- Exported: ' || NOW() || E'\\n\\n' ||
        'CREATE SCHEMA IF NOT EXISTS hyly;' || E'\\n\\n'
    " > ../deployment/01-hyly.sql
    
    # Export table definition with PRIMARY KEY
    echo "" >> ../deployment/01-hyly.sql
    docker exec hyly-n8n-postgres pg_dump -U n8n -d n8n \
      --schema=hyly \
      --table=hyly.execution_backtrace \
      --no-owner \
      --no-privileges \
      --no-comments \
      --schema-only | \
    sed -n '/^CREATE TABLE/,/^);/p' >> ../deployment/01-hyly.sql
    
    # Add PRIMARY KEY constraint separately if needed
    docker exec hyly-n8n-postgres psql -U n8n -d n8n -t -A -c "
      SELECT 'ALTER TABLE hyly.execution_backtrace ADD CONSTRAINT execution_backtrace_pkey PRIMARY KEY (execution_id, step_index);'
    " >> ../deployment/01-hyly.sql 2>/dev/null || true
    
    echo "" >> ../deployment/01-hyly.sql
    
    # Export functions
    docker exec hyly-n8n-postgres psql -U n8n -d n8n -t -A -c "
      SELECT pg_get_functiondef(oid) || ';' 
      FROM pg_proc 
      WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'hyly')
      ORDER BY proname
    " >> ../deployment/01-hyly.sql
    
    echo "✅ Exported to deployment/01-hyly.sql"
    echo ""
    echo "Current objects:"
    docker exec hyly-n8n-postgres psql -U n8n -d n8n -t -c "
      SELECT 'Tables: ' || COUNT(*) FROM pg_tables WHERE schemaname = 'hyly'
      UNION ALL
      SELECT 'Functions: ' || COUNT(*) FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'hyly';"
    ;;
    
  commit)
    echo "💾 Committing Hyly extension..."
    
    # First export current state
    $0 export
    
    # Save a timestamped backup
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    cp ../deployment/01-hyly.sql ../backups/hyly-${TIMESTAMP}.sql
    
    echo "✅ Committed to deployment/01-hyly.sql"
    echo "✅ Backup saved to backups/hyly-${TIMESTAMP}.sql"
    ;;
    
  deploy)
    echo "🚀 Testing deployment from deployment/01-hyly.sql..."
    
    # Drop and recreate from deployment file
    docker exec hyly-n8n-postgres psql -U n8n -d n8n -c "DROP SCHEMA IF EXISTS hyly CASCADE;"
    cat ../deployment/01-hyly.sql | docker exec -i hyly-n8n-postgres psql -U n8n -d n8n
    
    echo "✅ Deployed from deployment/01-hyly.sql"
    ;;
    
  *)
    echo "Usage: $0 [export|commit|deploy]"
    echo ""
    echo "  export  - Export current hyly schema objects to hyly--1.0.sql"
    echo "  commit  - Export and save to docker/pg-extensions/ for next deployment"
    echo "  deploy  - Install the committed version (for testing deployment)"
    echo ""
    echo "Workflow:"
    echo "  1. Make changes directly in PostgreSQL (psql, pgAdmin, etc)"
    echo "  2. Test your changes"
    echo "  3. Run: $0 commit"
    echo "  4. Next container rebuild will have your changes"
    ;;
esac