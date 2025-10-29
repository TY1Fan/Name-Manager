# Vagrant Worker Node Setup Guide

This guide explains how to use Vagrant to create a Linux VM as your Docker Swarm worker node, instead of using a physical lab server.

## Why Use Vagrant?

**Benefits:**
- ✅ No need for a separate physical machine
- ✅ Portable and reproducible setup
- ✅ Easy to tear down and rebuild (`vagrant destroy` / `vagrant up`)
- ✅ Simulates multi-node distributed architecture
- ✅ Perfect for development and testing
- ✅ Version-controlled infrastructure configuration

**When to Use Physical Server:**
- Production deployments
- Need actual physical separation
- Performance requirements exceed VM capabilities
- Already have dedicated lab infrastructure

## Prerequisites

### Required Software

1. **Vagrant** (2.2 or later)
   ```bash
   # Install via Homebrew on macOS
   brew install vagrant
   
   # Verify installation
   vagrant --version
   ```

2. **VirtualBox** (6.1 or later) - Default provider
   ```bash
   # Install via Homebrew on macOS
   brew install --cask virtualbox
   
   # Verify installation
   VBoxManage --version
   ```

3. **Docker Desktop** (for macOS host - manager node)
   - Already installed if you've been using Docker Compose
   - Docker Desktop includes Swarm support

### System Requirements

**Host Machine (Your Mac):**
- macOS 10.15 or later
- 8GB+ RAM (4GB for VM + 4GB for host)
- 30GB+ free disk space
- CPU with virtualization support (VT-x enabled)

## Quick Start

### Step 1: Start the Worker VM

```bash
# Navigate to Vagrant directory
cd /Users/tohyifan/HW_3/vagrant

# Start and provision the VM (first time: downloads Ubuntu image)
vagrant up

# Expected output:
# - Downloads ubuntu/jammy64 box (~500MB, one-time)
# - Creates VM with 2GB RAM, 2 CPUs
# - Installs Docker automatically
# - Configures network (IP: 192.168.56.10)
```

**First boot takes 5-10 minutes** (downloads Ubuntu image and installs Docker).  
Subsequent boots take ~30 seconds.

### Step 2: Verify VM is Running

```bash
# Check VM status
vagrant status

# Should show: "default: running (virtualbox)"

# SSH into the VM
vagrant ssh

# Inside VM, verify Docker
docker --version
# Should show: Docker version 24.x or later

# Exit VM
exit
```

### Step 3: Initialize Swarm on Manager (Your Mac)

```bash
# Get your Mac's IP address on private network
# Run on your Mac (not in VM)
ifconfig | grep "inet " | grep -v 127.0.0.1

# Look for IP starting with 192.168.56.x (e.g., 192.168.56.1)
# This is your manager node IP

# Initialize Docker Swarm
docker swarm init --advertise-addr 192.168.56.1

# Expected output will include a join command like:
# docker swarm join --token SWMTKN-1-xxx... 192.168.56.1:2377

# ⚠️ IMPORTANT: Copy the entire "docker swarm join" command
```

### Step 4: Join Worker to Swarm

```bash
# SSH into the VM
vagrant ssh

# Paste and run the join command (with sudo)
sudo docker swarm join --token SWMTKN-1-xxx... 192.168.56.1:2377

# Expected output: "This node joined a swarm as a worker."

# Exit VM
exit
```

### Step 5: Verify Swarm Cluster

```bash
# On your Mac (manager node), list all nodes
docker node ls

# Expected output:
# ID         HOSTNAME       STATUS   AVAILABILITY   MANAGER STATUS   ENGINE VERSION
# abc123 *   docker-desktop Ready    Active         Leader           24.x.x
# def456     swarm-worker   Ready    Active                          24.x.x

# ✅ You should see 2 nodes: your Mac (manager/leader) and swarm-worker
```

## Network Configuration

### IP Addresses

- **Manager Node (Mac)**: `192.168.56.1` (auto-assigned by VirtualBox)
- **Worker Node (VM)**: `192.168.56.10` (configured in Vagrantfile)

### Required Ports (Auto-configured)

Docker Swarm requires these ports between nodes:
- `2377/tcp` - Cluster management
- `7946/tcp` - Node communication
- `7946/udp` - Node communication
- `4789/udp` - Overlay network traffic

**Note**: VirtualBox private network automatically allows this communication.

### Testing Network Connectivity

```bash
# From your Mac, ping the worker VM
ping 192.168.56.10

# SSH into VM and ping manager
vagrant ssh
ping 192.168.56.1
exit
```

## VM Management Commands

### Daily Operations

```bash
# Start VM
vagrant up

# Stop VM (preserves state)
vagrant halt

# Restart VM
vagrant reload

# SSH into VM
vagrant ssh

# View VM status
vagrant status

# View VM info
vagrant ssh-config
```

### Maintenance

```bash
# Re-run provisioning (reinstall Docker, etc.)
vagrant provision

# Restart with fresh provisioning
vagrant reload --provision

# Destroy and recreate VM (LOSES DATA!)
vagrant destroy -f
vagrant up
```

### Troubleshooting

```bash
# Check VM logs
vagrant up --debug

# View VirtualBox VMs
VBoxManage list vms

# Force stop VM if frozen
vagrant halt -f

# Remove all Vagrant boxes (free space)
vagrant box list
vagrant box remove ubuntu/jammy64
```

## Storage and Volumes

### Database Volume Persistence

The database service in Docker Swarm uses a bind mount to a dedicated directory on the worker VM:

**Primary Storage Location:**
```
/var/lib/postgres-data
```

This directory is:
- Created automatically by the Vagrantfile provisioning
- Owned by the VM's filesystem (not synced to host)
- Optimized for database performance
- Has proper permissions (755)

**Data Persistence Behavior:**
- ✅ **Persists across `vagrant halt` and `vagrant up`** - Data is preserved
- ✅ **Persists across `vagrant reload`** - Data is preserved
- ✅ **Persists across VM restarts** - Data is preserved
- ✅ **Persists across Swarm stack redeployments** - Data is preserved
- ❌ **Lost on `vagrant destroy`** - Complete VM removal deletes all data

**Why Not Use Synced Folders for Database Data?**

The PostgreSQL data directory is intentionally NOT synced to the host because:
1. **Performance**: Native VM filesystem is much faster than synced folders
2. **Reliability**: Avoids file locking issues with database files
3. **Compatibility**: PostgreSQL requires specific filesystem features
4. **Best Practice**: Database volumes should use native storage

### Checking Storage Status

```bash
# Check if persistent storage exists and its size
cd /Users/tohyifan/HW_3/vagrant
vagrant ssh -c "ls -lah /var/lib/postgres-data"

# Check storage usage
vagrant ssh -c "du -sh /var/lib/postgres-data"

# When database is running, you'll see PostgreSQL files
vagrant ssh -c "ls /var/lib/postgres-data"
# Expected output (after deployment):
# base  global  pg_wal  postgresql.conf  postmaster.opts  ...
```

### Backing Up Data

The Vagrantfile includes a synced folder specifically for database backups:

```bash
# On your Mac, backups folder is synced to VM
ls /Users/tohyifan/HW_3/vagrant/backups

# Inside VM (vagrant ssh), access same folder
ls /vagrant/backups

# Create a manual backup using pg_dump
# Method 1: From host (Mac)
cd /Users/tohyifan/HW_3/vagrant
vagrant ssh -c "docker exec \$(docker ps -q -f name=names-app_db) \
  pg_dump -U postgres names_db > /vagrant/backups/backup-\$(date +%Y%m%d-%H%M%S).sql"

# Method 2: From inside VM
vagrant ssh
docker exec $(docker ps -q -f name=names-app_db) \
  pg_dump -U postgres names_db > /vagrant/backups/backup.sql
exit

# Backup is now available on your Mac
ls vagrant/backups/
```

**Restore from Backup:**

```bash
# If you need to restore data after 'vagrant destroy' and rebuild:

# 1. Rebuild VM and initialize Swarm
./ops/init-swarm.sh
./ops/deploy.sh

# 2. Wait for database to be ready
sleep 30

# 3. Restore from backup
cd vagrant
vagrant ssh -c "docker exec -i \$(docker ps -q -f name=names-app_db) \
  psql -U postgres names_db < /vagrant/backups/backup.sql"
```

### Testing Data Persistence

**Test 1: Persist Across `vagrant reload`**

```bash
# 1. Add some data
curl -X POST http://localhost/api/names \
  -H "Content-Type: application/json" \
  -d '{"name":"Persistence Test 1"}'

# 2. Count names
BEFORE=$(curl -s http://localhost/api/names | jq '. | length')
echo "Names before reload: $BEFORE"

# 3. Reload VM
cd vagrant
vagrant reload
cd ..

# 4. Wait for services to restart
./ops/deploy.sh
sleep 30

# 5. Verify data persists
AFTER=$(curl -s http://localhost/api/names | jq '. | length')
echo "Names after reload: $AFTER"

# Should be equal
[ "$BEFORE" -eq "$AFTER" ] && echo "✅ Data persisted!" || echo "❌ Data lost!"
```

**Test 2: Persist Across `vagrant halt/up`**

```bash
# 1. Add data
curl -X POST http://localhost/api/names \
  -H "Content-Type: application/json" \
  -d '{"name":"Halt Test 1"}'

# 2. Count names
BEFORE=$(curl -s http://localhost/api/names | jq '. | length')

# 3. Halt VM
cd vagrant
vagrant halt

# 4. Start VM again
vagrant up
cd ..

# 5. Redeploy stack
./ops/deploy.sh
sleep 30

# 6. Verify data persists
AFTER=$(curl -s http://localhost/api/names | jq '. | length')

[ "$BEFORE" -eq "$AFTER" ] && echo "✅ Data persisted!" || echo "❌ Data lost!"
```

### Before `vagrant destroy`

⚠️ **WARNING**: `vagrant destroy` permanently deletes the VM and all data in `/var/lib/postgres-data`!

If you need to destroy and rebuild the VM:

```bash
# 1. Backup database first
vagrant ssh
docker exec names-app_db pg_dump -U names_user namesdb > /vagrant/backups/pre-destroy-backup.sql
exit

# 2. Now safe to destroy
vagrant destroy -f

# 3. Rebuild and restore
vagrant up
# (follow steps to rejoin Swarm)
# (restore database from backup)
```

## Deployment Workflow

### Option A: Physical Lab Server

```bash
# 1. Ensure lab server has Docker installed
# 2. Initialize Swarm on your Mac
# 3. SSH to lab server and join Swarm
# 4. Deploy stack
```

### Option B: Vagrant VM (This Guide)

```bash
# 1. Start Vagrant VM
cd vagrant && vagrant up

# 2. Initialize Swarm on your Mac
docker swarm init --advertise-addr 192.168.56.1

# 3. Join VM to Swarm
vagrant ssh
sudo docker swarm join --token <TOKEN> 192.168.56.1:2377
exit

# 4. Deploy stack
cd ../src
docker stack deploy -c docker-stack.yml names-app
```

### Switching Between Options

You can easily switch between physical server and Vagrant:

```bash
# Remove stack
docker stack rm names-app

# Leave Swarm (on worker)
vagrant ssh  # or ssh to lab server
sudo docker swarm leave
exit

# Remove Swarm on manager
docker swarm leave --force

# Now rejoin with different worker node
```

## Resource Adjustment

Edit `vagrant/Vagrantfile` to adjust VM resources:

```ruby
config.vm.provider "virtualbox" do |vb|
  vb.memory = "2048"  # RAM in MB (increase if needed)
  vb.cpus = 2         # CPU cores
end
```

After changes:
```bash
vagrant reload
```

## Troubleshooting

### Issue: VM Won't Start

```bash
# Check VirtualBox is installed
VBoxManage --version

# Check for conflicting VMs
VBoxManage list runningvms

# Try with debug
vagrant up --debug
```

### Issue: Network Connectivity Problems

```bash
# Verify private network in VirtualBox
VBoxManage list hostonlyifs

# Should show vboxnet0 with 192.168.56.1

# Recreate network
vagrant halt
vagrant up
```

### Issue: Can't Join Swarm

```bash
# Verify manager is listening
# On Mac:
docker node ls

# Check manager IP
ifconfig | grep 192.168.56.1

# Ensure VM can reach manager
vagrant ssh
ping 192.168.56.1
telnet 192.168.56.1 2377
exit
```

### Issue: VM Runs Slow

```bash
# Increase VM resources in Vagrantfile
# Then:
vagrant reload

# Or use physical lab server instead
```

## Performance Considerations

**Vagrant VM (Local):**
- ✅ Lower network latency
- ✅ Easier to manage
- ❌ Shares host resources
- ❌ Not suitable for production

**Physical Lab Server:**
- ✅ Dedicated resources
- ✅ Better for production
- ❌ Higher network latency
- ❌ Requires separate hardware

## Persistent Storage Configuration Summary

### Storage Architecture

The Vagrant configuration implements a two-tier storage strategy:

**1. Database Data Storage** (Performance-Critical)
- **Location**: `/var/lib/postgres-data` on VM
- **Type**: VM local filesystem (NOT synced)
- **Purpose**: PostgreSQL data files
- **Persistence**: Survives VM restarts, lost on `vagrant destroy`
- **Performance**: Optimized for database I/O operations

**2. Backup Storage** (Convenience)
- **Location**: `./backups` (synced to `/vagrant/backups` on VM)
- **Type**: Synced folder
- **Purpose**: Database backups, exports
- **Persistence**: Survives everything (stored on host)
- **Performance**: Slower, but suitable for backups

### Configuration Details

The Vagrantfile automatically:
1. Creates `/var/lib/postgres-data` directory during provisioning
2. Sets appropriate permissions (755)
3. Displays storage status on each VM boot
4. Provides synced folder for backups at `./backups`

**Docker Stack Configuration** (`stack.yaml`):
```yaml
services:
  db:
    volumes:
      - type: bind
        source: /var/lib/postgres-data
        target: /var/lib/postgresql/data
```

This bind mount ensures database files are stored on the VM's filesystem at the dedicated path.

### Data Lifecycle

| Operation | Data Persists? | Notes |
|-----------|----------------|-------|
| `vagrant halt` | ✅ YES | VM stopped, disk preserved |
| `vagrant up` | ✅ YES | VM restarted, data intact |
| `vagrant reload` | ✅ YES | VM rebooted, data intact |
| `vagrant suspend/resume` | ✅ YES | VM hibernated, data intact |
| `vagrant provision` | ✅ YES | Only re-runs scripts, data intact |
| `vagrant destroy` | ❌ NO | Complete removal, data deleted |
| Stack remove/redeploy | ✅ YES | Volume persists between deployments |
| Swarm leave/rejoin | ✅ YES | Data independent of Swarm state |

### Best Practices

**DO:**
- ✅ Use `vagrant halt` for temporary stops
- ✅ Use `vagrant reload` to apply Vagrantfile changes
- ✅ Back up data before `vagrant destroy`
- ✅ Test restore procedures regularly
- ✅ Monitor storage usage with `du -sh /var/lib/postgres-data`

**DON'T:**
- ❌ Don't use synced folders for database data (performance issues)
- ❌ Don't run `vagrant destroy` without backups
- ❌ Don't manually modify files in `/var/lib/postgres-data`
- ❌ Don't rely on VM snapshots alone (use pg_dump backups)

### Backup Strategy

**Automated Backup Example:**

Create a backup script at `vagrant/backup.sh`:

```bash
#!/bin/bash
# Automated database backup script

BACKUP_DIR="/Users/tohyifan/HW_3/vagrant/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="backup-${TIMESTAMP}.sql"

echo "Creating backup: $BACKUP_FILE"

cd /Users/tohyifan/HW_3/vagrant
vagrant ssh -c "docker exec \$(docker ps -q -f name=names-app_db) \
  pg_dump -U postgres names_db" > "$BACKUP_DIR/$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "✅ Backup successful: $BACKUP_FILE"
    # Keep only last 7 backups
    ls -t "$BACKUP_DIR"/backup-*.sql | tail -n +8 | xargs -r rm
else
    echo "❌ Backup failed!"
    exit 1
fi
```

**Schedule with cron** (macOS):

```bash
# Add to crontab (crontab -e)
0 2 * * * /Users/tohyifan/HW_3/vagrant/backup.sh >> /Users/tohyifan/HW_3/vagrant/backups/backup.log 2>&1
```

### Troubleshooting Storage Issues

**Issue: Permission Denied on `/var/lib/postgres-data`**

```bash
vagrant ssh
sudo chmod 755 /var/lib/postgres-data
sudo chown -R 999:999 /var/lib/postgres-data  # PostgreSQL user
exit
```

**Issue: Disk Space Full**

```bash
# Check available space
vagrant ssh -c "df -h"

# Check database size
vagrant ssh -c "du -sh /var/lib/postgres-data"

# Clean up old logs if needed
vagrant ssh
sudo docker system prune -a
exit
```

**Issue: Data Lost After `vagrant destroy`**

```bash
# Restore from backup
vagrant up
./ops/init-swarm.sh
./ops/deploy.sh
sleep 30

# Restore data
cd vagrant
vagrant ssh -c "docker exec -i \$(docker ps -q -f name=names-app_db) \
  psql -U postgres names_db < /vagrant/backups/backup.sql"
```

### Verification Checklist

After setting up or modifying storage configuration:

- [ ] `/var/lib/postgres-data` exists on worker VM
- [ ] Directory has proper permissions (755)
- [ ] Synced backup folder works (`./backups` ↔ `/vagrant/backups`)
- [ ] Database writes to correct location
- [ ] Data persists across `vagrant reload`
- [ ] Data persists across `vagrant halt/up`
- [ ] Backup script works
- [ ] Restore procedure tested

### Testing Persistence

Use the provided test procedures in `specs/001-swarm-orchestration/TESTING.md` to verify:

```bash
# Run persistence tests
./ops/test-e2e.sh

# Or manually test
# See "Testing Data Persistence" section above
```

## Next Steps

After setting up Vagrant worker node:

1. ✅ VM running and joined to Swarm
2. ➡️ Create `docker-stack.yml` with placement constraints
3. ➡️ Deploy stack: `docker stack deploy -c docker-stack.yml names-app`
4. ➡️ Verify services on correct nodes: `docker stack ps names-app`
5. ➡️ Test application functionality
6. ➡️ Document any custom configurations

## Additional Resources

- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [VirtualBox Networking](https://www.virtualbox.org/manual/ch06.html)
- [Docker Swarm Tutorial](https://docs.docker.com/engine/swarm/swarm-tutorial/)
- [Ubuntu/Jammy64 Box](https://app.vagrantup.com/ubuntu/boxes/jammy64)
