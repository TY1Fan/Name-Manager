# Vagrant Worker Node for Docker Swarm

This directory contains the Vagrant configuration to create a Linux VM that serves as a Docker Swarm worker node for the Names Manager application.

## Quick Links

- **Setup Guide**: [VAGRANT_SETUP.md](./VAGRANT_SETUP.md) - Comprehensive instructions
- **Vagrantfile**: [Vagrantfile](./Vagrantfile) - VM configuration
- **Backups**: `./backups/` - Shared folder for database backups

## Why Vagrant?

Instead of requiring a physical lab server, this Vagrant VM allows you to:
- Run the entire distributed application on a single laptop
- Simulate multi-node Swarm deployment
- Easily tear down and rebuild the environment
- Practice production-like deployment without extra hardware

## Quick Start (5 Minutes)

```bash
# 1. Install prerequisites (one-time)
brew install vagrant
brew install --cask virtualbox

# 2. Start the worker VM
cd vagrant
vagrant up

# 3. Initialize Swarm on your Mac
docker swarm init --advertise-addr 192.168.56.1

# 4. Join VM to Swarm
vagrant ssh
sudo docker swarm join --token <TOKEN> 192.168.56.1:2377
exit

# 5. Verify cluster
docker node ls
# Should show 2 nodes: your Mac (manager) and swarm-worker (worker)
```

## What Gets Created

**Virtual Machine:**
- **OS**: Ubuntu 22.04 LTS (Jammy)
- **Hostname**: swarm-worker
- **IP**: 192.168.56.10
- **RAM**: 2GB
- **CPUs**: 2 cores
- **Disk**: 20GB (dynamic)

**Software Installed:**
- Docker Engine (latest stable)
- Docker CLI and plugins
- All required dependencies

**Network:**
- Private network connecting to host (VirtualBox)
- Automatic firewall configuration for Swarm ports

## Architecture

```
┌─────────────────────────────────────────┐
│         Your Mac (Manager Node)         │
│                                         │
│  ┌──────────┐  ┌──────────┐           │
│  │ Frontend │  │ Backend  │           │
│  │ (Nginx)  │  │ (Flask)  │           │
│  └──────────┘  └──────────┘           │
│         │            │                 │
│         └────────────┼─────────────────┼───► Overlay Network
│                      │                 │
└──────────────────────┼─────────────────┘
                       │
                       │ Docker Swarm
                       │
┌──────────────────────┼─────────────────┐
│    Vagrant VM (Worker Node)            │
│         192.168.56.10                  │
│                      │                 │
│              ┌───────▼─────┐          │
│              │  Database   │          │
│              │ (PostgreSQL)│          │
│              └─────────────┘          │
│                                       │
└───────────────────────────────────────┘
```

## Common Commands

```bash
# Start VM
vagrant up

# Stop VM (keeps data)
vagrant halt

# Restart VM
vagrant reload

# SSH into VM
vagrant ssh

# Check status
vagrant status

# Destroy VM (DELETES DATA!)
vagrant destroy

# View VM info
vagrant ssh-config
```

## Files in This Directory

- **Vagrantfile** - VM configuration (edit to change resources)
- **VAGRANT_SETUP.md** - Detailed setup and troubleshooting guide
- **backups/** - Shared folder for database backups
- **.vagrant/** - Vagrant state (auto-created, gitignored)

## Data Persistence

**Preserved:**
- Database volumes survive `vagrant halt` and `vagrant up`
- Data persists across VM reboots

**Lost:**
- `vagrant destroy` deletes all VM data including volumes
- Always backup before destroying: `vagrant ssh` → `docker exec ... pg_dump`

**Backup Location:**
- `./backups/` folder is shared between Mac and VM
- Copy backups here before `vagrant destroy`

## Resource Requirements

**Minimum:**
- 4GB RAM on host Mac
- 20GB free disk space
- macOS 10.15 or later

**Recommended:**
- 8GB+ RAM on host Mac
- 40GB+ free disk space
- Modern Mac (2017 or newer)

## Troubleshooting

**VM won't start?**
```bash
vagrant up --debug
VBoxManage list runningvms
```

**Network issues?**
```bash
vagrant reload
ping 192.168.56.10
```

**Performance problems?**
- Edit Vagrantfile to increase RAM/CPU
- Or use physical lab server instead

**Full troubleshooting guide**: See [VAGRANT_SETUP.md](./VAGRANT_SETUP.md)

## Switching to Physical Server

If you later want to use a physical lab server:

1. Stop using Vagrant: `vagrant halt`
2. Leave Swarm: `docker swarm leave --force`
3. Follow physical server setup in main documentation
4. The stack file works with either approach

## Next Steps

After setting up the Vagrant worker:

1. ✅ Worker VM running (`vagrant status`)
2. ✅ Joined to Swarm (`docker node ls`)
3. ➡️ Create `docker-stack.yml` with placement constraints
4. ➡️ Deploy stack to Swarm
5. ➡️ Verify database runs on worker VM
6. ➡️ Test application end-to-end

## Support

- **Vagrant Issues**: See [VAGRANT_SETUP.md](./VAGRANT_SETUP.md) troubleshooting section
- **Swarm Issues**: See main [IMPLEMENTATION.md](../specs/001-swarm-orchestration/IMPLEMENTATION.md)
- **Application Issues**: See application [README.md](../README.md)
