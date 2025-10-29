# Quickstart Single Host Guide

1. Clone the repository with `https://github.com/TY1Fan/Name-Manager.git`
1. Change directory into src with `cd src`. Check that docker compose is in the same directory that you are currently in
1. Create environment file `cp .env.example .env` and edit configuration if you want to customise the configurations
1. Run `docker compose up`
1. Search in browser `http://localhost:8080/`

# Docker Swarm Deployment - Quick Start Guide

**Get the Names Manager application running in a Docker Swarm cluster in under 5 minutes!**

This guide will help you deploy the Names Manager application across multiple nodes using Docker Swarm orchestration. Perfect for learning distributed systems, testing production-like deployments, or running on multiple machines.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start (5 Minutes)](#quick-start-5-minutes)
3. [Architecture Overview](#architecture-overview)
4. [Verification Steps](#verification-steps)
5. [Switching Between Compose and Swarm](#switching-between-compose-and-swarm)
6. [Common Troubleshooting](#common-troubleshooting)
7. [Next Steps](#next-steps)

---

## Prerequisites

Before you begin, ensure you have:

### Required Software

- ✅ **macOS** 10.15 or later (host machine)
- ✅ **Docker Desktop** installed and running
- ✅ **Vagrant** 2.2 or later (`brew install vagrant`)
- ✅ **VirtualBox** 6.1 or later (`brew install --cask virtualbox`)
- ✅ **Git** (to clone the repository)

### Quick Installation Check

```bash
# Verify all prerequisites
docker --version          # Should show Docker version 20+
vagrant --version         # Should show Vagrant 2.2+
VBoxManage --version      # Should show VirtualBox 6.1+
```

### System Requirements

- **Disk Space**: ~5 GB available (for VM and images)
- **Memory**: 4 GB RAM recommended (2 GB allocated to VM)
- **Network**: Internet connection for initial setup

---

## Quick Start (5 Minutes)

Follow these steps to get your Swarm cluster up and running:

### Step 1: Navigate to Project Directory

```bash
cd /path/to/HW_3
```

### Step 2: Initialize the Swarm Cluster

This command starts the Vagrant VM and sets up a 2-node Swarm cluster:

```bash
./ops/init-swarm.sh
```

**What this does:**
- ✅ Starts Vagrant VM (Ubuntu 22.04) on `192.168.56.10`
- ✅ Initializes Swarm on your Mac (manager node)
- ✅ Joins VM as worker node
- ✅ Creates persistent storage directory for database
- ✅ Verifies cluster is ready

**Expected output:**
```
🚀 Initializing Docker Swarm Cluster...
✓ Docker is installed and running
✓ Vagrant is installed
✓ VirtualBox is installed
⏳ Starting Vagrant VM...
✓ Vagrant VM is running
✓ Swarm initialized on manager node (192.168.56.1)
✓ Worker node joined successfully
✓ Cluster has 2 nodes (1 manager, 1 worker)
✅ Swarm cluster initialization complete!
```

**Time:** ~2 minutes

---

### Step 3: Deploy the Application Stack

Deploy all services (frontend, backend, database) to the cluster:

```bash
./ops/deploy.sh
```

**What this does:**
- ✅ Validates environment configuration
- ✅ Deploys 3 services using `stack.yaml`
- ✅ Waits for all services to become healthy
- ✅ Shows deployment status

**Expected output:**
```
🚀 Deploying Names Manager Stack to Swarm...
✓ Docker Swarm is active
✓ Cluster has 2 nodes
✓ Environment file loaded
✓ Stack deployed successfully
⏳ Waiting for services to be ready...
✓ All services are ready!

📊 Deployment Status:
  names-app_frontend    1/1 replicas
  names-app_backend     1/1 replicas
  names-app_db          1/1 replicas

✅ Deployment complete!
🌐 Access the application at: http://localhost
```

**Time:** ~2 minutes

---

### Step 4: Verify Everything Works

Run the comprehensive verification script:

```bash
./ops/verify.sh
```

**What this checks:**
- ✅ Swarm cluster health (2 nodes active)
- ✅ All services running with correct replicas
- ✅ Service placement (database on worker, app on manager)
- ✅ Database connectivity
- ✅ Backend API health endpoint
- ✅ Frontend web server
- ✅ Cross-node service discovery

**Expected output:**
```
🔍 Verifying Names Manager Swarm Deployment...

✅ PASS: Docker Swarm is active
✅ PASS: Cluster has 2 nodes
✅ PASS: Stack 'names-app' exists with 3 services
✅ PASS: All service replicas are ready (3/3)
✅ PASS: Database is on worker node
✅ PASS: Backend is on manager node
✅ PASS: Database health check passed
✅ PASS: Backend health check passed (200 OK)
✅ PASS: Frontend is accessible (200 OK)
✅ PASS: Cross-node service discovery working

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Verification Summary: 10/10 checks passed ✅
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Time:** ~30 seconds

---

### Step 5: Use the Application! 🎉

Open your browser and navigate to:

**http://localhost**

You now have a fully functioning distributed application running across two nodes!

**Try it out:**
1. Add some names through the web interface
2. Check that they persist
3. The data is stored on the worker node's persistent volume
4. Frontend and backend run on your Mac (manager node)
5. Database runs on the Vagrant VM (worker node)

---

## Architecture Overview

Understanding the deployment architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Swarm Cluster                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────┐    ┌──────────────────────────┐   │
│  │  Manager Node           │    │  Worker Node             │   │
│  │  (Your Mac)             │    │  (Vagrant VM)            │   │
│  │  192.168.56.1           │    │  192.168.56.10           │   │
│  │                         │    │                          │   │
│  │  ┌──────────────────┐  │    │  ┌────────────────────┐ │   │
│  │  │  Frontend        │◄─┼────┼─►│                     │ │   │
│  │  │  nginx:alpine    │  │    │  │  Database           │ │   │
│  │  │  Port 80         │  │    │  │  PostgreSQL 15      │ │   │
│  │  └──────────────────┘  │    │  │  Port 5432          │ │   │
│  │           │             │    │  └──────────┬──────────┘ │   │
│  │           ▼             │    │             │            │   │
│  │  ┌──────────────────┐  │    │             ▼            │   │
│  │  │  Backend         │  │    │  ┌────────────────────┐ │   │
│  │  │  Flask/Gunicorn  │  │    │  │  Persistent Volume │ │   │
│  │  │  Port 8000       │  │    │  │  /var/lib/         │ │   │
│  │  └──────────────────┘  │    │  │  postgres-data     │ │   │
│  │           │             │    │  └────────────────────┘ │   │
│  └───────────┼─────────────┘    └───────────┬─────────────┘   │
│              │                               │                 │
│              └───────────────────────────────┘                 │
│                  Overlay Network (appnet)                      │
│                  Encrypted, Attachable                         │
└─────────────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions

**Service Placement:**
- **Frontend + Backend on Manager**: Low latency, direct communication
- **Database on Worker**: Simulates production separation, persistent storage

**Networking:**
- **Overlay Network**: Encrypted multi-host networking
- **Port Publishing**: Only port 80 exposed to host
- **Service Discovery**: Automatic DNS resolution between services

**Storage:**
- **Persistent Volume**: Database data survives stack redeployment
- **Bind Mount**: `/var/lib/postgres-data` on worker VM
- **Backup Folder**: `./backups` synced between host and VM

---

## Verification Steps

### Manual Verification (Alternative to verify.sh)

If you prefer to check manually:

#### 1. Check Cluster Nodes
```bash
docker node ls
```
Expected: 2 nodes (1 manager, 1 worker), both "Ready" and "Active"

#### 2. Check Services
```bash
docker service ls
```
Expected: 3 services, all showing "1/1" replicas

#### 3. Check Service Logs
```bash
# Check backend logs
docker service logs names-app_backend --tail 50

# Check database logs
docker service logs names-app_db --tail 50

# Check frontend logs
docker service logs names-app_frontend --tail 50
```

#### 4. Test API Directly
```bash
# Health check
curl http://localhost:8000/healthz

# List names
curl http://localhost:8000/api/names

# Add a name
curl -X POST http://localhost:8000/api/names \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User"}'
```

#### 5. Verify Service Placement
```bash
# Should show database container on worker node (192.168.56.10)
docker service ps names-app_db

# Should show frontend/backend on manager node (192.168.56.1)
docker service ps names-app_frontend
docker service ps names-app_backend
```

---

## Switching Between Compose and Swarm

The project supports both deployment methods:

### When to Use Docker Compose (Local Development)

**Use Case:** Quick local development, testing changes, debugging

**Advantages:**
- ✅ Faster startup (no multi-node setup)
- ✅ Simpler logs and debugging
- ✅ No VM overhead
- ✅ Direct file system access

**How to Use:**
```bash
cd src
docker-compose up -d
```

**Access:** http://localhost

**Stop:**
```bash
docker-compose down
```

---

### When to Use Docker Swarm (Production-Like)

**Use Case:** Learning distributed systems, testing HA, production deployments

**Advantages:**
- ✅ Multi-node orchestration
- ✅ Service replication and scaling
- ✅ Rolling updates and rollbacks
- ✅ Production-like environment
- ✅ Load balancing across nodes

**How to Use:**
```bash
./ops/init-swarm.sh   # One-time setup
./ops/deploy.sh       # Deploy
```

**Access:** http://localhost

**Stop:**
```bash
./ops/cleanup.sh      # Keep cluster
./ops/cleanup.sh --full  # Remove everything
```

---

### Switching Between Them

**From Compose to Swarm:**
```bash
# Stop Compose
cd src && docker-compose down

# Start Swarm (if not already initialized)
cd .. && ./ops/init-swarm.sh
./ops/deploy.sh
```

**From Swarm to Compose:**
```bash
# Stop Swarm (keeps cluster for next time)
./ops/cleanup.sh --stack-only

# Or completely tear down Swarm
./ops/cleanup.sh --full

# Start Compose
cd src && docker-compose up -d
```

**Important Notes:**
- ✅ Both use the same codebase and configuration
- ✅ Database data is separate (different volumes)
- ✅ You can switch freely without code changes
- ⚠️ Don't run both simultaneously (port 80 conflict)

---

## Common Troubleshooting

### Issue 1: "Port 80 already in use"

**Symptoms:**
```
Error response from daemon: driver failed programming external connectivity
```

**Solutions:**
```bash
# Check if Compose is still running
cd src && docker-compose ps
docker-compose down  # If services are running

# Check for other services on port 80
sudo lsof -i :80

# Or use a different port in stack.yaml
```

---

### Issue 2: Services Not Starting

**Symptoms:**
- `docker service ls` shows 0/1 replicas
- Services stuck in "Pending" state

**Diagnosis:**
```bash
# Check service status
docker service ps names-app_backend --no-trunc

# Check service logs
docker service logs names-app_backend
```

**Common Causes:**
- Environment variables not set (check `.env` file)
- Image not available on worker node
- Port conflicts
- Resource constraints (check VM memory)

**Solutions:**
```bash
# Rebuild and redeploy
./ops/deploy.sh --build --update

# Check worker node resources
vagrant ssh -c "free -h"
vagrant ssh -c "df -h"
```

---

### Issue 3: Vagrant VM Won't Start

**Symptoms:**
```
VBoxManage: error: Failed to open a session
```

**Solutions:**
```bash
# Check VirtualBox is running
VBoxManage list runningvms

# Restart VirtualBox service (macOS)
sudo /Library/Application\ Support/VirtualBox/LaunchDaemons/VirtualBoxStartup.sh restart

# Destroy and recreate VM
cd vagrant
vagrant destroy -f
vagrant up
```

---

### Issue 4: "Database Connection Failed"

**Symptoms:**
- Backend health check fails
- API returns 503 errors
- Can't add names

**Diagnosis:**
```bash
# Check database service
docker service ps names-app_db

# Check database logs
docker service logs names-app_db --tail 100

# Test database connection from manager
docker run --rm --network names-app_appnet postgres:15-alpine \
  pg_isready -h db -p 5432
```

**Solutions:**
```bash
# Restart database service
docker service update --force names-app_db

# Check database container on worker
vagrant ssh -c "docker ps | grep postgres"

# Verify persistent storage
vagrant ssh -c "ls -la /var/lib/postgres-data"
```

---

### Issue 5: Worker Node Not Joining Swarm

**Symptoms:**
```
docker node ls  # Shows only 1 node
```

**Diagnosis:**
```bash
# Check Swarm status on manager
docker info | grep Swarm

# Check worker node Docker status
vagrant ssh -c "docker info | grep Swarm"

# Check network connectivity
ping 192.168.56.10
vagrant ssh -c "ping -c 3 192.168.56.1"
```

**Solutions:**
```bash
# Reinitialize Swarm with force flag
./ops/init-swarm.sh --force

# Or manually rejoin worker
# On manager, get join token:
docker swarm join-token worker

# On worker:
vagrant ssh
# Run the join command shown above
```

---

### Issue 6: Can't Access Application at http://localhost

**Symptoms:**
- Browser shows "Connection refused" or "Can't reach this page"

**Diagnosis:**
```bash
# Check if frontend service is running
docker service ps names-app_frontend

# Check if port 80 is published
docker service inspect names-app_frontend --format '{{.Endpoint.Ports}}'

# Test from command line
curl -v http://localhost
```

**Solutions:**
```bash
# Verify service is on manager node
docker service ps names-app_frontend

# Restart frontend service
docker service update --force names-app_frontend

# Check Docker Desktop is running
# Check firewall isn't blocking port 80
```

---

### Getting Help

If you encounter issues not covered here:

1. **Check Detailed Logs:**
   ```bash
   docker service logs names-app_backend --tail 200 --follow
   ```

2. **Run Full Verification:**
   ```bash
   ./ops/verify.sh --verbose
   ```

3. **Check Documentation:**
   - `vagrant/VAGRANT_SETUP.md` - Vagrant-specific issues
   - `src/swarm/README.md` - Swarm configuration details
   - `specs/001-swarm-orchestration/TESTING.md` - Testing procedures

4. **Clean Slate:**
   ```bash
   ./ops/cleanup.sh --full
   ./ops/init-swarm.sh
   ./ops/deploy.sh
   ```

---

## Next Steps

### Learn More

**Explore the Codebase:**
- `src/swarm/stack.yaml` - Service definitions and configuration
- `ops/` - Automation scripts with detailed comments
- `vagrant/` - VM configuration and setup

**Read Detailed Documentation:**
- `vagrant/VAGRANT_SETUP.md` - Complete Vagrant guide (storage, networking, troubleshooting)
- `src/swarm/README.md` - Swarm architecture and deployment details
- `specs/001-swarm-orchestration/TESTING.md` - Comprehensive testing procedures

**Run Automated Tests:**
```bash
# Run full end-to-end test suite
./ops/test-e2e.sh

# Run quick smoke tests only
./ops/test-e2e.sh --quick
```

---

### Experiment with the Cluster

**Scale Services:**
```bash
# Scale backend to 2 replicas
docker service scale names-app_backend=2

# Scale back to 1
docker service scale names-app_backend=1
```

**Rolling Updates:**
```bash
# Update backend with new image
docker service update \
  --image names-manager-backend:v2 \
  names-app_backend
```

**Inspect Service Details:**
```bash
# View service configuration
docker service inspect names-app_backend --pretty

# View service logs in real-time
docker service logs names-app_backend --follow
```

**Database Backups:**
```bash
# Manual backup
./vagrant/backup.sh

# Restore from backup
# Instructions shown by backup script
```

---

### Production Considerations

If you're planning to use this in production:

1. **Security:**
   - Use Docker secrets for sensitive data
   - Enable TLS for Swarm communication
   - Restrict network access
   - Update `.env` with strong passwords

2. **High Availability:**
   - Use 3+ manager nodes (odd number)
   - Multiple worker nodes
   - Replicate services (e.g., `replicas: 3`)

3. **Monitoring:**
   - Add Prometheus for metrics
   - Set up alerting
   - Monitor disk space on worker nodes

4. **Backups:**
   - Automate database backups (see `vagrant/backup.sh`)
   - Test restore procedures
   - Off-site backup storage

5. **Updates:**
   - Use tagged images (not `latest`)
   - Test updates in staging
   - Plan rollback procedures

---

## Quick Command Reference

```bash
# Initialization
./ops/init-swarm.sh              # Set up cluster
./ops/init-swarm.sh --force      # Reinitialize cluster

# Deployment
./ops/deploy.sh                  # Deploy stack
./ops/deploy.sh --build          # Rebuild images first
./ops/deploy.sh --update         # Update existing stack

# Verification
./ops/verify.sh                  # Run all checks
./ops/verify.sh --verbose        # Show detailed output
./ops/verify.sh --quick          # Skip slow checks

# Cleanup
./ops/cleanup.sh                 # Remove stack, keep cluster
./ops/cleanup.sh --stack-only    # Remove stack only
./ops/cleanup.sh --full          # Complete teardown

# Testing
./ops/test-e2e.sh               # Full test suite
./ops/test-e2e.sh --quick       # Quick tests only

# Backup
./vagrant/backup.sh             # Backup database

# Vagrant Management
cd vagrant
vagrant up                      # Start VM
vagrant halt                    # Stop VM
vagrant reload                  # Restart VM
vagrant ssh                     # SSH into VM
vagrant destroy                 # Delete VM

# Docker Swarm Commands
docker node ls                  # List cluster nodes
docker service ls               # List services
docker stack ps names-app       # List stack containers
docker service logs <service>   # View logs
```

---

## Summary

You now have a fully functional Docker Swarm cluster! 🎉

**What You've Achieved:**
- ✅ Multi-node Docker Swarm cluster (manager + worker)
- ✅ Distributed application deployment
- ✅ Service orchestration and placement constraints
- ✅ Persistent data storage
- ✅ Automated deployment and verification

**Time to Deploy:** ~5 minutes
**Infrastructure:** 2-node cluster (Mac + Vagrant VM)
**Services:** Frontend, Backend, Database
**Access:** http://localhost

**Happy clustering! 🚀**

---

*For detailed technical documentation, see:*
- *Full Setup Guide: `vagrant/VAGRANT_SETUP.md`*
- *Architecture Details: `src/swarm/README.md`*
- *Testing Procedures: `specs/001-swarm-orchestration/TESTING.md`*