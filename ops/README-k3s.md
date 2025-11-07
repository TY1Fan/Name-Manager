# Operations Scripts - k3s

This directory contains helper scripts for managing the Names Manager application on k3s.

## Scripts Overview

### deploy-k3s.sh
**Purpose**: Full automated deployment of the application to k3s

**Usage**:
```bash
./ops/deploy-k3s.sh
```

**What it does**:
1. Verifies kubectl connection to k3s cluster
2. Creates namespace and configuration (ConfigMap, Secret)
3. Deploys database (PVC, StatefulSet, Service)
4. Deploys backend (Deployment, Service)
5. Deploys frontend (Deployment, Service)
6. Deploys HorizontalPodAutoscaler (if manifest exists)
7. Waits for all components to be ready
8. Displays deployment status and access URL

**Output**: Shows status and provides the application URL

---

### cleanup-k3s.sh
**Purpose**: Remove all application resources from k3s

**Usage**:
```bash
./ops/cleanup-k3s.sh
```

**What it does**:
1. Prompts for confirmation
2. Deletes HPA (if exists)
3. Deletes frontend deployment and service
4. Deletes backend deployment and service
5. Deletes database StatefulSet and service
6. Optionally deletes PVC (prompts for confirmation - **deletes all data!**)
7. Deletes ConfigMap and Secret
8. Optionally deletes entire namespace (prompts for confirmation)

**⚠️ Warning**: Deleting the PVC will permanently delete all database data!

---

### update-k3s.sh
**Purpose**: Build, transfer, and deploy updated container images

**Usage**:
```bash
# Update both backend and frontend
./ops/update-k3s.sh

# Update only backend
./ops/update-k3s.sh backend

# Update only frontend
./ops/update-k3s.sh frontend
```

**What it does**:
1. Builds new Docker image(s) locally
2. Saves image to tar archive
3. Transfers tar to k3s-server VM via SCP
4. Imports image into k3s containerd runtime
5. Triggers rolling restart of deployment
6. Waits for rollout to complete
7. Shows updated pod status

**Prerequisites**:
- Docker installed locally
- SSH access to vagrant@192.168.56.10 (k3s-server)
- Source code in `src/backend/` and `src/frontend/`

---

## Prerequisites

All scripts require:
- kubectl configured with k3s cluster access
- kubectl port forwarding active: `127.0.0.1:6443 -> 192.168.56.10:6443`
- k3s cluster running (k3s-server and k3s-agent VMs)

Additional requirements for `update-k3s.sh`:
- Docker installed on local machine
- SSH access to k3s-server VM
- Vagrant VMs running

## Quick Start

### Initial Deployment
```bash
# Deploy everything
./ops/deploy-k3s.sh

# Access application
# URL will be shown in output (typically http://localhost:30080)
```

### Update Application
```bash
# After making code changes
./ops/update-k3s.sh backend    # Update backend only
./ops/update-k3s.sh frontend   # Update frontend only
./ops/update-k3s.sh            # Update both
```

### Complete Cleanup
```bash
# Remove everything (will prompt for confirmations)
./ops/cleanup-k3s.sh
```

## Common Workflows

### Development Cycle
1. Make code changes in `src/backend/` or `src/frontend/`
2. Run `./ops/update-k3s.sh [component]`
3. Test changes at http://localhost:30080
4. Repeat as needed

### Fresh Deployment
```bash
# If application is already deployed, clean it up first
./ops/cleanup-k3s.sh

# Deploy from scratch
./ops/deploy-k3s.sh
```

### Disaster Recovery
```bash
# Quick restart without rebuilding images
kubectl rollout restart deployment/backend -n names-app
kubectl rollout restart deployment/frontend -n names-app

# Or use the cleanup and redeploy approach
./ops/cleanup-k3s.sh
./ops/deploy-k3s.sh
```

## Manual Commands

If you prefer manual control, see [docs/OPERATIONS.md](../docs/OPERATIONS.md) for detailed kubectl commands.

## Troubleshooting

### Script fails with "Cannot connect to k3s cluster"
- Verify VMs are running: `vagrant status`
- Check kubectl config: `kubectl cluster-info`
- Verify port forwarding is active

### update-k3s.sh fails with SSH errors
- Verify k3s-server VM is running: `vagrant status`
- Test SSH: `ssh vagrant@192.168.56.10`
- Check SSH keys: `vagrant ssh k3s-server` should work

### Deployment hangs waiting for pods
- Check pod status: `kubectl get pods -n names-app`
- View pod logs: `kubectl logs -n names-app <pod-name>`
- Check events: `kubectl get events -n names-app --sort-by='.lastTimestamp'`

## Docker Swarm Scripts

The original Docker Swarm scripts are preserved with their original names:
- `deploy.sh` - Docker Swarm deployment
- `cleanup.sh` - Docker Swarm cleanup (now replaced with cleanup-k3s.sh for k3s)
- `init-swarm.sh` - Docker Swarm initialization
- `verify.sh` - Docker Swarm verification
- `validate.sh` - Docker Swarm validation

**Note**: Use the `-k3s.sh` suffix scripts for k3s operations.

---

**Last Updated**: 2025-11-05  
**Target**: k3s v1.33.5+k3s1  
**Application**: Names Manager
