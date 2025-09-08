# Hyly Extension Development

## Quick Development Workflow

### 1. Make Changes
Edit `modify-hyly.sql` with your function/table changes

### 2. Apply Changes
```bash
cd /home/mg/src/n8n-env/docker/pg-extensions/dev
./update-hyly.sh
```

### 3. Test Changes
```bash
# Test in psql
docker exec -it hyly-n8n-postgres psql -U n8n -d n8n

# Run your function
n8n=> SELECT hyly.build_execution_backtrace(1);
```

### 4. When Stable - Save Version
```bash
# Save current version
cp modify-hyly.sql versions/hyly-v1.1-$(date +%Y%m%d).sql
```

## Direct psql Development

For even faster iteration, work directly in psql:

```bash
# Connect to database
docker exec -it hyly-n8n-postgres psql -U n8n -d n8n

# Edit function directly
n8n=> \ef hyly.build_execution_backtrace
# This opens the function in vi/nano for editing

# Or create/replace inline
n8n=> CREATE OR REPLACE FUNCTION hyly.my_function() ...
```

## Export Current State

To capture all current Hyly objects:

```bash
# Export all hyly schema objects
docker exec hyly-n8n-postgres pg_dump -U n8n -d n8n \
  --schema=hyly \
  --no-owner \
  --no-privileges \
  > hyly-current.sql
```

## Files

- `modify-hyly.sql` - Your working file for changes
- `update-hyly.sh` - Quick apply script  
- `versions/` - Stable versions saved here
- `hyly-current.sql` - Current state export