# verify.sh Testing Guide

This document describes the `verify.sh` script and how to use it for deployment verification.

## Script Overview

**Location**: `ops/verify.sh`  
**Purpose**: Verify Docker Swarm stack deployment health and configuration  
**Status**: ✅ Complete and ready to use

## Features Implemented

### ✅ All Acceptance Criteria Met

1. **Script checks `docker service ls` shows all services running**
   - Verifies stack exists with expected number of services (3)
   - Checks each service has ready replicas (e.g., "1/1")
   - Reports any services that are not ready

2. **Script verifies service placement using `docker service ps`**
   - Checks database service is on worker node
   - Checks backend service is on manager node
   - Checks frontend service is on manager node
   - Validates placement constraints are working

3. **Script tests database health with pg_isready**
   - Executes `pg_isready` inside database container
   - Verifies PostgreSQL is accepting connections
   - Reports connection status

4. **Script tests backend health endpoint `/healthz`**
   - Sends HTTP request to backend health endpoint
   - Validates HTTP 200 response code
   - Checks response body for `"status":"ok"`

5. **Script tests frontend accessibility (HTTP 200 on port 80)**
   - Sends HTTP request to frontend
   - Validates HTTP 200 response
   - Confirms frontend is serving content

6. **Script tests cross-node service discovery**
   - Verifies backend can resolve database service name
   - Tests network connectivity between nodes
   - Validates overlay network is working

7. **Script outputs clear PASS/FAIL for each check**
   - Color-coded output: ✅ Green (pass), ❌ Red (fail), ⚠️ Yellow (warn)
   - Clear status for each verification step
   - Easy to scan results

8. **Script provides summary and troubleshooting hints on failures**
   - Summary shows total/passed/failed counts
   - Troubleshooting commands for each failure
   - Helpful suggestions for common issues

9. **Exit codes: 0=all checks pass, 1=some checks fail**
   - Exit code 0: All checks passed
   - Exit code 1: One or more checks failed
   - Can be used in automation scripts

### Additional Features

- **--verbose flag**: Show detailed output for each check
- **--quick flag**: Skip slow checks (service discovery)
- **--help flag**: Comprehensive usage documentation
- **Non-destructive**: Can run repeatedly without side effects
- **Comprehensive checks**: 9 different verification tests
- **Progress tracking**: Shows which check is running
- **Detailed summaries**: Access URLs, monitoring commands

## Usage

### Basic Usage

```bash
# Prerequisites: Stack deployed
./ops/verify.sh

# Expected output:
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🔍 Docker Swarm Stack Verification
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# ℹ️  INFO: Stack: names-app
# ℹ️  INFO: Expected Services: 3 (frontend, backend, db)
#
# 🔍 Checking: Docker daemon is running
# ✅ PASS: Docker daemon is running
#
# 🔍 Checking: Docker Swarm is active
# ✅ PASS: Docker Swarm is active with 2 nodes
#
# 🔍 Checking: Stack 'names-app' exists
# ✅ PASS: Stack 'names-app' exists with 3 services
#
# 🔍 Checking: All services have ready replicas
# ✅ PASS: All services have ready replicas
#
# 🔍 Checking: Services are placed on correct nodes
# ✅ PASS: All services are placed on correct nodes
#
# 🔍 Checking: Database health (pg_isready)
# ✅ PASS: Database is accepting connections
#
# 🔍 Checking: Backend health endpoint (/healthz)
# ✅ PASS: Backend health endpoint returns healthy status
#
# 🔍 Checking: Frontend accessibility (HTTP 200 on port 80)
# ✅ PASS: Frontend is accessible and returns HTTP 200
#
# 🔍 Checking: Cross-node service discovery (backend → database)
# ✅ PASS: Backend can reach database via service discovery
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Verification Summary
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# Total Checks: 9
# Passed: 9
# Failed: 0
# Warnings: 0
#
# 🎉 All checks passed! Your Swarm deployment is healthy.
#
# 📍 Application Access:
#    Frontend:      http://localhost:80
#    Frontend:      http://192.168.56.1:80
#    API Health:    http://localhost/api/health
#    Swarm Health:  http://localhost/healthz
#
# 📊 Monitoring:
#    Service Status:  docker stack services names-app
#    Service Logs:    docker service logs names-app_<service>
#    Service Details: docker stack ps names-app
```

### With Options

```bash
# Show help
./ops/verify.sh --help

# Verbose output (show details for each check)
./ops/verify.sh --verbose

# Quick mode (skip service discovery test)
./ops/verify.sh --quick

# Combine options
./ops/verify.sh --verbose --quick
```

## Complete Verification Workflow

### Step 1: Deploy Stack

```bash
# Initialize Swarm and deploy
./ops/init-swarm.sh
./ops/deploy.sh

# Wait for deployment to complete
```

### Step 2: Run Verification

```bash
./ops/verify.sh

# If all checks pass:
# Exit code: 0
# All services healthy and accessible

# If any check fails:
# Exit code: 1
# Detailed failure information provided
```

### Step 3: Address Issues (if needed)

```bash
# View service logs
docker service logs names-app_backend

# Check service status
docker service ps names-app_backend --no-trunc

# Update service if needed
docker service update --force names-app_backend

# Re-run verification
./ops/verify.sh
```

## Checks Performed

### Check 1: Docker Daemon Running

```bash
# What it does:
# - Verifies docker command works
# - Checks Docker daemon is accessible

# Pass criteria:
# - `docker info` succeeds

# Failure troubleshooting:
# - Start Docker Desktop
# - Check docker daemon status
```

### Check 2: Docker Swarm Active

```bash
# What it does:
# - Verifies Swarm mode is active
# - Counts number of nodes (expects 2+)

# Pass criteria:
# - Swarm status is "active"
# - At least 2 nodes present

# Failure troubleshooting:
# - Run: ./ops/init-swarm.sh
# - Check: docker node ls
```

### Check 3: Stack Exists

```bash
# What it does:
# - Checks stack 'names-app' is deployed
# - Verifies 3 services exist

# Pass criteria:
# - Stack found in `docker stack ls`
# - Exactly 3 services in stack

# Failure troubleshooting:
# - Run: ./ops/deploy.sh
# - Check: docker stack ls
```

### Check 4: Services Running

```bash
# What it does:
# - Checks each service's replica status
# - Verifies replicas are ready (1/1)

# Pass criteria:
# - All services show ready replicas
# - Format: "1/1" (running/desired)

# Failure troubleshooting:
# - Wait for services to start
# - Check logs: docker service logs <service>
# - Check tasks: docker service ps <service>
```

### Check 5: Service Placement

```bash
# What it does:
# - Verifies database is on worker node
# - Verifies backend is on manager node
# - Verifies frontend is on manager node

# Pass criteria:
# - db on node with "worker" in name
# - backend on manager node
# - frontend on manager node

# Failure troubleshooting:
# - Check stack.yaml placement constraints
# - Redeploy: ./ops/deploy.sh --update
```

### Check 6: Database Health

```bash
# What it does:
# - Executes pg_isready inside database container
# - Verifies PostgreSQL is accepting connections

# Pass criteria:
# - pg_isready returns success

# Failure troubleshooting:
# - Check db logs: docker service logs names-app_db
# - Check db status: docker service ps names-app_db
# - Wait for PostgreSQL to start
```

### Check 7: Backend Health Endpoint

```bash
# What it does:
# - Sends GET request to http://localhost:8000/healthz
# - Validates HTTP 200 response
# - Checks for {"status":"ok"} in body

# Pass criteria:
# - HTTP 200 response code
# - Response body contains "status":"ok"

# Failure troubleshooting:
# - Check backend logs: docker service logs names-app_backend
# - Test manually: curl http://localhost:8000/healthz
# - Check database connection
```

### Check 8: Frontend Accessibility

```bash
# What it does:
# - Sends GET request to http://localhost:80
# - Validates HTTP 200 response

# Pass criteria:
# - HTTP 200 response code

# Failure troubleshooting:
# - Check frontend logs: docker service logs names-app_frontend
# - Verify port 80 exposed: docker service inspect names-app_frontend
# - Check nginx config
```

### Check 9: Service Discovery

```bash
# What it does:
# - Verifies backend can resolve "db" service name
# - Tests connectivity to database port 5432
# - Validates overlay network

# Pass criteria:
# - Backend can resolve hostname "db"
# - Backend can connect to port 5432 on db

# Failure troubleshooting:
# - Check network: docker network inspect names-app_appnet
# - Verify services on same network
# - Check overlay network driver

# Note: Skipped with --quick flag
```

## Testing Scenarios

### Scenario 1: All Checks Pass

```bash
# Prerequisites: Healthy deployment

./ops/verify.sh

# Expected behavior:
# ✅ 9/9 checks pass
# ✅ Exit code 0
# ✅ Success message with access URLs
```

### Scenario 2: Services Not Ready

```bash
# Prerequisites: Just deployed, services starting

./ops/verify.sh

# Expected behavior:
# ❌ "Services running" check fails
# Exit code: 1
# Troubleshooting: Wait for services to start
```

### Scenario 3: Backend Unhealthy

```bash
# Prerequisites: Backend cannot reach database

./ops/verify.sh

# Expected behavior:
# ❌ "Backend health endpoint" check fails
# Exit code: 1
# Troubleshooting: Check backend logs, database connection
```

### Scenario 4: Wrong Service Placement

```bash
# Prerequisites: Placement constraints not working

./ops/verify.sh

# Expected behavior:
# ❌ "Service placement" check fails
# Exit code: 1
# Troubleshooting: Check stack.yaml, redeploy
```

### Scenario 5: No Stack Deployed

```bash
# Prerequisites: Stack not deployed

./ops/verify.sh

# Expected behavior:
# ❌ "Stack exists" check fails
# Exit code: 1
# Troubleshooting: Run ./ops/deploy.sh
```

### Scenario 6: Swarm Not Initialized

```bash
# Prerequisites: Swarm not active

./ops/verify.sh

# Expected behavior:
# ❌ "Swarm active" check fails
# Exit code: 1
# Troubleshooting: Run ./ops/init-swarm.sh
```

## Verbose Mode Output

```bash
./ops/verify.sh --verbose

# Shows additional information:
# - Docker node list
# - Service details
# - HTTP response codes
# - Container IDs
# - Network resolution details
# - Task placement details
```

## Quick Mode

```bash
./ops/verify.sh --quick

# Skips:
# - Service discovery check (slow)

# Useful for:
# - Rapid health checks
# - CI/CD pipelines
# - Frequent monitoring
```

## Integration with CI/CD

```bash
#!/bin/bash
# Example CI/CD script

# Deploy application
./ops/deploy.sh || exit 1

# Verify deployment
./ops/verify.sh || {
    echo "Deployment verification failed"
    docker service logs names-app_backend
    exit 1
}

echo "Deployment successful and verified"
```

## Automation Script Example

```bash
#!/bin/bash
# Full deployment and verification

set -e

echo "Step 1: Initialize Swarm"
./ops/init-swarm.sh

echo "Step 2: Deploy stack"
./ops/deploy.sh

echo "Step 3: Wait 30 seconds for services to stabilize"
sleep 30

echo "Step 4: Verify deployment"
if ./ops/verify.sh; then
    echo "✅ Deployment successful and healthy"
else
    echo "❌ Deployment verification failed"
    echo "Checking logs..."
    docker service logs names-app_backend --tail 50
    exit 1
fi
```

## Monitoring Loops

```bash
# Watch deployment status
while true; do
    clear
    ./ops/verify.sh
    sleep 10
done

# Check every minute until healthy
while ! ./ops/verify.sh; do
    echo "Deployment not healthy yet, waiting 60 seconds..."
    sleep 60
done
echo "Deployment is healthy!"
```

## Manual Verification

After running verify.sh, you can manually check:

```bash
# View stack
docker stack ls
docker stack services names-app
docker stack ps names-app

# Test endpoints
curl -i http://localhost
curl http://localhost/api/health | jq
curl http://localhost/healthz | jq

# Check logs
docker service logs names-app_frontend --tail 50
docker service logs names-app_backend --tail 50
docker service logs names-app_db --tail 50

# Inspect services
docker service inspect names-app_backend --pretty
docker service ps names-app_backend --no-trunc

# Check networks
docker network ls
docker network inspect names-app_appnet
```

## Troubleshooting Common Issues

### Issue: Services Not Starting

```bash
# Check service logs
docker service logs names-app_backend

# Check task status
docker service ps names-app_backend --no-trunc

# Force update
docker service update --force names-app_backend

# Re-verify
./ops/verify.sh
```

### Issue: Health Check Failing

```bash
# Check endpoint manually
curl -v http://localhost:8000/healthz

# Check backend logs for errors
docker service logs names-app_backend | grep -i error

# Verify database connection
docker exec $(docker ps -q -f name=names-app_backend) curl -v http://db:5432
```

### Issue: Service Discovery Not Working

```bash
# Check overlay network
docker network inspect names-app_appnet

# Verify services are on network
docker service inspect names-app_backend | grep -A 10 Networks

# Test DNS resolution
docker exec $(docker ps -q -f name=names-app_backend) nslookup db
```

### Issue: Wrong Node Placement

```bash
# Check placement constraints in stack.yaml
cat src/swarm/stack.yaml | grep -A 5 "placement:"

# Check node labels
docker node inspect <node-name> --format '{{ .Spec.Labels }}'

# Redeploy with correct constraints
./ops/deploy.sh --update
```

## Performance Expectations

- **Full verification**: 10-20 seconds
- **Quick mode**: 5-10 seconds
- **Verbose mode**: 15-25 seconds
- **Service discovery check**: 2-5 seconds (most time-consuming)

## Exit Codes

```bash
# Check exit code
./ops/verify.sh
echo $?

# Exit code 0: Success
# All checks passed

# Exit code 1: Failure
# One or more checks failed
```

## Integration with Other Scripts

The verify.sh script fits into the deployment workflow:

```bash
# 1. Initialize cluster
./ops/init-swarm.sh

# 2. Deploy application
./ops/deploy.sh

# 3. Verify deployment (THIS SCRIPT)
./ops/verify.sh

# 4. Use application
open http://localhost

# 5. Cleanup (when done)
./ops/cleanup.sh
```

## Review Checklist

✅ Each check has clear pass/fail criteria  
✅ Failures include helpful troubleshooting info  
✅ Script can run repeatedly without side effects  
✅ Output is easy to understand  
✅ Color-coded for quick scanning  
✅ Provides actionable next steps  
✅ Non-destructive operations only  
✅ Detailed summary at end  
✅ Exit codes usable in automation

## See Also

- [deploy.sh Testing Guide](./DEPLOY_TESTING.md)
- [init-swarm.sh Testing Guide](./INIT_SWARM_TESTING.md)
- [Stack Configuration](../src/swarm/README.md)
- [Health Check Documentation](../src/backend/HEALTHZ_TESTING.md)
