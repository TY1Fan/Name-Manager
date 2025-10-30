# Docker Swarm Stack Configuration

This directory contains the Docker Swarm stack configuration for distributed deployment of the Names Manager application.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Docker Swarm Cluster                   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────────┐      ┌─────────────────────┐  │
│  │  Manager Node      │      │  Worker Node        │  │
│  │  (Laptop)          │      │  (VM/Lab Server)    │  │
│  │                    │      │                     │  │
│  │  ┌──────────────┐ │      │  ┌───────────────┐ │  │
│  │  │  Frontend    │ │      │  │  Database     │ │  │
│  │  │  Port 80     │ │      │  │  PostgreSQL   │ │  │
│  │  └──────────────┘ │      │  └───────────────┘ │  │
│  │                    │      │         │          │  │
│  │  ┌──────────────┐ │      │         ▼          │  │
│  │  │  Backend     │ │      │  /var/lib/        │  │
│  │  │  Flask API   │ │      │  postgres-data    │  │
│  │  └──────────────┘ │      │                     │  │
│  └────────────────────┘      └─────────────────────┘  │
│           │                            │               │
│           └────────────────────────────┘               │
│              Overlay Network (appnet)                  │
└─────────────────────────────────────────────────────────┘
```

## Files

- **stack.yaml**: Main Docker Swarm stack configuration file
- **README.md**: This file - documentation and usage guide

## Prerequisites

Before deploying the stack, ensure:

1. **Docker Swarm Initialized**
   ```bash
   # On manager node (laptop)
   docker swarm init --advertise-addr 192.168.56.1
   
   # On worker node (VM/lab server)
   docker swarm join --token <TOKEN> 192.168.56.1:2377
   ```

2. **Worker Node Storage**
   ```bash
   # On worker node, create persistent storage directory
   sudo mkdir -p /var/lib/postgres-data
   sudo chown -R 999:999 /var/lib/postgres-data
   ```

3. **Environment Variables**
   - Copy `.env.example` to `.env` in the `src/` directory
   - Update values as needed (especially POSTGRES_PASSWORD)

4. **Docker Images Built**
   ```bash
   # Build images from src directory
   cd src
   docker build -t names-manager-backend:latest ./backend
   docker build -t names-manager-frontend:latest ./frontend
   ```

## Deployment

### Deploy the Stack

```bash
# From the src directory
cd /path/to/HW_3/src

# Deploy stack (reads .env automatically)
docker stack deploy -c swarm/stack.yaml names-app
```

### Verify Deployment

```bash
# Check services status
docker service ls

# Check service logs
docker service logs names-app_frontend
docker service logs names-app_backend
docker service logs names-app_db

# Verify service placement
docker service ps names-app_frontend  # Should be on manager
docker service ps names-app_backend   # Should be on manager
docker service ps names-app_db        # Should be on worker
```

### Access the Application

- **Frontend**: http://localhost (or http://192.168.56.1 from worker)
- **Health Checks**:
  - Backend: http://localhost/api/healthz
  - Database: Check logs for health status

## Updating the Stack

```bash
# After making changes to stack.yaml or rebuilding images
docker stack deploy -c swarm/stack.yaml names-app
```

Docker Swarm will perform a rolling update automatically.

## Removing the Stack

```bash
# Remove all services
docker stack rm names-app

# Wait for services to stop (check with docker service ls)
# Volumes persist and can be reused on next deployment
```

## Service Configuration

### Database (db)
- **Node**: Worker with label `role=db` (`node.labels.role == db`)
- **Port**: Internal only (5432)
- **Volume**: `/var/lib/postgres-data` on worker node
- **Health Check**: `pg_isready` every 10s
- **Replicas**: 1 (stateful service)
- **Note**: Worker node is automatically labeled during `init-swarm.sh`

### Backend (backend)
- **Node**: Manager only (`node.role == manager`)
- **Port**: Internal only (5000)
- **Health Check**: `curl /healthz` every 10s
- **Replicas**: 1
- **Dependencies**: Requires `db` service

### Frontend (frontend)
- **Node**: Manager only (`node.role == manager`)
- **Port**: 80 (published, ingress mode)
- **Replicas**: 1
- **Dependencies**: Requires `backend` service

## Network Configuration

- **Network Name**: `appnet`
- **Driver**: overlay (for multi-node communication)
- **Encryption**: Enabled
- **Service Discovery**: Automatic DNS-based (services can reach each other by name)

## Volume Configuration

- **Volume Name**: `db_data`
- **Type**: Bind mount to `/var/lib/postgres-data` on worker node
- **Persistence**: Data survives container restarts and stack redeployments
- **Backup**: Use `vagrant/backups/` directory (if using Vagrant VM)

## Troubleshooting

### Services not starting

```bash
# Check service status
docker service ls

# Check detailed service info
docker service ps names-app_db --no-trunc

# Check logs
docker service logs names-app_db
```

### Wrong node placement

```bash
# Verify node roles
docker node ls

# Check service constraints
docker service inspect names-app_db --format '{{.Spec.TaskTemplate.Placement}}'
```

### Volume issues

```bash
# On worker node, verify directory exists and permissions
ssh worker-node
ls -la /var/lib/postgres-data
sudo chown -R 999:999 /var/lib/postgres-data
```

### Network connectivity issues

```bash
# Verify overlay network
docker network ls
docker network inspect names-app_appnet

# Test service-to-service connectivity
docker exec $(docker ps -q -f name=names-app_backend) ping db
```

## Differences from Docker Compose

| Feature | Docker Compose | Docker Swarm Stack |
|---------|----------------|-------------------|
| **Scope** | Single host | Multi-node cluster |
| **Port** | 8080:80 | 80:80 |
| **Placement** | Automatic | Constraint-based |
| **Scaling** | Manual | Declarative replicas |
| **Health Checks** | Container-level | Service-level |
| **Updates** | Manual restart | Rolling updates |
| **Service Discovery** | Bridge network | Overlay network |

## Migration from Compose to Swarm

1. **Keep Compose for Local Development**
   - Use `docker-compose.yml` for single-host development
   - Use `swarm/stack.yaml` for distributed deployment

2. **Build Images Before Deploying**
   - Compose builds on-the-fly
   - Swarm requires pre-built images

3. **Update DB_URL if needed**
   - Compose: `db:5432`
   - Swarm: `db:5432` (same, service discovery works)

4. **Check Port Mappings**
   - Compose: `${FRONTEND_PORT}:80` (default 8080)
   - Swarm: `80:80` (direct port 80)

## See Also

- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Vagrant Setup Guide](../../vagrant/VAGRANT_SETUP.md)
- [Ops Scripts](../../ops/) - Automated deployment scripts
