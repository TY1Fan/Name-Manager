# deploy.sh Testing Guide

This document describes the `deploy.sh` script and how to use it.

## Script Overview

**Location**: `ops/deploy.sh`  
**Purpose**: Deploy the Names Manager application stack to Docker Swarm  
**Status**: ✅ Complete and ready to use

## Features Implemented

### ✅ All Acceptance Criteria Met

1. **Script verifies Swarm is initialized before deploying**
   - Checks if Docker daemon is running
   - Verifies Swarm is active
   - Confirms at least 2 nodes (manager + worker)

2. **Script checks .env file exists and has required variables**
   - Validates .env file presence in src/
   - Sources and checks required environment variables:
     - POSTGRES_USER
     - POSTGRES_PASSWORD
     - POSTGRES_DB
     - DB_URL

3. **Script deploys stack with `docker stack deploy -c swarm/stack.yaml names-app`**
   - Changes to src/ directory
   - Deploys stack with correct file path
   - Handles both new deployments and updates

4. **Script waits for all services to be running (timeout: 2 minutes)**
   - Polls service status every 5 seconds
   - Checks replicas are ready (e.g., "1/1")
   - Shows progress for each service

5. **Script shows service status after deployment**
   - Displays `docker stack services` output
   - Shows service placement with `docker stack ps`
   - Clear formatting and colors

6. **Script displays frontend URL (http://localhost or manager IP)**
   - Shows multiple access URLs
   - Includes health check endpoints
   - Provides monitoring commands

7. **Script has --update flag to redeploy existing stack**
   - `--update` flag forces redeployment
   - Works even if stack already exists
   - Updates services with new configuration

8. **Exit codes: 0=success, 1=error, 2=timeout**
   - Proper exit codes throughout
   - Can be used in automation

### Additional Features

- **--build flag**: Build Docker images before deploying
- **--help flag**: Comprehensive usage documentation
- **Image validation**: Checks if required images exist
- **Color-coded output**: Green (success), Red (error), Yellow (warning), Blue (info)
- **Progress indicators**: Clear status messages for each step
- **Idempotent**: Safe to run multiple times

## Usage

### Basic Usage

```bash
# Prerequisites: Swarm initialized, images built
./ops/deploy.sh

# Expected output:
# - Checks Swarm status (2+ nodes)
# - Validates .env file
# - Checks required environment variables
# - Verifies Docker images exist
# - Deploys stack
# - Waits for services to be ready
# - Shows deployment status
# - Displays access information
```

### With Options

```bash
# Show help
./ops/deploy.sh --help

# Build images and deploy
./ops/deploy.sh --build

# Update existing stack
./ops/deploy.sh --update

# Combine options
./ops/deploy.sh --build --update
```

## Complete Deployment Workflow

### Step 1: Initialize Swarm (if not done)

```bash
./ops/init-swarm.sh

# Output shows:
# ✅ Swarm initialized
# ✅ Worker joined
# ✅ Storage created
```

### Step 2: Prepare Environment

```bash
# Copy and configure .env file
cd src
cp .env.example .env
# Edit .env with your settings
cd ..
```

### Step 3: Build Images

```bash
# Option A: Build manually
cd src
docker build -t names-manager-backend:latest ./backend
docker build -t names-manager-frontend:latest ./frontend
cd ..

# Option B: Use --build flag
./ops/deploy.sh --build
```

### Step 4: Deploy Stack

```bash
./ops/deploy.sh

# Expected output:
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🚀 Docker Swarm Stack Deployment
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# ℹ️  Checking Docker Swarm status...
# ✅ Docker Swarm is active with 2 nodes
#
# ℹ️  Checking required files...
# ✅ Stack file found: src/swarm/stack.yaml
# ✅ .env file found: src/.env
#
# ℹ️  Validating environment variables...
# ✅ All required environment variables are set
#
# ℹ️  Checking Docker images...
# ✅ Required Docker images are available
#
# ℹ️  Deploying new stack: names-app
#
# Creating network names-app_appnet
# Creating service names-app_db
# Creating service names-app_backend
# Creating service names-app_frontend
#
# ✅ Stack deployment command executed successfully
#
# ℹ️  Waiting for services to be ready (timeout: 120s)...
#
#   Waiting for names-app_db... (0/1)
#   Waiting for names-app_backend... (0/1)
#   Waiting for names-app_frontend... (0/1)
#   ...
#
# ✅ All services are ready!
#
# ℹ️  Deployment Status:
#
# Stack Services:
# ID            NAME                    MODE        REPLICAS   IMAGE
# abc123...     names-app_frontend      replicated  1/1        names-manager-frontend:latest
# def456...     names-app_backend       replicated  1/1        names-manager-backend:latest
# ghi789...     names-app_db            replicated  1/1        postgres:15
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🎉 Deployment Complete!
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# 📍 Application Access:
#    Frontend:  http://localhost
#    Frontend:  http://192.168.56.1
#
# 🔍 Health Checks:
#    API Health:   http://localhost/api/health
#    DB Health:    http://localhost/api/health/db
#    Swarm Health: http://localhost/healthz
#
# 📊 Monitoring Commands:
#    Service status:   docker stack services names-app
#    Service logs:     docker service logs names-app
#    Service details:  docker stack ps names-app
```

## Testing Scenarios

### Scenario 1: Fresh Deployment

```bash
# Prerequisites: Swarm initialized, images built, .env configured

./ops/deploy.sh

# Expected behavior:
# ✅ All checks pass
# ✅ Stack deployed successfully
# ✅ Services become ready within 2 minutes
# ✅ Exit code 0
```

### Scenario 2: Update Existing Stack

```bash
# Prerequisites: Stack already deployed

# Make changes to stack.yaml or rebuild images
docker build -t names-manager-backend:latest ./backend

# Deploy update
./ops/deploy.sh --update

# Expected behavior:
# ✅ Detects existing stack
# ✅ Updates with new configuration
# ✅ Services restart with new images
# ✅ Exit code 0
```

### Scenario 3: Build and Deploy

```bash
# Prerequisites: Swarm initialized, .env configured

./ops/deploy.sh --build

# Expected behavior:
# ✅ Builds backend image
# ✅ Builds frontend image
# ✅ Deploys stack
# ✅ Exit code 0
```

### Scenario 4: Deploy Without Images

```bash
# Prerequisites: Images not built

./ops/deploy.sh

# Expected behavior:
# ❌ ERROR: Missing Docker images
# Exit code: 1
# Suggestion: Build images or use --build flag
```

### Scenario 5: Deploy Without Swarm

```bash
# Prerequisites: Swarm not initialized

./ops/deploy.sh

# Expected behavior:
# ❌ ERROR: Docker Swarm is not initialized
# Exit code: 1
# Suggestion: Run ./ops/init-swarm.sh
```

## Error Handling

The script handles various error conditions:

### Swarm Not Initialized

```bash
./ops/deploy.sh

# Output:
# ❌ ERROR: Docker Swarm is not initialized. Run: ./ops/init-swarm.sh
# Exit code: 1
```

### Missing .env File

```bash
./ops/deploy.sh

# Output:
# ❌ ERROR: .env file not found: src/.env. Copy from .env.example and configure.
# Exit code: 1
```

### Missing Environment Variables

```bash
./ops/deploy.sh

# Output:
# ❌ ERROR: Missing required environment variables: POSTGRES_PASSWORD DB_URL
# Exit code: 1
```

### Missing Docker Images

```bash
./ops/deploy.sh

# Output:
# ❌ ERROR: Missing Docker images: names-manager-backend:latest names-manager-frontend:latest
# Exit code: 1
```

### Service Timeout

```bash
./ops/deploy.sh

# If services don't start within 2 minutes:
# ❌ ERROR: Timeout waiting for services to be ready after 120s
# Exit code: 2
```

## Manual Verification

After deployment, verify manually:

```bash
# Check stack status
docker stack ls

# Expected:
# NAME        SERVICES   ORCHESTRATOR
# names-app   3          Swarm

# Check services
docker stack services names-app

# Expected:
# ID          NAME                MODE      REPLICAS   IMAGE
# ...         names-app_frontend  replicated 1/1       names-manager-frontend:latest
# ...         names-app_backend   replicated 1/1       names-manager-backend:latest
# ...         names-app_db        replicated 1/1       postgres:15

# Check service placement
docker stack ps names-app

# Verify frontend is accessible
curl -I http://localhost
# Expected: HTTP/1.1 200 OK

# Check health endpoints
curl http://localhost/api/health | jq
curl http://localhost/healthz | jq
```

## Monitoring and Logs

```bash
# View all service logs
docker service logs names-app_frontend
docker service logs names-app_backend
docker service logs names-app_db

# Follow logs in real-time
docker service logs -f names-app_backend

# View recent logs
docker service logs --tail 50 names-app_backend

# Check service details
docker service inspect names-app_backend --pretty

# Check service tasks
docker service ps names-app_backend --no-trunc
```

## Updating the Application

```bash
# 1. Make code changes
vim src/backend/main.py

# 2. Rebuild image
cd src
docker build -t names-manager-backend:latest ./backend
cd ..

# 3. Deploy update
./ops/deploy.sh --update

# Docker Swarm performs rolling update automatically
```

## Troubleshooting

### Services Not Starting

```bash
# Check service logs
docker service logs names-app_db
docker service logs names-app_backend

# Check task failures
docker service ps names-app_backend --no-trunc

# Check events
docker events --filter 'type=service' --since 10m
```

### Database Connection Issues

```bash
# Verify database is running
docker service ps names-app_db

# Check database logs
docker service logs names-app_db

# Test database health
docker service logs names-app_backend | grep -i database
```

### Port 80 Not Accessible

```bash
# Check if frontend is running
docker service ps names-app_frontend

# Check frontend logs
docker service logs names-app_frontend

# Verify ingress network
docker network inspect ingress

# Test from manager node
curl -v http://localhost
```

## Performance Expectations

- **Fresh deployment**: 1-2 minutes (including image pull and service start)
- **Update deployment**: 30-60 seconds (rolling update)
- **Build and deploy**: 3-5 minutes (includes image build)
- **Service readiness check**: Typically 30-45 seconds

## Integration with Other Scripts

The deploy.sh script is the second step in the deployment workflow:

```bash
# 1. Initialize cluster
./ops/init-swarm.sh

# 2. Deploy application
./ops/deploy.sh

# 3. Verify deployment (Task 3.5 - to be implemented)
./ops/verify.sh

# 4. Access application
open http://localhost

# 5. Monitor logs
docker service logs -f names-app_backend

# 6. Cleanup (when needed)
./ops/cleanup.sh
```

## See Also

- [init-swarm.sh Testing Guide](./INIT_SWARM_TESTING.md)
- [Stack Configuration](../src/swarm/README.md)
- [Docker Stack Documentation](https://docs.docker.com/engine/reference/commandline/stack/)
