# PostgreSQL Extensions for n8n

This directory contains PostgreSQL extensions, optimizations, and utilities for the n8n database.

## Directory Structure

```
pg-extensions/
├── init/                     # SQL scripts that run on container initialization
│   ├── 01-enable-extensions.sql    # Enables common PostgreSQL extensions
│   ├── 02-n8n-optimizations.sql    # n8n-specific performance optimizations
│   └── 03-vector-search.sql        # pgvector setup for AI/ML workloads
├── scripts/                  # Utility scripts for database management
│   ├── backup.sh            # Automated backup script
│   └── restore.sh           # Database restore script
├── conf/                    # PostgreSQL configuration files
│   └── postgresql.conf      # Optimized PostgreSQL settings for n8n
└── README.md               # This file
```

## Enabled Extensions

### Core Extensions (Always Enabled)
- **uuid-ossp**: UUID generation functions
- **pgcrypto**: Cryptographic functions for encryption/hashing
- **citext**: Case-insensitive text data type
- **pg_trgm**: Trigram matching for fuzzy text search
- **unaccent**: Text normalization by removing accents
- **tablefunc**: Crosstab and other table functions
- **hstore**: Key-value store within PostgreSQL
- **ltree**: Hierarchical tree-like data structures

### Optional Extensions
- **pgvector**: Vector similarity search for AI embeddings (requires special image)

## Usage

### Mounting Extensions in Docker Compose

Add these volumes to your PostgreSQL service in `docker-compose.yml`:

```yaml
services:
  postgres:
    volumes:
      # Mount initialization scripts
      - ./docker/pg-extensions/init:/docker-entrypoint-initdb.d:ro
      # Mount custom configuration
      - ./docker/pg-extensions/conf/postgresql.conf:/etc/postgresql/postgresql.conf:ro
      # Mount backup directory
      - ./docker/pg-extensions/backups:/backups
    command: postgres -c config_file=/etc/postgresql/postgresql.conf
```

### Backup and Restore

#### Creating a Backup
```bash
# From host
docker exec hyly-n8n-postgres /bin/bash -c "/scripts/backup.sh"

# With custom name
docker exec hyly-n8n-postgres /bin/bash -c "/scripts/backup.sh my_backup_name"
```

#### Restoring from Backup
```bash
# List available backups
docker exec hyly-n8n-postgres ls -la /backups/

# Restore specific backup
docker exec -it hyly-n8n-postgres /bin/bash -c "/scripts/restore.sh backup_n8n_20250830_120000.sql.gz"
```

## Performance Optimizations

The `02-n8n-optimizations.sql` script creates indexes for:
- Active workflows lookup
- Execution history queries
- Webhook path resolution
- Status-based filtering

These indexes significantly improve n8n performance for:
- Loading workflow lists
- Execution history pagination
- Webhook triggering
- Dashboard statistics

## Vector Search Setup

If you need AI/ML capabilities with vector search:

1. Use a PostgreSQL image with pgvector:
```yaml
image: pgvector/pgvector:15-alpine
```

2. The `03-vector-search.sql` script will automatically:
   - Enable the pgvector extension
   - Create a workflow_embeddings table
   - Set up vector similarity indexes

3. Use vector search in n8n workflows:
```sql
-- Find similar workflows
SELECT workflow_id, 
       embedding <=> '[0.1, 0.2, ...]'::vector AS distance
FROM workflow_embeddings
ORDER BY distance
LIMIT 10;
```

## Configuration Tuning

The `postgresql.conf` file includes optimized settings for:
- **Memory**: Tuned for 2-4GB RAM systems
- **Connections**: Supports up to 200 concurrent connections
- **Performance**: Parallel query execution enabled
- **Logging**: Captures slow queries (>100ms)
- **Autovacuum**: Aggressive cleanup for high-transaction workloads

### Adjusting for Your System

For different RAM sizes, adjust these values:
- **1GB RAM**: `shared_buffers = 128MB`, `effective_cache_size = 512MB`
- **4GB RAM**: `shared_buffers = 512MB`, `effective_cache_size = 2GB`
- **8GB+ RAM**: `shared_buffers = 1GB`, `effective_cache_size = 4GB`

## Monitoring

Check extension status:
```sql
-- List installed extensions
SELECT * FROM pg_extension;

-- Check custom indexes
SELECT indexname, tablename 
FROM pg_indexes 
WHERE indexname LIKE 'idx_%';

-- View table statistics
SELECT schemaname, tablename, n_live_tup, n_dead_tup 
FROM pg_stat_user_tables;
```

## Troubleshooting

### Extensions Not Loading
- Check PostgreSQL logs: `docker logs hyly-n8n-postgres`
- Verify mount paths in docker-compose.yml
- Ensure SQL files have proper permissions

### Performance Issues
- Run `ANALYZE;` to update statistics
- Check slow query log in PostgreSQL logs
- Verify indexes are being used: `EXPLAIN ANALYZE <query>`

### Backup/Restore Failures
- Ensure backup directory is mounted and writable
- Check disk space for backups
- Verify PostgreSQL user has necessary permissions

## Security Notes

- Always use strong passwords for database users
- Regularly backup your database
- Monitor logs for suspicious activity
- Keep PostgreSQL image updated
- Use SSL/TLS for remote connections

## Additional Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [n8n Database Setup](https://docs.n8n.io/hosting/configuration/database/)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server)