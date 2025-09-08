# PostgreSQL Analysis Tools

This directory contains SQL scripts and tools for analyzing n8n workflows and executions using PostgreSQL database queries.

## Structure

- **v1.0-base/**: Base PostgreSQL scripts for n8n database analysis
  - **init/**: Database initialization and optimization scripts
    - `01-hyly.sql` - Hyly-specific database setup
    - `02-extensions.sql` - PostgreSQL extensions
    - `03-optimizations.sql` - Performance optimizations

## Usage

These scripts are designed to work with n8n's PostgreSQL database to provide insights into:
- Workflow execution patterns
- Performance analysis
- Error tracking and debugging
- Database optimization

### Prerequisites

1. Access to n8n PostgreSQL database
2. PostgreSQL client (psql) or database management tool
3. Appropriate database permissions for analysis queries

### Running Scripts

```bash
# Connect to n8n database
psql -h localhost -U n8n_user -d n8n_db

# Run initialization scripts (one time)
\i v1.0-base/init/01-hyly.sql
\i v1.0-base/init/02-extensions.sql  
\i v1.0-base/init/03-optimizations.sql
```

### Integration with Workflow Development

These tools complement the workflow development lifecycle by providing:
- Deep analysis of execution data beyond what's available via API
- Historical performance tracking
- Advanced debugging capabilities for complex workflow issues
- Database-level insights for optimization

### Safety Notes

- **Read-only analysis**: Most scripts are designed for analysis, not modification
- **Backup first**: Always backup database before running optimization scripts
- **Test environment**: Run new scripts in development before production use
- **Permissions**: Use dedicated analysis user with minimal required permissions

## Development

When adding new analysis scripts:
1. Place in appropriate version directory (v1.0-base, etc.)
2. Include comments explaining purpose and usage
3. Test thoroughly in development environment
4. Document any new dependencies or setup requirements
