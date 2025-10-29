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

The database volume will be stored inside the VM at:
```
/var/lib/docker/volumes/
```

**Data Persistence:**
- ✅ Survives `vagrant halt` and `vagrant up`
- ✅ Survives `vagrant reload`
- ❌ Lost on `vagrant destroy`

### Backing Up Data

The Vagrantfile includes a synced folder for backups:

```bash
# On your Mac, backups folder is synced to VM
ls /Users/tohyifan/HW_3/vagrant/backups

# Inside VM (vagrant ssh), access same folder
ls /vagrant/backups

# Manual backup example:
vagrant ssh
docker exec names-app_db pg_dump -U names_user namesdb > /vagrant/backups/backup.sql
exit
```

### Before `vagrant destroy`

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
