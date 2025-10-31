# Swarm Directory

This directory contains Docker Swarm deployment configurations for the Names Manager application.

## Purpose

This directory is used for Docker Swarm orchestration files that define how the application should be deployed across multiple nodes in a Swarm cluster.

## Contents

- **stack.yaml**: Docker Stack file that defines all services, networks, and volumes for Swarm deployment

## Usage

### Deploy the Stack

From the manager VM:

```bash
# Copy stack file to manager VM
vagrant ssh manager -c "sudo mkdir -p /vagrant/swarm"

# Deploy the stack
vagrant ssh manager -c "cd /vagrant && docker stack deploy -c swarm/stack.yaml names"
```

### View Stack Status

```bash
# List all services
vagrant ssh manager -c "docker stack services names"

# List all tasks (running containers)
vagrant ssh manager -c "docker stack ps names"

# View service logs
vagrant ssh manager -c "docker service logs names_api"
```

### Remove the Stack

```bash
vagrant ssh manager -c "docker stack rm names"
```

## Architecture

The stack defines a 3-tier application:

1. **Database (db)**: PostgreSQL 15 on worker node with `role=db` label
2. **Backend (api)**: Flask API connecting to database
3. **Frontend (web)**: Nginx serving static files and proxying to API

All services communicate over the `appnet` overlay network.

## Files

### stack.yaml

The main Docker Stack configuration file that:
- Defines all services with their images and configurations
- Specifies deployment constraints (replicas, placement, health checks)
- Configures the overlay network
- Defines persistent volumes for database data

## Network

Services use the `appnet` overlay network (created separately):
```bash
docker network create --driver overlay --attachable appnet
```

## Placement Constraints

- **db service**: Runs only on nodes with `node.labels.role == db` (worker node)
- **api service**: Can run on any node
- **web service**: Can run on any node

## Health Checks

All services include health checks to ensure reliability:
- **db**: `pg_isready` command
- **api**: HTTP GET to `/api/health`
- **web**: HTTP GET to `/`

## Related Documentation

- See `spec/20-target-spec.md` for target architecture details
- See `spec/40-tasks.md` for implementation tasks
- See `vagrant/swarm-join-tokens.md` for cluster configuration
