# Docker Stack Implementation Reference

This document provides technical guidance for implementing the Docker Swarm stack file based on the specification requirements.

## Worker Node Options

You have two options for the worker node:

### Option A: Physical Lab Server
- Dedicated hardware running Linux
- Better for production deployments
- Requires separate machine

### Option B: Vagrant VM (Recommended for Development)
- Linux VM running on your laptop
- Easier setup and management
- Perfect for development and testing
- See comprehensive guide: `/vagrant/VAGRANT_SETUP.md`

**Quick Vagrant Setup:**
```bash
cd vagrant
vagrant up                    # Start VM with Docker pre-installed
docker swarm init --advertise-addr 192.168.56.1  # On Mac
vagrant ssh                   # Enter VM
sudo docker swarm join ...    # Join Swarm (paste command from init)
exit
docker node ls                # Verify 2 nodes on Mac
```

## Stack File Location

Create: `src/docker-stack.yml`

## Key Configuration Requirements

### Version
```yaml
version: "3.8"
```
Minimum version 3.8 required for full Swarm features.

### Placement Constraints

**Frontend Service** (must run on manager):
```yaml
deploy:
  placement:
    constraints:
      - node.role == manager
```

**Backend Service** (must run on manager):
```yaml
deploy:
  placement:
    constraints:
      - node.role == manager
```

**Database Service** (must run on worker):
```yaml
deploy:
  placement:
    constraints:
      - node.role == worker
```

### Networking

**Overlay Network** (enables cross-node communication):
```yaml
networks:
  appnet:
    driver: overlay
    attachable: true
```

All services must attach to this network.

### Volume Persistence

**Database Volume** (persists on worker node):
```yaml
volumes:
  db_data:
    driver: local
```

The volume will be created on whichever node runs the database service (worker node due to placement constraint).

### Health Checks

All services should maintain existing health check configurations from docker-compose.yml:
- Database: `pg_isready` check
- Backend: Endpoint health check (if implemented)
- Frontend: Basic HTTP check

### Restart Policies

Configure automatic restart for all services:
```yaml
deploy:
  restart_policy:
    condition: on-failure
    delay: 5s
    max_attempts: 3
    window: 120s
```

### Service Dependencies

Maintain startup order using `depends_on`:
- Backend depends on database being healthy
- Frontend depends on backend

Note: In Swarm mode, `depends_on` with health checks works differently. Consider using health checks and retry logic in services.

## Port Publishing

**Frontend Service** (published on manager node):
```yaml
ports:
  - "${FRONTEND_PORT}:80"
```

Mode: `host` for better performance, or `ingress` for load balancing (if scaling in future).

## Environment Variables

Maintain all existing environment variables from docker-compose.yml:
- `DB_URL`
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- `MAX_NAME_LENGTH`
- `SERVER_HOST`, `SERVER_PORT`
- `LOG_LEVEL`, `DB_ECHO`
- `FRONTEND_PORT`

Can be loaded from `.env` file (same as Compose).

## Service Update Configuration

Configure rolling update behavior:
```yaml
deploy:
  update_config:
    parallelism: 1
    delay: 10s
    failure_action: rollback
    order: stop-first
```

## Replicas

Start with single replica per service:
```yaml
deploy:
  replicas: 1
```

## Key Differences from Docker Compose

1. **deploy** section instead of **restart**
2. **placement constraints** for node assignment
3. **overlay network** instead of bridge
4. **stack deploy** command instead of **compose up**
5. **secrets** (optional, for future enhancement)

## Deployment Commands

### Deploy Stack
```bash
docker stack deploy -c src/docker-stack.yml names-app
```

### View Services
```bash
docker stack services names-app
docker stack ps names-app
```

### View Logs
```bash
docker service logs names-app_frontend
docker service logs names-app_backend
docker service logs names-app_db
```

### Update Stack
```bash
docker stack deploy -c src/docker-stack.yml names-app
```

### Remove Stack
```bash
docker stack rm names-app
```

## Testing Checklist

- [ ] Stack deploys without errors
- [ ] All services show REPLICAS 1/1
- [ ] Frontend service on manager node
- [ ] Backend service on manager node
- [ ] Database service on worker node
- [ ] Overlay network created
- [ ] Volume created on worker node
- [ ] Frontend accessible from manager
- [ ] Cross-node communication works
- [ ] Data persists after service restart
- [ ] Data persists after stack redeploy

## Troubleshooting Tips

### Service Not Starting
```bash
docker service ps --no-trunc names-app_<service>
docker service logs names-app_<service>
```

### Wrong Node Placement
```bash
docker service ps names-app_<service>
# Check NODE column
```
If wrong, verify placement constraints in stack file.

### Network Issues - Physical Server
```bash
docker network inspect names-app_appnet
# Verify all services attached
# Check subnet configuration

# Test connectivity between nodes
ping <worker-ip>
telnet <worker-ip> 2377
```

### Network Issues - Vagrant VM
```bash
# Verify VM IP
vagrant ssh
ip addr show
exit

# Ping VM from Mac
ping 192.168.56.10

# Verify Swarm ports accessible
nc -zv 192.168.56.10 2377

# Restart VM if network issues
vagrant reload
```

### Volume Issues
```bash
docker volume inspect names-app_db_data
# Verify volume exists on worker node

# For Vagrant: SSH into VM to check
vagrant ssh
sudo docker volume ls
sudo docker volume inspect names-app_db_data
exit
```

### Vagrant-Specific Issues

**VM Won't Start:**
```bash
vagrant status
vagrant up --debug
VBoxManage list runningvms
```

**Can't Join Swarm:**
```bash
# Verify manager IP
ifconfig | grep 192.168.56.1

# Verify VM can reach manager
vagrant ssh
ping 192.168.56.1
telnet 192.168.56.1 2377
exit

# Re-initialize if needed
docker swarm leave --force  # On manager
docker swarm init --advertise-addr 192.168.56.1
```

**Performance Issues:**
```bash
# Check VM resources
vagrant ssh
free -h  # Check memory
df -h    # Check disk
exit

# Increase resources in Vagrantfile if needed
```

## Migration Path from Compose

1. Copy `docker-compose.yml` to `docker-stack.yml`
2. Add `deploy` sections with placement constraints
3. Change network driver to overlay
4. Test with local Swarm (single node) first
5. Deploy to multi-node cluster
6. Keep `docker-compose.yml` unchanged for local dev

## Reference

- [Docker Stack Deploy Docs](https://docs.docker.com/engine/reference/commandline/stack_deploy/)
- [Compose File Version 3 Reference](https://docs.docker.com/compose/compose-file/compose-file-v3/)
- [Swarm Mode Overview](https://docs.docker.com/engine/swarm/)
