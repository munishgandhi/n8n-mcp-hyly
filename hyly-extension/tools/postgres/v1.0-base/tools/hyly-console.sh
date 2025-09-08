#!/bin/bash
# Quick access to Hyly development

echo "🔧 Hyly Extension Development"
echo "============================="
echo ""
echo "Connecting to PostgreSQL..."
echo "  • Database: n8n"
echo "  • Schema: hyly"
echo ""
echo "Quick commands:"
echo "  \\df hyly.*              -- List all functions"
echo "  \\dt hyly.*              -- List all tables"
echo "  \\ef hyly.function_name  -- Edit function in editor"
echo "  \\d hyly.table_name      -- Describe table"
echo "  \\q                      -- Quit"
echo ""
echo "Make your changes directly, then run: ./hyly-commit.sh commit"
echo ""

# Connect to PostgreSQL
docker exec -it hyly-n8n-postgres psql -U n8n -d n8n -c "SET search_path TO hyly, public;" -c "\\echo 'Connected to hyly schema'" 