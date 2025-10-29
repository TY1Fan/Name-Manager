# init-swarm.sh Testing Guide

This document describes the `init-swarm.sh` script and how to test it.

## Script Overview

**Location**: `ops/init-swarm.sh`  
**Purpose**: Initialize Docker Swarm cluster with manager and worker nodes  
**Status**: ✅ Complete and ready to use

## Features Implemented

### ✅ All Acceptance Criteria Met

1. **Script checks for required tools (vagrant, docker)**
   - Checks if Docker is installed and running
   - Checks if Vagrant is installed (unless --skip-vagrant)
   - Checks if VirtualBox is installed
   - Checks if vagrant directory exists

2. **Script starts Vagrant VM if not running**
   - Detects VM status (running, poweroff, saved, not_created)
   - Starts or creates VM as needed
   - Waits for VM to be fully ready
   - Tests SSH connectivity
   - Verifies Docker is running in VM

3. **Script initializes Swarm with correct advertise address (192.168.56.1)**
   - Uses `docker swarm init --advertise-addr 192.168.56.1`
   - Configures manager node correctly

4. **Script joins worker VM to Swarm cluster**
   - Gets worker join token from manager
   - Executes join command on worker via SSH
   - Handles cases where worker is already in a swarm

5. **Script verifies both nodes are Ready**
   - Checks node count (expects 2)
   - Verifies manager node status
   - Verifies worker node status
   - Displays cluster information

6. **Script is idempotent (doesn't fail if Swarm already initialized)**
   - Detects if Swarm already exists
   - Returns exit code 2 if already initialized
   - Can use --force to re-initialize

7. **Script provides clear success/failure messages**
   - Color-coded output (green=success, red=error, yellow=warning, blue=info)
   - Progress indicators for each step
   - Clear error messages with resolution hints
   - Next steps displayed on success

8. **Script includes usage instructions (--help flag)**
   - Comprehensive help documentation
   - Examples provided
   - Option descriptions

9. **Exit codes: 0=success, 1=error, 2=already initialized**
   - Proper exit codes throughout
   - Can be used in automation scripts

### Additional Features

- **--force flag**: Re-initialize even if Swarm exists
- **--skip-vagrant flag**: Skip VM startup (use existing VM)
- **Persistent storage setup**: Creates /var/lib/postgres-data on worker
- **Proper permissions**: Sets ownership to 999:999 (postgres user)
- **Network verification**: Tests connectivity between nodes
- **Helpful next steps**: Shows commands to run after initialization

## Usage

### Basic Usage

```bash
# Initialize the cluster (first time)
./ops/init-swarm.sh

# Expected output:
# - Checks prerequisites
# - Starts Vagrant VM
# - Initializes Swarm on manager
# - Joins worker to cluster
# - Creates storage directory
# - Verifies cluster status
# - Shows next steps
```

### With Options

```bash
# Show help
./ops/init-swarm.sh --help

# Force re-initialization
./ops/init-swarm.sh --force

# Use existing VM (don't start/check Vagrant)
./ops/init-swarm.sh --skip-vagrant

# Combine options
./ops/init-swarm.sh --force --skip-vagrant
```

## Testing Scenarios

### Scenario 1: Fresh Installation

```bash
# Prerequisites: Vagrant, VirtualBox, Docker installed
# VM doesn't exist yet

./ops/init-swarm.sh

# Expected behavior:
# ✅ Checks prerequisites
# ✅ Creates and starts Vagrant VM
# ✅ Initializes Swarm (exit 0)
# ✅ Shows cluster status
```

### Scenario 2: Already Initialized

```bash
# Run after Scenario 1

./ops/init-swarm.sh

# Expected behavior:
# ✅ Detects existing Swarm
# ✅ Shows current cluster status
# ✅ Exits with code 2 (already initialized)
# ℹ️ Suggests using --force to re-initialize
```

### Scenario 3: Force Re-initialization

```bash
./ops/init-swarm.sh --force

# Expected behavior:
# ✅ Leaves existing Swarm
# ✅ Re-initializes from scratch
# ✅ Re-joins worker node
# ✅ Exits with code 0
```

### Scenario 4: VM Already Running

```bash
# Prerequisites: VM is already running from previous init

./ops/init-swarm.sh

# Expected behavior:
# ✅ Detects VM is running
# ✅ Skips VM startup
# ✅ Continues with Swarm initialization
```

### Scenario 5: Skip Vagrant Flag

```bash
# Prerequisites: VM manually started or using physical server

./ops/init-swarm.sh --skip-vagrant

# Expected behavior:
# ✅ Skips Vagrant checks
# ✅ Skips VM startup
# ✅ Initializes Swarm and joins worker
```

## Error Handling

The script handles various error conditions:

### Docker Not Running

```bash
# If Docker daemon is not running
./ops/init-swarm.sh

# Output:
# ❌ ERROR: Docker daemon is not running. Please start Docker Desktop.
# Exit code: 1
```

### Vagrant Not Installed

```bash
# If Vagrant is not installed
./ops/init-swarm.sh

# Output:
# ❌ ERROR: Vagrant is not installed. Install with: brew install vagrant
# Exit code: 1
```

### VM Cannot Start

```bash
# If VM fails to start
./ops/init-swarm.sh

# Output:
# ❌ ERROR: Failed to start Vagrant VM
# Exit code: 1
```

### Network Issues

```bash
# If manager cannot reach worker
./ops/init-swarm.sh

# Output:
# ❌ ERROR: Failed to join worker node to Swarm
# Exit code: 1
```

## Manual Verification

After running the script, verify the cluster manually:

```bash
# Check cluster status
docker node ls

# Expected output:
# ID            HOSTNAME       STATUS    AVAILABILITY   MANAGER STATUS
# abc123...     <hostname>     Ready     Active         Leader
# def456...     swarm-worker   Ready     Active

# Check Swarm info
docker info | grep -A 5 "Swarm:"

# Test SSH to worker
cd vagrant
vagrant ssh -c "docker info | grep -A 3 'Swarm:'"
cd ..

# Verify storage directory on worker
cd vagrant
vagrant ssh -c "ls -la /var/lib/postgres-data"
cd ..
```

## Cleanup (If Needed)

To completely reset the cluster:

```bash
# Leave Swarm on manager
docker swarm leave --force

# Stop and destroy VM
cd vagrant
vagrant destroy -f
cd ..

# Now you can run init-swarm.sh again for a fresh start
```

## Integration with Other Scripts

The init-swarm.sh script is the first step in the deployment workflow:

```bash
# 1. Initialize cluster
./ops/init-swarm.sh

# 2. Build images (as shown in script output)
cd src
docker build -t names-manager-backend:latest ./backend
docker build -t names-manager-frontend:latest ./frontend
cd ..

# 3. Deploy stack (Task 3.4 - to be implemented)
./ops/deploy.sh

# 4. Verify deployment (Task 3.5 - to be implemented)
./ops/verify.sh

# 5. Access application
open http://localhost
```

## Script Architecture

### Key Functions

1. **check_prerequisites()**: Validates required tools
2. **check_swarm_status()**: Checks if Swarm already initialized
3. **start_vagrant_vm()**: Manages Vagrant VM lifecycle
4. **initialize_swarm()**: Initializes Swarm on manager
5. **join_worker_to_swarm()**: Joins worker node to cluster
6. **create_worker_storage()**: Sets up persistent storage
7. **verify_cluster()**: Validates cluster health

### Configuration Variables

- `MANAGER_IP="192.168.56.1"` - Manager node address
- `WORKER_IP="192.168.56.10"` - Worker node address
- `VAGRANT_DIR="vagrant"` - Path to Vagrant directory
- `SWARM_PORT="2377"` - Swarm management port

## Troubleshooting

### "Docker daemon is not running"

```bash
# Solution: Start Docker Desktop
open -a Docker
# Wait for Docker to start, then retry
```

### "Cannot connect to VM via SSH"

```bash
# Solution: Check VM status and restart
cd vagrant
vagrant status
vagrant reload
cd ..
```

### "Failed to join worker node to Swarm"

```bash
# Solution: Check network and firewall
# Verify manager can reach worker
ping 192.168.56.10

# Check if ports are open
# Required ports: 2377, 7946, 4789
```

### "Worker node is not Ready"

```bash
# Solution: Check worker node logs
cd vagrant
vagrant ssh -c "docker info"
vagrant ssh -c "systemctl status docker"
cd ..
```

## Performance Expectations

- **First run** (VM creation): 3-5 minutes
- **Subsequent runs** (VM exists): 30-60 seconds
- **Force re-init**: 1-2 minutes
- **Skip Vagrant**: 15-30 seconds

## See Also

- [Vagrant Setup Guide](../vagrant/VAGRANT_SETUP.md)
- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Stack Configuration](../src/swarm/README.md)
