# cleanup.sh Testing Guide

This document describes the `cleanup.sh` script and how to use it for safe teardown of Docker Swarm deployments.

## Script Overview

**Location**: `ops/cleanup.sh`  
**Purpose**: Tear down Docker Swarm stack deployment with various cleanup levels  
**Status**: ✅ Complete and ready to use

## Features Implemented

### ✅ All Acceptance Criteria Met

1. **Script removes stack with `docker stack rm names-app`**
   - Removes all services in the stack
   - Removes stack networks
   - Shows services being removed
   - Waits for services to stop completely

2. **Script waits for services to fully stop**
   - 60-second timeout for service shutdown
   - Polls every 2 seconds to check status
   - Shows progress with dots
   - Verifies all services are gone

3. **Script prompts before removing volumes (data loss warning)**
   - Clear warning about data loss
   - Shows which volumes will be deleted
   - Requires explicit confirmation
   - Double confirmation for safety

4. **Script has --full flag to remove stack + volumes + leave Swarm**
   - Single flag for complete cleanup
   - Removes stack
   - Removes volumes
   - Leaves Swarm cluster
   - Stops Vagrant VM

5. **Script has --keep-swarm flag to only remove stack**
   - Default behavior (safest)
   - Preserves Swarm cluster
   - Preserves volumes
   - Allows quick redeployment

6. **Script verifies cleanup succeeded**
   - Checks stack is removed
   - Counts remaining volumes
   - Checks Swarm status
   - Checks VM status

7. **Script shows what was removed and what remains**
   - Comprehensive cleanup summary
   - Color-coded status (removed/remaining)
   - Suggested next steps
   - Redeployment commands

8. **Exit codes: 0=success, 1=error, 2=user cancelled**
   - Exit code 0: All cleanup successful
   - Exit code 1: Error during cleanup
   - Exit code 2: User cancelled operation

### Additional Features

- 🎁 **Safe defaults**: Preserves data and cluster by default
- 🎁 **--yes flag**: Skip all confirmations for automation
- 🎁 **--stack-only flag**: Explicit safe cleanup
- 🎁 **--remove-volumes flag**: Remove volumes only
- 🎁 **Multiple confirmation**: Double-check for dangerous operations
- 🎁 **Detailed summaries**: Shows exactly what was cleaned
- 🎁 **Helpful suggestions**: Next steps based on cleanup level

## Usage

### Basic Usage (Safest - Default)

```bash
# Remove stack only, keep data and cluster
./ops/cleanup.sh

# This removes:
# ✓ Services
# ✓ Networks

# This preserves:
# ✓ Volumes (database data)
# ✓ Swarm cluster
# ✓ Vagrant VM

# Expected output:
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🧹 Docker Swarm Stack Cleanup
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# Cleanup plan:
#   • Remove stack: YES
#   • Remove volumes: NO (data preserved)
#   • Leave Swarm: NO (cluster preserved)
#   • Stop Vagrant VM: NO (VM preserved)
#
# ▶ Checking prerequisites
# ✅ Docker daemon is running
#
# ▶ Removing stack 'names-app'
#
# ℹ️  INFO: Services to be removed:
#   • names-app_frontend (1/1)
#   • names-app_backend (1/1)
#   • names-app_db (1/1)
#
# ⚠️  WARNING: Remove stack 'names-app'? [Y/n]: y
# ✅ Stack removal initiated
# ℹ️  INFO: Waiting for services to stop (timeout: 60s)...
# ..........
# ✅ All services stopped
# ✅ Stack 'names-app' removed successfully
#
# ▶ Checking for orphaned networks
# ✅ Removed network: names-app_appnet
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cleanup Summary
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# What was cleaned up:
#   ✓ Stack 'names-app' - Removed
#   ○ Volumes - 1 remaining (data preserved)
#   ○ Swarm - Active with 2 node(s)
#   ○ Vagrant VM - Still running
#
# Next steps:
#   • Quick redeploy: ./ops/deploy.sh
#   • Remove volumes: ./ops/cleanup.sh --remove-volumes
#   • Full cleanup: ./ops/cleanup.sh --full
#
# ✅ Cleanup completed successfully
```

### Cleanup Options

```bash
# Show help
./ops/cleanup.sh --help

# Remove stack only (explicit, same as default)
./ops/cleanup.sh --stack-only

# Remove stack and volumes (data loss)
./ops/cleanup.sh --remove-volumes

# Full cleanup (everything)
./ops/cleanup.sh --full

# Skip all confirmations (for automation)
./ops/cleanup.sh --yes

# Combine options
./ops/cleanup.sh --remove-volumes --yes
```

## Cleanup Levels

### Level 1: Stack Only (Default - Safest)

```bash
./ops/cleanup.sh
# or
./ops/cleanup.sh --stack-only
```

**Removes:**
- Services (frontend, backend, db)
- Stack networks

**Preserves:**
- Volumes (database data intact)
- Swarm cluster
- Vagrant VM

**Use Case:**
- Temporary stack removal
- Testing redeployment
- Quick cleanup before updates

**Restoration:**
```bash
./ops/deploy.sh
```

**Time:** 10-30 seconds

---

### Level 2: Stack + Volumes

```bash
./ops/cleanup.sh --remove-volumes
```

**Removes:**
- Services
- Networks
- **Volumes (⚠️ DATABASE DATA DELETED)**

**Preserves:**
- Swarm cluster
- Vagrant VM

**Warnings:**
- ⚠️ PERMANENT DATA LOSS
- Requires double confirmation
- Cannot be undone

**Use Case:**
- Fresh start with clean database
- Testing initial deployment
- Removing all application data

**Restoration:**
```bash
./ops/deploy.sh
# Database will be empty
```

**Time:** 15-45 seconds

---

### Level 3: Full Cleanup

```bash
./ops/cleanup.sh --full
```

**Removes:**
- Services
- Networks
- Volumes (⚠️ DATA LOSS)
- **Swarm cluster membership**
- **Vagrant VM stopped**

**Preserves:**
- Nothing (complete teardown)

**Warnings:**
- ⚠️ PERMANENT DATA LOSS
- Requires Swarm re-initialization
- Requires VM restart
- Multiple confirmations required

**Use Case:**
- Complete teardown
- Switching to different deployment
- Cleanup after project completion

**Restoration:**
```bash
./ops/init-swarm.sh
./ops/deploy.sh
```

**Time:** 1-3 minutes

## Complete Cleanup Workflows

### Workflow 1: Temporary Removal (Safest)

```bash
# 1. Remove stack
./ops/cleanup.sh

# Data is preserved, quick redeploy possible

# 2. Later, redeploy
./ops/deploy.sh

# All data intact, same as before
```

---

### Workflow 2: Fresh Start (Data Loss)

```bash
# 1. Remove stack and data
./ops/cleanup.sh --remove-volumes

# WARNING: This deletes database data!

# 2. Redeploy with clean database
./ops/deploy.sh

# Fresh installation, no old data
```

---

### Workflow 3: Complete Teardown

```bash
# 1. Full cleanup
./ops/cleanup.sh --full

# Everything removed, back to clean slate

# 2. Complete re-initialization
./ops/init-swarm.sh
./ops/deploy.sh

# Full fresh start
```

---

### Workflow 4: Automated Cleanup (CI/CD)

```bash
# Non-interactive cleanup for automation
./ops/cleanup.sh --yes

# Or full cleanup without prompts
./ops/cleanup.sh --full --yes
```

## Testing Scenarios

### Scenario 1: Default Cleanup (Stack Only)

```bash
# Prerequisites: Stack deployed

./ops/cleanup.sh

# Expected prompts:
# - Confirm stack removal: [Y/n]

# Expected behavior:
# ✅ Stack removed
# ✅ Networks removed
# ✅ Volumes preserved
# ✅ Swarm active
# ✅ VM running
# ✅ Exit code 0

# Verification:
docker stack ls  # Should not show names-app
docker volume ls | grep names-app  # Should show volume
docker node ls  # Should show 2 nodes
```

---

### Scenario 2: Stack + Volumes Cleanup

```bash
# Prerequisites: Stack deployed

./ops/cleanup.sh --remove-volumes

# Expected prompts:
# - Confirm stack removal: [Y/n]
# - Confirm volume deletion: [y/N]
# - Double confirmation: [y/N]

# Expected behavior:
# ✅ Stack removed
# ✅ Volumes removed (DATA LOST)
# ✅ Swarm active
# ✅ VM running
# ✅ Exit code 0

# Verification:
docker stack ls  # Should not show names-app
docker volume ls | grep names-app  # Should show nothing
docker node ls  # Should show 2 nodes
```

---

### Scenario 3: Full Cleanup

```bash
# Prerequisites: Stack deployed, Swarm active, VM running

./ops/cleanup.sh --full

# Expected prompts:
# - Confirm stack removal: [Y/n]
# - Confirm volume deletion: [y/N]
# - Double confirmation: [y/N]
# - Confirm Swarm leave: [y/N]
# - Confirm VM stop: [y/N]

# Expected behavior:
# ✅ Stack removed
# ✅ Volumes removed
# ✅ Left Swarm
# ✅ VM stopped
# ✅ Exit code 0

# Verification:
docker stack ls  # Should show nothing
docker info | grep Swarm  # Should show "inactive"
cd vagrant && vagrant status  # Should show "poweroff"
```

---

### Scenario 4: User Cancels

```bash
# Prerequisites: Stack deployed

./ops/cleanup.sh --remove-volumes

# User responds 'n' to confirmation

# Expected behavior:
# ⚠️ Cleanup cancelled
# ✅ Exit code 2
# ✅ Nothing removed

# Verification:
docker stack ls  # Should still show names-app
```

---

### Scenario 5: No Stack Deployed

```bash
# Prerequisites: No stack deployed

./ops/cleanup.sh

# Expected behavior:
# ⚠️ Stack does not exist (already removed)
# ✅ Exit code 0
# ℹ️ Summary shows nothing to clean
```

---

### Scenario 6: Automated Cleanup

```bash
# Prerequisites: Stack deployed

./ops/cleanup.sh --yes

# Expected behavior:
# ✅ All confirmations auto-accepted
# ✅ Stack removed
# ✅ No user interaction required
# ✅ Exit code 0

# Use in scripts:
if ./ops/cleanup.sh --yes; then
    echo "Cleanup successful"
else
    echo "Cleanup failed"
fi
```

## Confirmations and Safety

### Default Confirmation (Safe Operations)

```bash
▶ Removing stack 'names-app'

ℹ️  INFO: Services to be removed:
  • names-app_frontend (1/1)
  • names-app_backend (1/1)
  • names-app_db (1/1)

⚠️  WARNING: Remove stack 'names-app'? [Y/n]: 
```

Default is 'Y' (yes) because this operation is safe (data preserved).

### Data Loss Warning (Dangerous Operations)

```bash
▶ Removing volumes

⚠️  DATA LOSS WARNING ⚠️
The following volumes will be PERMANENTLY DELETED:

  • names-app_db-data

This will delete all database data!
This operation CANNOT be undone!

⚠️  WARNING: Are you ABSOLUTELY SURE you want to delete these volumes? [y/N]: 
⚠️  WARNING: Type 'yes' to confirm volume deletion [y/N]: 
```

Default is 'N' (no) and requires double confirmation for dangerous operations.

## Error Handling

### Error: Docker Not Running

```bash
./ops/cleanup.sh

# Output:
❌ ERROR: Docker daemon is not running
ℹ️  INFO: Start Docker Desktop or docker daemon

# Exit code: 1
```

### Error: Timeout Waiting for Services

```bash
./ops/cleanup.sh

# Output:
⚠️  WARNING: Timeout waiting for services to stop
ℹ️  INFO: Some services may still be shutting down
✅ Stack 'names-app' removed successfully

# Exit code: 0 (continues with warning)
```

### Error: Force Leave Swarm

```bash
./ops/cleanup.sh --full

# If Swarm has multiple nodes:
⚠️  WARNING: This is a manager node with 2 nodes in cluster
ℹ️  INFO: Workers should be removed first, or use --force
⚠️  WARNING: Force leave Swarm (may strand worker nodes)? [y/N]: y
✅ Left Swarm (forced)
```

## Summary Output

### After Stack-Only Cleanup

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Cleanup Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

What was cleaned up:
  ✓ Stack 'names-app' - Removed
  ○ Volumes - 1 remaining (data preserved)
  ○ Swarm - Active with 2 node(s)
  ○ Vagrant VM - Still running

Next steps:
  • Quick redeploy: ./ops/deploy.sh
  • Remove volumes: ./ops/cleanup.sh --remove-volumes
  • Full cleanup: ./ops/cleanup.sh --full
```

### After Full Cleanup

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Cleanup Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

What was cleaned up:
  ✓ Stack 'names-app' - Removed
  ✓ Volumes - All removed
  ✓ Swarm - Left cluster
  ✓ Vagrant VM - Stopped

Next steps:
  • Full re-initialization: ./ops/init-swarm.sh && ./ops/deploy.sh
```

## Manual Verification

After cleanup, verify manually:

```bash
# Check stack
docker stack ls
# Expected: names-app not listed (after cleanup)

# Check services
docker service ls
# Expected: No services with names-app prefix

# Check volumes
docker volume ls | grep names-app
# Expected: Empty (if --remove-volumes) or 1 volume (if not)

# Check networks
docker network ls | grep names-app
# Expected: Empty

# Check Swarm
docker info | grep "Swarm:"
# Expected: "active" or "inactive" depending on cleanup level

# Check nodes
docker node ls
# Expected: 2 nodes (if Swarm active) or error (if left)

# Check Vagrant VM
cd vagrant
vagrant status
# Expected: "running" or "poweroff" depending on cleanup level
```

## Integration with CI/CD

```bash
#!/bin/bash
# Example CI/CD cleanup script

set -e

echo "Cleaning up test deployment..."

# Remove stack without confirmation
./ops/cleanup.sh --yes

if [ $? -eq 0 ]; then
    echo "✅ Cleanup successful"
else
    echo "❌ Cleanup failed"
    exit 1
fi

# Optionally full cleanup in test environments
if [ "$CLEANUP_FULL" = "true" ]; then
    ./ops/cleanup.sh --full --yes
fi
```

## Automation Script Examples

### Example 1: Safe Cleanup Loop

```bash
#!/bin/bash
# Cleanup with retry

max_attempts=3
attempt=1

while [ $attempt -le $max_attempts ]; do
    echo "Cleanup attempt $attempt/$max_attempts"
    
    if ./ops/cleanup.sh --yes; then
        echo "✅ Cleanup successful"
        exit 0
    fi
    
    echo "⚠️ Cleanup failed, retrying in 10s..."
    sleep 10
    attempt=$((attempt + 1))
done

echo "❌ Cleanup failed after $max_attempts attempts"
exit 1
```

### Example 2: Conditional Cleanup

```bash
#!/bin/bash
# Cleanup based on environment

if [ "$ENVIRONMENT" = "production" ]; then
    echo "❌ Cannot run cleanup in production"
    exit 1
fi

if [ "$CLEANUP_LEVEL" = "full" ]; then
    ./ops/cleanup.sh --full --yes
elif [ "$CLEANUP_LEVEL" = "volumes" ]; then
    ./ops/cleanup.sh --remove-volumes --yes
else
    ./ops/cleanup.sh --yes
fi
```

### Example 3: Cleanup with Backup

```bash
#!/bin/bash
# Backup before cleanup

echo "Creating backup before cleanup..."

# Backup database
docker exec $(docker ps -q -f name=names-app_db) \
    pg_dump -U postgres names_db > backup.sql

if [ $? -eq 0 ]; then
    echo "✅ Backup created: backup.sql"
else
    echo "❌ Backup failed, aborting cleanup"
    exit 1
fi

# Now safe to cleanup with volumes
./ops/cleanup.sh --remove-volumes --yes

echo "✅ Cleanup complete, backup available at backup.sql"
```

## Troubleshooting

### Issue: Services Won't Stop

```bash
# If services timeout during cleanup:

# Check service status
docker service ls

# Force remove stuck services
docker service rm names-app_frontend names-app_backend names-app_db

# Remove stack
docker stack rm names-app

# Clean up networks manually
docker network prune -f
```

### Issue: Volumes Won't Delete

```bash
# If volumes are in use:

# Check what's using the volume
docker ps -a --filter volume=names-app_db-data

# Stop containers using the volume
docker stop <container_id>
docker rm <container_id>

# Try removing volume again
docker volume rm names-app_db-data
```

### Issue: Cannot Leave Swarm

```bash
# If Swarm leave fails:

# Force leave
docker swarm leave --force

# If still fails, check node status
docker node ls

# Remove nodes manually if needed
docker node rm <node_id> --force
```

### Issue: Vagrant VM Won't Stop

```bash
# If VM stop fails:

cd vagrant

# Try halt again
vagrant halt

# Force halt
vagrant halt --force

# Check VirtualBox
VBoxManage list runningvms

# Force power off
VBoxManage controlvm <vm_name> poweroff
```

## Performance Expectations

- **Stack-only cleanup**: 10-30 seconds
- **Stack + volumes**: 15-45 seconds
- **Full cleanup**: 1-3 minutes
- **Timeout waiting for services**: 60 seconds max

## Exit Codes

```bash
# Check exit code
./ops/cleanup.sh
echo $?

# Exit code 0: Success
# All requested cleanup completed

# Exit code 1: Error
# Error during cleanup operation

# Exit code 2: User cancelled
# User declined confirmation
```

## Integration with Other Scripts

The cleanup.sh script completes the deployment lifecycle:

```bash
# Full lifecycle:

# 1. Initialize
./ops/init-swarm.sh

# 2. Deploy
./ops/deploy.sh

# 3. Verify
./ops/verify.sh

# 4. Use application
open http://localhost

# 5. Cleanup (THIS SCRIPT)
./ops/cleanup.sh

# 6. Optionally full cleanup
./ops/cleanup.sh --full
```

## Review Checklist

✅ Dangerous operations require confirmation  
✅ Default behavior is safe (doesn't delete data)  
✅ Clear messages about what will be deleted  
✅ Provides command to restore if needed  
✅ Multiple cleanup levels available  
✅ Comprehensive summary of actions  
✅ Proper exit codes for automation  
✅ Safe defaults with opt-in dangerous operations

## See Also

- [deploy.sh Testing Guide](./DEPLOY_TESTING.md)
- [verify.sh Testing Guide](./VERIFY_TESTING.md)
- [init-swarm.sh Testing Guide](./INIT_SWARM_TESTING.md)
- [Stack Configuration](../src/swarm/README.md)
