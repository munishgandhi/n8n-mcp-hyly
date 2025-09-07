# Claude Integration Directory

This directory contains Claude Code integration files for hyly-extension tools.

## Structure

- **commands/**: Claude commands and shell scripts for workflow operations
- **scripts/**: Helper scripts and utilities  
- **agents/**: AI agents for complex multi-step workflows

## Tool Integration

The deployment scripts (`../deploy/`) will automatically:
- Copy or symlink tools from `../tools/` to appropriate subdirectories
- Make scripts executable
- Setup proper relative paths

## Usage

### User Installation
```bash
cd ../deploy
./install-to-user.sh --dry-run  # Test first
./install-to-user.sh            # Install to ~/.claude
```

### Project Setup  
```bash
cd ../deploy
./setup-project.sh /path/to/project --dry-run  # Test first
./setup-project.sh /path/to/project            # Setup project
```

## Available Tools (when populated)

- `n8nwf-01-upload.sh` - Upload and verify workflows
- `n8nwf-02-execute.sh` - Execute workflows via CLI
- `n8nwf-03-analyze.sh` - Analyze execution results  
- `n8nwf-04-validate.md` - Validate fix drafts (Claude command)
- `n8nwf-05-mergefix.md` - Merge validated fixes (Claude command)