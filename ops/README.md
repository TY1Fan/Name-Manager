# Operations Scripts

This directory contains operational scripts for managing the Docker Swarm deployment.

## Purpose

The `ops/` directory houses scripts that automate common operational tasks for the Names Manager application deployed on Docker Swarm.

## Scripts

- `init-swarm.sh` - Initialize Docker Swarm cluster from scratch
- `deploy.sh` - Deploy or update the application stack
- `backup-db.sh` - Backup the PostgreSQL database
- `restore-db.sh` - Restore database from backup
- `health-check.sh` - Check health status of all services

## Usage

All scripts should be run from the project root directory:

```bash
# Example: Initialize Swarm cluster
./ops/init-swarm.sh

# Example: Deploy the application
./ops/deploy.sh
```

## Prerequisites

- Vagrant VMs must be running (`vagrant up`)
- SSH access to manager and worker nodes
- Docker installed on all nodes
- Proper network connectivity between nodes

## Notes

- Scripts use `vagrant ssh` to execute commands on VMs
- Manager node: 192.168.56.10
- Worker node: 192.168.56.11
- All scripts include error handling and validation
