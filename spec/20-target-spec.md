# Names Manager - Target State Specification

## Executive Summary

**Goal**: Refactor the Names Manager 3-tier application from Docker Compose to **Docker Swarm orchestration** with distributed deployment across two virtual machines.

**Target Architecture**:
- **Swarm Manager VM**: Runs frontend (Nginx) and backend (Flask) services
- **Swarm Worker VM**: Runs database (PostgreSQL) service
- **Orchestration**: Docker Swarm with stack deployment for production
- **Development**: Keep Docker Compose for local development workflow

**Status**: This specification defines the target state for migrating from single-host Docker Compose to multi-host Docker Swarm deployment.

## Overview

This document outlines the migration from the current Docker Compose-based single-host deployment to a Docker Swarm orchestrated multi-host deployment. The application will be refactored to run across two Vagrant VMs with proper service distribution, overlay networking, and production-grade orchestration.

## Architecture Changes

### Current Architecture (Docker Compose)
```
Single Host (Laptop)
├── Frontend (Nginx) :8080
├── Backend (Flask) :8000
└── Database (PostgreSQL) :5432
    └── Bridge Network: appnet
```

### Target Architecture (Docker Swarm)
```
VM1: Swarm Manager (Vagrant)          VM2: Swarm Worker (Vagrant)
├── Frontend (Nginx) :8080            └── Database (PostgreSQL)
├── Backend (Flask) :8000                 └── Persistent Volume
└── Overlay Network: app-overlay          └── Placement Constraint
```

## Infrastructure Requirements

### Virtual Machine Setup

#### VM1: Swarm Manager Node
**Purpose**: Orchestration + Application Services

**Specifications**:
- **OS**: Ubuntu 22.04 LTS (or similar)
- **Memory**: 2 GB RAM minimum
- **CPU**: 2 cores
- **Disk**: 20 GB
- **Network**: Private network with static IP
- **Role**: Swarm Manager

**Services Running**:
- Docker Engine (Swarm mode enabled)
- Frontend service (Nginx)
- Backend service (Flask with Gunicorn)

#### VM2: Swarm Worker Node  
**Purpose**: Database Services

**Specifications**:
- **OS**: Ubuntu 22.04 LTS (or similar)
- **Memory**: 2 GB RAM minimum
- **CPU**: 2 cores
- **Disk**: 30 GB (more space for database)
- **Network**: Private network with static IP
- **Role**: Swarm Worker

**Services Running**:
- Docker Engine (Swarm mode enabled)
- Database service (PostgreSQL 15)

### Vagrant Configuration
```ruby
# Vagrantfile target structure
Vagrant.configure("2") do |config|
  # Swarm Manager VM
  config.vm.define "manager" do |manager|
    manager.vm.box = "ubuntu/jammy64"
    manager.vm.hostname = "swarm-manager"
    manager.vm.network "private_network", ip: "192.168.56.10"
    manager.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
    end
  end
  
  # Swarm Worker VM
  config.vm.define "worker" do |worker|
    worker.vm.box = "ubuntu/jammy64"
    worker.vm.hostname = "swarm-worker"
    worker.vm.network "private_network", ip: "192.168.56.11"
    worker.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
    end
  end
end
```

## Docker Swarm Configuration

### Swarm Initialization

#### Manager Node Setup
```bash
# On VM1 (manager)
docker swarm init --advertise-addr 192.168.56.10

# Output provides join token for workers
# Example: docker swarm join --token SWMTKN-1-xxx... 192.168.56.10:2377
```

#### Worker Node Setup
```bash
# On VM2 (worker)
docker swarm join --token <WORKER_TOKEN> 192.168.56.10:2377

# Verify on manager
docker node ls
# Should show:
# ID       HOSTNAME        STATUS  AVAILABILITY  MANAGER STATUS
# xxx      swarm-manager   Ready   Active        Leader
# yyy      swarm-worker    Ready   Active
```

### Network Configuration

#### Overlay Network
```bash
# Create overlay network for service communication
docker network create \
  --driver overlay \
  --attachable \
  app-overlay
```

**Features**:
- Multi-host networking across VMs
- Encrypted by default (--opt encrypted for data plane encryption)
- Service discovery via DNS
- Load balancing built-in

### Stack File Structure

#### docker-stack.yml
```yaml
version: "3.8"

services:
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-names_user}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-names_pass}
      POSTGRES_DB: ${POSTGRES_DB:-namesdb}
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - app-overlay
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == worker
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-names_user} -d ${POSTGRES_DB:-namesdb}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 20s

  backend:
    image: ${DOCKER_REGISTRY:-localhost}/names-backend:${VERSION:-latest}
    environment:
      DB_URL: postgresql+psycopg2://${POSTGRES_USER:-names_user}:${POSTGRES_PASSWORD:-names_pass}@db:5432/${POSTGRES_DB:-namesdb}
      MAX_NAME_LENGTH: ${MAX_NAME_LENGTH:-50}
      SERVER_HOST: 0.0.0.0
      SERVER_PORT: 8000
      LOG_LEVEL: ${LOG_LEVEL:-INFO}
      DB_ECHO: ${DB_ECHO:-false}
    networks:
      - app-overlay
    deploy:
      replicas: 2
      placement:
        constraints:
          - node.role == manager
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
      rollback_config:
        parallelism: 1
        delay: 10s
    depends_on:
      - db

  frontend:
    image: ${DOCKER_REGISTRY:-localhost}/names-frontend:${VERSION:-latest}
    ports:
      - "${FRONTEND_PORT:-8080}:80"
    networks:
      - app-overlay
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      update_config:
        parallelism: 1
        delay: 10s
    depends_on:
      - backend

networks:
  app-overlay:
    driver: overlay
    attachable: true

volumes:
  db_data:
    driver: local
```

### Service Deployment Strategy

#### Placement Constraints
```yaml
# Database: Worker node only
deploy:
  placement:
    constraints:
      - node.role == worker
      - node.hostname == swarm-worker  # Optional: specific node

# Frontend/Backend: Manager node only  
deploy:
  placement:
    constraints:
      - node.role == manager
```

#### Replicas and Scaling
- **Frontend**: 1 replica (can scale to 2-3)
- **Backend**: 2 replicas (horizontal scaling, load balanced)
- **Database**: 1 replica (single instance, constraint to worker)

## Application Code Changes

### Critical Bug Fixes (Required for Functionality)

#### Fix 1: Backend GET /api/names Response Format
```python
# main.py - Update list_names() to match frontend expectations
@app.route("/api/names", methods=["GET"])
def list_names():
    logger.info("GET /api/names - Request received")
    
    try:
        with engine.connect() as conn:
            stmt = select(
                table.c.id,
                table.c.name,
                table.c.created_at
            ).order_by(table.c.id.asc())
            rows = conn.execute(stmt).fetchall()

        results = []
        for r in rows:
            results.append({
                "id": r.id,
                "name": r.name,
                "created_at": r.created_at.isoformat() if r.created_at else None
            })

        logger.info(f"GET /api/names - Successfully retrieved {len(results)} names")
        # CHANGE: Wrap in object with "names" key
        return jsonify({"names": results}), 200
    
    except Exception as e:
        logger.error(f"GET /api/names - Database error: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

#### Fix 2: Frontend Display Logic
```javascript
// app.js - Update loadNames() to properly handle response
async function loadNames() {
  try {
    setLoading(namesList, true);
    hideMessages();
    
    const res = await apiRequest("/names");
    const data = await res.json();
    
    namesList.innerHTML = "";

    // CHANGE: Properly destructure response object
    if (data.names && data.names.length > 0) {
      data.names.forEach((item) => {  // CHANGE: item is now an object
        const li = document.createElement("li");
        li.innerHTML = `
          <div>
            <span class="name">${escapeHtml(item.name)}</span>
            <span class="meta">${new Date(item.created_at).toLocaleString()}</span>
          </div>
          <button onclick="deleteName(${item.id})" class="delete-btn">Delete</button>
        `;
        namesList.appendChild(li);
      });
      
      showSuccess(`Found ${data.names.length} name${data.names.length !== 1 ? 's' : ''}`);
    } else {
      namesList.innerHTML = "<li><em>No names found</em></li>";
    }
  } catch (error) {
    showError(`Failed to load names: ${error.message}`);
    namesList.innerHTML = "<li><em>Error loading names</em></li>";
  } finally {
    setLoading(namesList, false);
  }
}
```

#### Fix 3: Frontend Delete Function
```javascript
// app.js - Update deleteName() to use ID instead of name
async function deleteName(nameId) {  // CHANGE: parameter is now ID (integer)
  try {
    hideMessages();
    
    // Find the name to display in confirmation
    const nameElement = event.target.closest('li').querySelector('.name');
    const nameText = nameElement.textContent;
    
    if (!confirm(`Are you sure you want to delete "${nameText}"?`)) {
      return;
    }
    
    // CHANGE: Use ID in DELETE request
    const res = await apiRequest(`/names/${nameId}`, { 
      method: "DELETE" 
    });
    
    showSuccess(`Successfully deleted "${nameText}"`);
    await loadNames();
    
  } catch (error) {
    if (error.message.includes('not found')) {
      showError(`Name was not found`);
    } else {
      showError(`Failed to delete name: ${error.message}`);
    }
    await loadNames();
  }
}
```

### Docker Image Building

#### Build Script for Images
```bash
#!/bin/bash
# build-images.sh - Build and tag images for swarm deployment

VERSION=${1:-latest}
REGISTRY=${2:-localhost}

echo "Building images with version: $VERSION"

# Build backend
docker build -t ${REGISTRY}/names-backend:${VERSION} ./backend
docker tag ${REGISTRY}/names-backend:${VERSION} ${REGISTRY}/names-backend:latest

# Build frontend
docker build -t ${REGISTRY}/names-frontend:${VERSION} ./frontend
docker tag ${REGISTRY}/names-frontend:${VERSION} ${REGISTRY}/names-frontend:latest

echo "Images built successfully"
docker images | grep names
```

#### Image Distribution to Nodes
```bash
# Option 1: Save and load (for Vagrant VMs without registry)
docker save names-backend:latest | gzip > names-backend.tar.gz
docker save names-frontend:latest | gzip > names-frontend.tar.gz

# On each VM:
docker load < names-backend.tar.gz
docker load < names-frontend.tar.gz

# Option 2: Use local registry (recommended for production)
# See "Optional: Local Docker Registry" section
```

## Deployment Workflow

### Development Workflow (Docker Compose)
```bash
# Local development on laptop - remains unchanged
cd src/
docker-compose up --build

# Run tests
docker-compose exec backend pytest

# Stop services
docker-compose down
```

### Production Workflow (Docker Swarm)

#### Initial Deployment
```bash
# 1. Initialize Swarm (one-time)
vagrant ssh manager
docker swarm init --advertise-addr 192.168.56.10

# 2. Join worker node (one-time)
vagrant ssh worker
docker swarm join --token <TOKEN> 192.168.56.10:2377

# 3. Create overlay network (one-time)
vagrant ssh manager
docker network create --driver overlay --attachable app-overlay

# 4. Build images on laptop
cd src/
./build-images.sh v1.0.0

# 5. Transfer images to manager VM
docker save names-backend:latest | vagrant ssh manager -- docker load
docker save names-frontend:latest | vagrant ssh manager -- docker load

# 6. Deploy stack
vagrant ssh manager
cd /vagrant/src
docker stack deploy -c docker-stack.yml names-app

# 7. Verify deployment
docker stack services names-app
docker service ls
docker service ps names-app_backend
docker service ps names-app_frontend
docker service ps names-app_db
```

#### Updates and Rollbacks
```bash
# Update application
./build-images.sh v1.0.1
# Transfer new images...
docker stack deploy -c docker-stack.yml names-app  # Rolling update

# Rollback if needed
docker service rollback names-app_backend
docker service rollback names-app_frontend

# Scale services
docker service scale names-app_backend=3
```

#### Stack Management
```bash
# View stack status
docker stack ls
docker stack services names-app
docker stack ps names-app

# View logs
docker service logs names-app_backend
docker service logs names-app_frontend
docker service logs names-app_db

# Remove stack
docker stack rm names-app
```

## Secrets Management

### Docker Secrets for Production
```bash
# Create secrets (on manager node)
echo "names_user" | docker secret create postgres_user -
echo "secure_password_here" | docker secret create postgres_password -
echo "namesdb" | docker secret create postgres_db -

# Update stack file to use secrets
```

```yaml
# docker-stack.yml - Updated with secrets
services:
  db:
    image: postgres:15
    secrets:
      - postgres_user
      - postgres_password
      - postgres_db
    environment:
      POSTGRES_USER_FILE: /run/secrets/postgres_user
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
      POSTGRES_DB_FILE: /run/secrets/postgres_db
    # ... rest of config

secrets:
  postgres_user:
    external: true
  postgres_password:
    external: true
  postgres_db:
    external: true
```

## Monitoring and Health Checks

### Service Health Monitoring
```bash
# Check service health
docker service ps names-app_db --format "{{.Name}}\t{{.CurrentState}}"
docker service ps names-app_backend --format "{{.Name}}\t{{.CurrentState}}"
docker service ps names-app_frontend --format "{{.Name}}\t{{.CurrentState}}"

# Watch service updates in real-time
watch -n 2 'docker service ls'

# Inspect service for detailed info
docker service inspect names-app_backend --pretty
```

### Application Health Endpoints
```bash
# Test health endpoints
curl http://192.168.56.10:8080/api/health
curl http://192.168.56.10:8080/api/health/db

# From manager node
docker service logs names-app_backend | grep "health"
```

## Network Configuration

### Overlay Network Features
- **Service Discovery**: Services can reach each other by service name (e.g., `db`, `backend`)
- **Load Balancing**: Swarm provides built-in load balancing across replicas
- **Encryption**: Enable with `--opt encrypted` flag for data plane encryption
- **Multi-host**: Services on different VMs communicate seamlessly

### Port Mapping and Access
```bash
# Frontend accessible on manager node
http://192.168.56.10:8080/

# From laptop (port forward through Vagrant)
vagrant ssh manager -- -L 8080:localhost:8080

# Then access from laptop browser
http://localhost:8080/
```

## Backup and Recovery

### Database Backup Strategy
```bash
# Backup database from worker node
vagrant ssh worker
docker exec $(docker ps -q -f name=names-app_db) \
  pg_dump -U names_user namesdb > backup_$(date +%Y%m%d).sql

# Copy backup to host
vagrant ssh worker -- cat backup_$(date +%Y%m%d).sql > ./backups/backup_$(date +%Y%m%d).sql
```

### Disaster Recovery
```bash
# Restore database
cat backup_20251030.sql | vagrant ssh worker -- \
  docker exec -i $(docker ps -q -f name=names-app_db) \
  psql -U names_user namesdb
```

## Project Structure Changes

### Updated Directory Structure
```
HW_3/
├── Vagrantfile                      # NEW: VM definitions
├── src/
│   ├── docker-compose.yml           # KEEP: Local development
│   ├── docker-stack.yml             # NEW: Swarm production deployment
│   ├── build-images.sh              # NEW: Image build script
│   ├── deploy.sh                    # NEW: Deployment automation
│   ├── backend/
│   │   ├── Dockerfile
│   │   ├── main.py                  # MODIFIED: Bug fixes
│   │   ├── requirements.txt
│   │   └── tests/
│   ├── frontend/
│   │   ├── Dockerfile
│   │   ├── app.js                   # MODIFIED: Bug fixes
│   │   ├── index.html
│   │   └── nginx.conf
│   └── db/
│       └── init.sql
├── spec/
│   ├── 10-current-state-spec.md     # UPDATED
│   ├── 20-target-spec.md            # UPDATED (this file)
│   ├── 30-plan.md                   # TO BE UPDATED
│   └── 40-tasks.md                  # TO BE UPDATED
└── README.md                        # TO BE UPDATED
```

## Optional Enhancements

### Local Docker Registry
```bash
# Run registry on manager node
docker service create --name registry --publish 5000:5000 registry:2

# Push images to registry
docker tag names-backend:latest 192.168.56.10:5000/names-backend:latest
docker push 192.168.56.10:5000/names-backend:latest

# Update stack file to pull from registry
image: 192.168.56.10:5000/names-backend:latest
```

### Logging Stack (Optional)
```yaml
# Add to docker-stack.yml for centralized logging
services:
  # ... existing services ...
  
  visualizer:
    image: dockersamples/visualizer:latest
    ports:
      - "8081:8080"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
    deploy:
      placement:
        constraints:
          - node.role == manager
```

## Success Criteria

### Deployment Success Metrics
- ✅ Swarm cluster initialized with 1 manager + 1 worker
- ✅ Frontend and backend running on manager VM
- ✅ Database running on worker VM
- ✅ Application accessible from laptop browser
- ✅ Services can communicate across overlay network
- ✅ Rolling updates work without downtime
- ✅ Docker Compose still works for local development

### Functional Requirements
- ✅ All three critical bugs fixed (GET format, display logic, DELETE)
- ✅ Names can be added successfully
- ✅ Names list displays correctly with timestamps
- ✅ Names can be deleted by ID
- ✅ Health checks pass on both endpoints
- ✅ Database data persists across service restarts

### Performance Targets
- **Startup Time**: < 60 seconds for full stack deployment
- **Response Time**: < 500ms for API calls across VMs
- **Network Latency**: < 50ms between manager and worker VMs
- **Service Recovery**: < 30 seconds for automatic restart on failure

### Documentation Requirements
- ✅ Updated current state spec with bugs documented
- ✅ Target state spec with Swarm architecture (this document)
- ✅ Migration plan with step-by-step instructions
- ✅ Task breakdown for implementation
- ✅ README with Swarm deployment instructions

This target specification defines the complete migration from Docker Compose to Docker Swarm orchestration with distributed deployment across Vagrant VMs.