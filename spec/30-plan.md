# Names Manager - Implementation Plan: Docker Swarm Migration

## Executive Summary

This plan outlines the migration of the Names Manager application from Docker Compose (single-host) to Docker Swarm (multi-host orchestration). The application will be deployed across two Vagrant VMs with proper service distribution, overlay networking, and production-grade orchestration.

**Primary Goal**: Migrate from Docker Compose to Docker Swarm with distributed deployment

**Total Timeline**: 2-3 weeks
**Resource Requirements**: 1 developer (part-time)
**Infrastructure**: 2 Vagrant VMs (manager + worker)
**Budget Impact**: None (using existing tools and local VMs)

## Implementation Phases

### Phase 0: Prerequisites & Bug Fixes
**Duration**: 2-3 days
**Priority**: CRITICAL
**Effort**: 8-10 hours

#### Milestone 0.1: Fix Critical Integration Bugs
**Goal**: Make application functional before migration

**Tasks:**
- [ ] Fix backend GET /api/names response format (wrap in `{names: [...]}`)
- [ ] Fix frontend display logic to handle response objects properly
- [ ] Fix frontend DELETE to use ID parameter instead of name string
- [ ] Update frontend to display timestamps from API response
- [ ] Test all functionality works with Docker Compose locally

**Deliverables:**
- `src/backend/main.py` - Fixed GET endpoint response format
- `src/frontend/app.js` - Fixed display and delete logic
- Working application verified with Docker Compose

**Acceptance Criteria:**
- ✅ Names list displays correctly when names exist
- ✅ Can successfully add new names
- ✅ Can successfully delete names by ID
- ✅ Timestamps display in human-readable format
- ✅ All functionality tested and verified working

**Testing:**
```bash
# Verify with Docker Compose
cd src/
docker-compose up --build
# Test: Add name, view list, delete name
docker-compose down
```

---

### Phase 1: Infrastructure Setup
**Duration**: 3-4 days
**Priority**: High
**Effort**: 10-12 hours

#### Milestone 1.1: Vagrant VM Configuration
**Goal**: Set up two VMs for Swarm cluster

**Tasks:**
- [ ] Create `Vagrantfile` with manager and worker VM definitions
- [ ] Configure manager VM (laptop): Ubuntu 22.04, 2GB RAM, 2 CPU, IP: 192.168.56.10
- [ ] Configure worker VM (lab machine): Ubuntu 22.04, 2GB RAM, 2 CPU, IP: 192.168.56.11
- [ ] Set up private network between VMs
- [ ] Configure port forwarding (80:80 on manager to host)
- [ ] Provision Docker Engine on both VMs

**Deliverables:**
- `Vagrantfile` with both VM definitions
- Provisioning script for Docker installation
- Network configuration for VM communication

**Acceptance Criteria:**
- ✅ Both VMs can be started with `vagrant up`
- ✅ VMs can ping each other by IP address
- ✅ Docker installed and running on both VMs
- ✅ SSH access works for both VMs
- ✅ Port 80 accessible from laptop browser

**Vagrant Configuration:**
```ruby
Vagrant.configure("2") do |config|
  # Manager VM (laptop)
  config.vm.define "manager" do |manager|
    manager.vm.box = "ubuntu/jammy64"
    manager.vm.hostname = "swarm-manager"
    manager.vm.network "private_network", ip: "192.168.56.10"
    manager.vm.network "forwarded_port", guest: 80, host: 8080
    manager.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
      vb.name = "names-manager"
    end
    manager.vm.provision "shell", path: "vagrant/install-docker.sh"
  end
  
  # Worker VM (lab machine)
  config.vm.define "worker" do |worker|
    worker.vm.box = "ubuntu/jammy64"
    worker.vm.hostname = "swarm-worker"
    worker.vm.network "private_network", ip: "192.168.56.11"
    worker.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
      vb.name = "names-worker"
    end
    worker.vm.provision "shell", path: "vagrant/install-docker.sh"
  end
end
```

**Testing:**
```bash
vagrant up
vagrant ssh manager -c "docker --version"
vagrant ssh worker -c "docker --version"
vagrant ssh manager -c "ping -c 3 192.168.56.11"
```

#### Milestone 1.2: Docker Swarm Initialization
**Goal**: Create Swarm cluster with manager and worker

**Tasks:**
- [ ] Initialize Swarm on manager VM
- [ ] Join worker VM to Swarm cluster
- [ ] Verify cluster status and node roles
- [ ] **Label worker node with `role=db`** (REQUIRED for placement constraints)
- [ ] Create overlay network `appnet`
- [ ] Configure network for service discovery

**Deliverables:**
- Swarm cluster with 1 manager + 1 worker
- Worker node labeled with `role=db`
- Overlay network `appnet` created
- Documentation of join tokens (for recovery)

**Acceptance Criteria:**
- ✅ `docker node ls` shows both nodes as Ready
- ✅ Manager node shows as Leader
- ✅ Worker node shows as Active
- ✅ Worker node labeled with `role=db`
- ✅ Overlay network `appnet` exists
- ✅ Network supports DNS service discovery

**Commands:**
```bash
# On manager VM
vagrant ssh manager
docker swarm init --advertise-addr 192.168.56.10
# Save the join token!

# On worker VM
vagrant ssh worker
docker swarm join --token <TOKEN> 192.168.56.10:2377

# Back on manager - Label the worker node for database placement
vagrant ssh manager
docker node ls  # Note the worker node ID or hostname
docker node update --label-add role=db <worker-node-id-or-hostname>

# Verify label
docker node inspect <worker-node-id> --format '{{.Spec.Labels}}'
# Should show: map[role:db]

# Create overlay network
docker network create --driver overlay --attachable appnet
docker network ls
```

---

### Phase 2: Docker Stack Configuration
**Duration**: 3-4 days
**Priority**: High
**Effort**: 12-15 hours

#### Milestone 2.1: Create Docker Stack File
**Goal**: Define Swarm deployment configuration

**Tasks:**
- [ ] Create `swarm/stack.yaml` (REQUIRED name/location)
- [ ] Configure database service with `node.labels.role == db` constraint
- [ ] Configure api service with DATABASE_URL pointing to `db` service name
- [ ] Configure web service with port mapping `80:80`
- [ ] Set up overlay network `appnet` for all services
- [ ] Configure database volume `dbdata` bound to `/var/lib/postgres-data` on lab node
- [ ] Add health checks (pg_isready for DB, /api/health for backend)
- [ ] Configure service replicas (api: 2, web: 1, db: 1)

**Deliverables:**
- `swarm/stack.yaml` with complete service definitions (REQUIRED)
- Health check configurations for all services
- Placement constraints using node labels
- Volume configuration for persistent database storage

**Acceptance Criteria:**
- ✅ Stack file at `swarm/stack.yaml` (exact path required)
- ✅ Database uses constraint: `node.labels.role == db`
- ✅ Database volume `dbdata` bound to `/var/lib/postgres-data`
- ✅ Web service publishes port `80:80`
- ✅ API service has DATABASE_URL with service name `db`
- ✅ Network `appnet` with `driver: overlay`
- ✅ All services use `appnet` overlay network
- ✅ DB health check uses `pg_isready`
- ✅ API health check uses `/api/health` endpoint
- ✅ Service discovery works (api can reach db by name)

**Required Stack Configuration** (`swarm/stack.yaml`):
```yaml
version: "3.8"

services:
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: names_user
      POSTGRES_PASSWORD: names_pass
      POSTGRES_DB: namesdb
    volumes:
      - dbdata:/var/lib/postgresql/data
    networks:
      - appnet
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.role == db
      restart_policy:
        condition: on-failure
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U names_user -d namesdb"]
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    image: localhost/names-backend:latest
    environment:
      DATABASE_URL: postgresql+psycopg2://names_user:names_pass@db:5432/namesdb
      MAX_NAME_LENGTH: 50
      LOG_LEVEL: INFO
    networks:
      - appnet
    deploy:
      replicas: 2
      placement:
        constraints:
          - node.role == manager
      restart_policy:
        condition: on-failure
    depends_on:
      - db

  web:
    image: localhost/names-frontend:latest
    ports:
      - "80:80"
    networks:
      - appnet
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      restart_policy:
        condition: on-failure
    depends_on:
      - api

networks:
  appnet:
    driver: overlay

volumes:
  dbdata:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /var/lib/postgres-data
```

**Critical Requirements Checklist:**
- ✅ File location: `swarm/stack.yaml` (not `src/docker-stack.yml`)
- ✅ Network: `appnet` with `driver: overlay`
- ✅ Volume: `dbdata` bound to `/var/lib/postgres-data` on lab node
- ✅ DB placement: `node.labels.role == db` (uses custom label)
- ✅ Web ports: `["80:80"]` (exact format)
- ✅ API environment: `DATABASE_URL` pointing to `db` by service name
- ✅ Service names: `db`, `api`, `web` (standard naming)

#### Milestone 2.2: Update Health Check Endpoint
**Goal**: Ensure /api/health returns correct format

**Tasks:**
- [ ] Verify `/api/health` endpoint exists in backend
- [ ] Update response format to `{"status":"ok"}` (if different)
- [ ] Test health endpoint locally with Docker Compose
- [ ] Add health check to backend service in stack file

**Deliverables:**
- `src/backend/main.py` - Updated health endpoint (if needed)
- Verified health endpoint returns `{"status":"ok"}`

**Acceptance Criteria:**
- ✅ GET /api/health returns 200 status
- ✅ Response body is `{"status":"ok"}` (exact format)
- ✅ Endpoint accessible without authentication
- ✅ Health check works in Docker Compose

**Code Verification:**
```python
@app.route("/api/health", methods=["GET"])
def health_check():
    """Basic health check endpoint that returns application status."""
    return jsonify({"status": "ok"}), 200
```

---

### Phase 3: Image Building & Distribution
**Duration**: 2-3 days
**Priority**: High
**Effort**: 8-10 hours

#### Milestone 3.1: Build Docker Images
**Goal**: Create production images for deployment

**Tasks:**
- [ ] Create image build script `build-images.sh`
- [ ] Build backend image with fixed code
- [ ] Build frontend image with fixed code
- [ ] Tag images appropriately for local use
- [ ] Test images locally with Docker Compose
- [ ] Verify all bug fixes included in images

**Deliverables:**
- `src/build-images.sh` - Automated build script
- `localhost/names-backend:latest` image
- `localhost/names-frontend:latest` image

**Acceptance Criteria:**
- ✅ Images build without errors
- ✅ Images contain all bug fixes
- ✅ Images tagged correctly
- ✅ Images tested and working locally

**Build Script:**
```bash
#!/bin/bash
# src/build-images.sh

set -e

echo "Building Names Manager Docker images..."

# Build backend
echo "Building backend image..."
docker build -t localhost/names-backend:latest ./backend

# Build frontend  
echo "Building frontend image..."
docker build -t localhost/names-frontend:latest ./frontend

echo "Build complete!"
docker images | grep names
```

#### Milestone 3.2: Transfer Images to VMs
**Goal**: Make images available on Swarm nodes

**Tasks:**
- [ ] Save backend image to tar file
- [ ] Save frontend image to tar file
- [ ] Transfer images to manager VM
- [ ] Load images on manager VM
- [ ] Verify images available on manager node

**Deliverables:**
- Images available on manager VM
- Documentation of transfer process

**Acceptance Criteria:**
- ✅ Backend image available on manager VM
- ✅ Frontend image available on manager VM
- ✅ `docker images` shows both images on manager
- ✅ Worker node has access to postgres:15 image

**Transfer Commands:**
```bash
# On laptop
cd src/
./build-images.sh

# Save images
docker save localhost/names-backend:latest | gzip > names-backend.tar.gz
docker save localhost/names-frontend:latest | gzip > names-frontend.tar.gz

# Transfer to manager VM
scp -P $(vagrant port manager --guest 22) \
  names-backend.tar.gz names-frontend.tar.gz \
  vagrant@localhost:/home/vagrant/

# Load on manager VM
vagrant ssh manager
gunzip < names-backend.tar.gz | docker load
gunzip < names-frontend.tar.gz | docker load
docker images
```

---

### Phase 4: Deployment & Testing
**Duration**: 3-4 days
**Priority**: High  
**Effort**: 12-15 hours

#### Milestone 4.1: Database Storage Setup (CRITICAL)
**Goal**: Configure persistent storage on lab node for database

**REQUIREMENT**: Database service must run ONLY on lab Linux node and use persistent storage on that node so data survives container replacement and restarts.

**Tasks:**
- [ ] SSH to worker VM (lab node)
- [ ] Create directory `/var/lib/postgres-data` (REQUIRED path)
- [ ] Set appropriate permissions (chmod 700, chown 999:999)
- [ ] Verify directory accessible and writable
- [ ] Ensure directory survives VM restarts
- [ ] Document storage path and configuration

**Deliverables:**
- `/var/lib/postgres-data` directory on worker VM (lab node)
- Correct ownership and permissions for PostgreSQL
- Documentation of storage configuration
- Verified data persistence

**Acceptance Criteria:**
- ✅ Directory `/var/lib/postgres-data` exists on worker/lab node ONLY
- ✅ Permissions: 700 (drwx------)
- ✅ Owner: 999:999 (PostgreSQL container user)
- ✅ PostgreSQL can write to directory
- ✅ Data persists across container restarts
- ✅ Data persists across service updates
- ✅ Volume bound correctly in stack.yaml
- ✅ Path documented in README

**Commands:**
```bash
# SSH to worker/lab node
vagrant ssh worker

# Create storage directory
sudo mkdir -p /var/lib/postgres-data

# Set permissions (PostgreSQL requires 700)
sudo chmod 700 /var/lib/postgres-data

# Set ownership (999:999 is PostgreSQL's UID/GID in container)
sudo chown 999:999 /var/lib/postgres-data

# Verify configuration
ls -ld /var/lib/postgres-data
# Expected output: drwx------ 2 999 999 ... /var/lib/postgres-data

# Test writability (should succeed)
sudo -u '#999' touch /var/lib/postgres-data/test.txt
sudo -u '#999' rm /var/lib/postgres-data/test.txt
```

**Why This Matters:**
- Database data MUST persist across container failures
- Database runs ONLY on lab node (not manager/laptop)
- `/var/lib/postgres-data` is the REQUIRED mount point
- Incorrect permissions will cause PostgreSQL to fail on startup
- Volume binding ensures data stays on lab node filesystem

#### Milestone 4.2: Initial Stack Deployment
**Goal**: Deploy application to Swarm cluster

**Tasks:**
- [ ] Ensure `swarm/stack.yaml` exists and is correct
- [ ] Copy stack file to manager VM (or use Vagrant shared folder)
- [ ] Deploy stack with `docker stack deploy`
- [ ] Verify all services created
- [ ] Check service status and placement
- [ ] Verify database on worker/lab node with correct label
- [ ] Verify api/web on manager node
- [ ] Check service logs for errors

**Deliverables:**
- Running stack `names-app` on Swarm cluster
- All services in Running state
- Logs showing successful startup
- Database using persistent storage on lab node

**Acceptance Criteria:**
- ✅ Stack deploys without errors
- ✅ All 3 services show as running (db, api, web)
- ✅ Database service on worker/lab node (labeled with role=db)
- ✅ API service on manager node (2 replicas)
- ✅ Web service on manager node (1 replica)
- ✅ Database using `/var/lib/postgres-data` storage
- ✅ No error messages in logs

**Deployment Commands:**
```bash
# Option 1: Copy stack file to manager
scp -P $(vagrant port manager --guest 22) \
  swarm/stack.yaml \
  vagrant@localhost:/home/vagrant/

# Option 2: Use Vagrant shared folder (recommended)
# The /vagrant folder is automatically shared
# So swarm/stack.yaml is accessible at /vagrant/swarm/stack.yaml

# Deploy stack from manager VM
vagrant ssh manager
docker stack deploy -c /vagrant/swarm/stack.yaml names-app

# Verify deployment
docker stack ls
docker stack services names-app
docker stack ps names-app

# Check service placement (MUST match requirements)
docker service ps names-app_db       # MUST be on worker (labeled role=db)
docker service ps names-app_api      # MUST be on manager
docker service ps names-app_web      # MUST be on manager

# Verify database constraint worked
docker service inspect names-app_db --format '{{.Spec.TaskTemplate.Placement}}'
# Should show: {[node.labels.role == db]}

# Check volume mount on database
docker service inspect names-app_db --format '{{.Spec.TaskTemplate.ContainerSpec.Mounts}}'
# Should reference dbdata volume
```

#### Milestone 4.3: Storage Persistence Verification (CRITICAL)
**Goal**: Verify database data persists across container lifecycle events

**REQUIREMENT**: Database data MUST survive container replacement and restarts.

**Tasks:**
- [ ] Add test data to database
- [ ] Verify data stored in `/var/lib/postgres-data` on worker node
- [ ] Force container restart and verify data persists
- [ ] Update service (rolling update) and verify data persists
- [ ] Remove and redeploy service, verify data persists
- [ ] Document persistence behavior

**Deliverables:**
- Verified data persistence across all lifecycle events
- Documentation of storage behavior
- Proof that data survives container replacement

**Acceptance Criteria:**
- ✅ Data added through API visible in database
- ✅ Files created in `/var/lib/postgres-data` on worker node
- ✅ Data survives `docker service update --force`
- ✅ Data survives container crashes
- ✅ Data survives service scale down/up
- ✅ Data survives stack removal/redeployment

**Testing Commands:**
```bash
# Add test data through API
curl -X POST http://localhost:8080/api/names \
  -H "Content-Type: application/json" \
  -d '{"name":"Persistence Test"}'

# Verify data in database
vagrant ssh worker
sudo ls -lh /var/lib/postgres-data/
# Should see PostgreSQL data files (base/, pg_wal/, etc.)

# Test 1: Force container restart
vagrant ssh manager
docker service update --force names-app_db
sleep 30
curl http://localhost:8080/api/names | grep "Persistence Test"
# ✅ Data should still be present

# Test 2: Rolling update simulation
docker service scale names-app_db=0
sleep 10
docker service scale names-app_db=1
sleep 30
curl http://localhost:8080/api/names | grep "Persistence Test"
# ✅ Data should still be present

# Test 3: Stack remove/redeploy
docker stack rm names-app
sleep 20
docker stack deploy -c /vagrant/swarm/stack.yaml names-app
sleep 60
curl http://localhost:8080/api/names | grep "Persistence Test"
# ✅ Data should STILL be present (this is the ultimate test!)

# Verify volume binding on worker node
vagrant ssh worker
sudo du -sh /var/lib/postgres-data
# Should show database size (several MB after usage)
```

#### Milestone 4.4: Service Discovery & Connectivity Testing
**Goal**: Verify inter-service communication

**Tasks:**
- [ ] Test api can reach database by DNS name `db`
- [ ] Verify web can reach api by DNS name `api`
- [ ] Test database health check from api service
- [ ] Verify overlay network connectivity
- [ ] Test service discovery resolution

**Deliverables:**
- Verified service-to-service communication
- Health checks passing
- Documentation of connectivity tests

**Acceptance Criteria:**
- ✅ API logs show successful database connection via name `db`
- ✅ Database health check passes
- ✅ API health endpoint returns `{"status":"ok"}`
- ✅ Web can make API calls to `api` service
- ✅ DNS resolution works (can resolve service names)
- ✅ DATABASE_URL environment variable uses service name `db`

**Testing Commands:**
```bash
# Test DNS resolution from api to db
vagrant ssh manager
docker exec $(docker ps -q -f name=names-app_api) ping -c 3 db

# Verify DATABASE_URL uses service name
docker service inspect names-app_api --format '{{range .Spec.TaskTemplate.ContainerSpec.Env}}{{println .}}{{end}}' | grep DATABASE_URL
# Should show: DATABASE_URL=postgresql+psycopg2://...@db:5432/...
#                                                     ^^
#                                              service name, not IP

# Test database connectivity from api
docker exec $(docker ps -q -f name=names-app_api) \
  curl http://localhost:8000/api/health/db

# Test api health
docker exec $(docker ps -q -f name=names-app_web) \
  curl http://api:8000/api/health
```

#### Milestone 4.5: Application Functional Testing
**Goal**: Verify all application features work end-to-end

**Tasks:**
- [ ] Access application from laptop browser (http://localhost:8080 via port 80)
- [ ] Test adding new names
- [ ] Test viewing names list
- [ ] Test deleting names
- [ ] Verify timestamps display correctly
- [ ] Test error handling
- [ ] Verify data persists after service restart

**Deliverables:**
- Fully functional application accessible from browser
- All CRUD operations working across distributed services
- Test results documented

**Acceptance Criteria:**
- ✅ Application accessible at http://localhost:8080 (web service port 80:80)
- ✅ Can successfully add names (web → api → db across VMs)
- ✅ Names list displays with timestamps
- ✅ Can successfully delete names by ID
- ✅ Error messages display appropriately
- ✅ Data persists after `docker service update`
- ✅ Application works across manager/worker VM boundary

**Test Scenarios:**
1. **Add Name**: Enter "John Doe", verify appears in list with timestamp
   - Tests: web → api (manager) → db (worker) communication
2. **Add Multiple**: Add 3-5 names, verify all appear
   - Tests: Multiple requests, load balancing across api replicas
3. **Delete**: Delete middle name, verify removed
   - Tests: DELETE operation across distributed services
4. **Persistence**: Restart api service, verify data still present
   - Tests: Database persistence on worker node
5. **Health Checks**: Visit /api/health, verify `{"status":"ok"}`
   - Tests: Health endpoint format requirement
6. **Error Handling**: Try empty name, verify error message
   - Tests: Validation and error propagation

---

### Phase 5: Production Hardening
**Duration**: 2-3 days
**Priority**: Medium
**Effort**: 8-10 hours

#### Milestone 5.1: Secrets Management
**Goal**: Secure database credentials

**Tasks:**
- [ ] Create Docker secrets for database credentials
- [ ] Update stack file to use secrets
- [ ] Update backend to read from secrets files
- [ ] Redeploy with secrets configuration
- [ ] Verify functionality with secrets

**Deliverables:**
- Docker secrets created for PostgreSQL credentials
- Updated stack file using secrets
- Backend reading credentials from `/run/secrets/`

**Acceptance Criteria:**
- ✅ Secrets created in Swarm
- ✅ No plaintext credentials in stack file
- ✅ Application works with secrets
- ✅ Database connection successful

**Commands:**
```bash
# Create secrets
echo "names_user" | docker secret create postgres_user -
echo "secure_password" | docker secret create postgres_password -
echo "namesdb" | docker secret create postgres_db -

# List secrets
docker secret ls
```

#### Milestone 5.2: Deployment Automation
**Goal**: Streamline deployment process

**Tasks:**
- [ ] Create deployment script `deploy.sh`
- [ ] Add health check verification to script
- [ ] Add rollback capability
- [ ] Create update script for rolling updates
- [ ] Document deployment procedures

**Deliverables:**
- `src/deploy.sh` - Automated deployment script
- `src/update.sh` - Rolling update script
- Deployment documentation in README

**Acceptance Criteria:**
- ✅ Single command deploys entire stack
- ✅ Script verifies successful deployment
- ✅ Rollback process documented and tested
- ✅ Update process doesn't cause downtime

**Deploy Script:**
```bash
#!/bin/bash
# src/deploy.sh

set -e

echo "Deploying Names Manager to Docker Swarm..."

# Build images
./build-images.sh

# Transfer images to manager
echo "Transferring images to manager VM..."
docker save localhost/names-backend:latest | \
  vagrant ssh manager -- docker load
docker save localhost/names-frontend:latest | \
  vagrant ssh manager -- docker load

# Deploy stack
echo "Deploying stack..."
vagrant ssh manager -- docker stack deploy -c /vagrant/src/docker-stack.yml names-app

# Wait for services
echo "Waiting for services to start..."
sleep 10

# Verify deployment
echo "Verifying deployment..."
vagrant ssh manager -- docker stack services names-app

echo "Deployment complete!"
echo "Access application at: http://localhost:8080"
```

#### Milestone 5.3: Monitoring & Logging Setup
**Goal**: Enable operational visibility

**Tasks:**
- [ ] Document log viewing procedures
- [ ] Create monitoring commands cheat sheet
- [ ] Test log aggregation from services
- [ ] Document health check monitoring
- [ ] Create troubleshooting guide

**Deliverables:**
- `docs/OPERATIONS.md` - Operations guide
- Commands for viewing logs and status
- Troubleshooting procedures

**Acceptance Criteria:**
- ✅ Can view logs from all services
- ✅ Can monitor service health
- ✅ Can track service placement
- ✅ Troubleshooting guide tested and accurate

**Monitoring Commands:**
```bash
# View service logs
docker service logs names-app_backend -f
docker service logs names-app_frontend -f
docker service logs names-app_db -f

# Monitor service status
watch -n 2 'docker service ls'
docker service ps names-app_backend --no-trunc

# Check health
docker service inspect names-app_db --format '{{.Spec.TaskTemplate.HealthCheck}}'
```

---

## Risk Management

### High-Risk Items

#### Risk 1: Network Connectivity Between VMs
**Impact**: High | **Probability**: Medium
**Description**: VMs may not be able to communicate, breaking overlay network

**Mitigation:**
- Test VM networking early in Phase 1
- Verify ping/SSH works between VMs before Swarm init
- Document IP addresses and network configuration
- Use Vagrant's built-in networking features
- Have fallback to single-VM deployment for testing

**Contingency:**
- If VMs can't communicate, use Docker Compose as fallback
- Check firewall rules on both VMs
- Verify VirtualBox network adapters configured correctly

#### Risk 2: Swarm Join Token Issues
**Impact**: High | **Probability**: Low
**Description**: Worker may fail to join Swarm, or token gets lost

**Mitigation:**
- Save join token immediately after swarm init
- Document token in secure location
- Test join process immediately after init
- Know how to regenerate token if needed

**Contingency:**
```bash
# Regenerate worker join token
docker swarm join-token worker
```

#### Risk 3: Service Placement Constraints Fail
**Impact**: High | **Probability**: Low
**Description**: Services don't deploy to correct nodes

**Mitigation:**
- Verify node labels before deployment
- Test placement with simple service first
- Check `docker node ls` output carefully
- Understand node role vs hostname constraints

**Contingency:**
- Remove placement constraints temporarily for testing
- Manually label nodes if needed
- Deploy to any available node initially

### Medium-Risk Items

#### Risk 4: Database Volume Permissions
**Impact**: Medium | **Probability**: Medium
**Description**: PostgreSQL can't write to /var/lib/postgres-data

**Mitigation:**
- Set correct permissions before deployment (chmod 700, chown 999:999)
- Test with simple postgres container first
- Check SELinux/AppArmor settings if on restrictive distro
- Document permission requirements

**Contingency:**
- Use Docker volume instead of bind mount
- Try different mount path
- Run with relaxed permissions temporarily for testing

#### Risk 5: Image Transfer Between Laptop and VMs
**Impact**: Medium | **Probability**: Medium  
**Description**: Images may be too large or transfer may fail

**Mitigation:**
- Use Docker save/load with compression
- Test transfer with small image first
- Consider setting up local registry if repeated transfers needed
- Use Vagrant synced folders to share files

**Contingency:**
- Build images directly on manager VM
- Use smaller base images
- Set up Docker registry service

#### Risk 6: DNS Service Discovery Not Working
**Impact**: Medium | **Probability**: Low
**Description**: Services can't reach each other by name

**Mitigation:**
- Verify all services on same overlay network
- Test DNS resolution with ping/nslookup
- Check network attachable flag set
- Use docker exec to test from inside containers

**Contingency:**
- Use IP addresses temporarily
- Recreate overlay network
- Check Swarm networking status

### Low-Risk Items

#### Risk 7: Port Conflicts
**Impact**: Low | **Probability**: Low
**Description**: Port 80 or 8080 already in use on laptop

**Mitigation:**
- Check ports before starting VMs
- Use different host port if needed (e.g., 8081)
- Document port mappings clearly

**Contingency:**
- Change FRONTEND_PORT in configuration
- Use alternative port mapping in Vagrantfile

#### Risk 8: Rolling Updates Cause Brief Downtime
**Impact**: Low | **Probability**: Medium
**Description**: Service updates may briefly interrupt service

**Mitigation:**
- Use rolling update configuration
- Set appropriate update delay
- Test updates with backend replicas (2+)
- Do updates during low-usage periods

**Contingency:**
- Accept brief downtime for small project
- Increase replica count before updates

---

## Rollout Strategy

### Pre-Work Preparation
- [ ] Backup current working system (Git commit/tag)
- [ ] Create feature branch `swarm-orchestration`
- [ ] Verify current Docker Compose setup works
- [ ] Document current state in spec
- [ ] Review Vagrant and VirtualBox installation

### Implementation Approach

#### Phase-by-Phase Rollout
Each phase must be completed and verified before moving to next phase:

1. **Phase 0**: Fix bugs, verify working with Compose
2. **Phase 1**: Set up VMs and Swarm cluster (infrastructure only)
3. **Phase 2**: Create stack file and configuration (no deployment yet)
4. **Phase 3**: Build and distribute images
5. **Phase 4**: Deploy and test (the critical phase)
6. **Phase 5**: Harden and document

#### Testing Strategy
- **After each milestone**: Run acceptance criteria tests
- **Before next phase**: Ensure previous phase fully working
- **Continuous**: Keep Docker Compose working for local dev/testing
- **End-to-end**: Full application test in Phase 4

#### Rollback Plan

**If Phase 4 deployment fails:**
1. Remove stack: `docker stack rm names-app`
2. Fix issue identified in logs
3. Rebuild images if code changes needed
4. Redeploy stack

**If critical issues found:**
1. Keep Docker Compose as working baseline
2. Fix Swarm issues separately  
3. Don't delete Compose files until Swarm proven working
4. Can always fall back to Compose on laptop

**Git Strategy:**
```bash
# Work on feature branch
git checkout -b swarm-orchestration

# Commit after each milestone
git add -A
git commit -m "Phase X Milestone Y: Description"

# If need to rollback
git log  # Find last working commit
git checkout <commit-hash>
```

### Parallel Development
- **Keep Compose**: `docker-compose.yml` remains for local development
- **Add Swarm**: `docker-stack.yml` for production deployment
- **Both work**: Can switch between them as needed
- **No conflicts**: They use different files and commands

---

## Success Criteria

### Phase 0: Bug Fixes
- [ ] ✅ GET /api/names returns `{names: [...]}`
- [ ] ✅ Frontend displays names with timestamps
- [ ] ✅ DELETE works using ID parameter
- [ ] ✅ All functionality verified with Docker Compose
- [ ] ✅ No errors in browser console

### Phase 1: Infrastructure
- [ ] ✅ Both VMs running and accessible
- [ ] ✅ Swarm cluster initialized (1 manager + 1 worker)
- [ ] ✅ `docker node ls` shows 2 Ready nodes
- [ ] ✅ Overlay network `appnet` created
- [ ] ✅ VMs can ping each other
- [ ] ✅ Port forwarding works (can access port 80)

### Phase 2: Stack Configuration  
- [ ] ✅ **`swarm/stack.yaml` created** (exact path required)
- [ ] ✅ Network `appnet` with `driver: overlay`
- [ ] ✅ Volume `dbdata` bound to `/var/lib/postgres-data` on lab node
- [ ] ✅ DB placement: `node.labels.role == db` (exact constraint)
- [ ] ✅ Web service ports: `["80:80"]`
- [ ] ✅ API service DATABASE_URL: points to service name `db`
- [ ] ✅ Health checks configured (pg_isready, /api/health)
- [ ] ✅ Stack file validates without errors

### Phase 3: Images
- [ ] ✅ Backend image built with bug fixes
- [ ] ✅ Frontend image built with bug fixes
- [ ] ✅ Images tagged correctly
- [ ] ✅ Images transferred to manager VM
- [ ] ✅ `docker images` shows both images on manager

### Phase 4: Deployment
- [ ] ✅ Database storage `/var/lib/postgres-data` created on worker/lab node
- [ ] ✅ Directory permissions: 700, owner 999:999
- [ ] ✅ Worker node labeled with `role=db`
- [ ] ✅ Stack deploys from `swarm/stack.yaml` without errors
- [ ] ✅ All 3 services running (db, api, web)
- [ ] ✅ DB service on worker/lab node (constraint: `node.labels.role == db`) ✓
- [ ] ✅ API service on manager node (2 replicas) ✓
- [ ] ✅ Web service on manager node (1 replica) ✓
- [ ] ✅ API can reach DB by DNS name `db` (DATABASE_URL)
- [ ] ✅ Web can reach API by DNS name `api`
- [ ] ✅ Application accessible at http://localhost:8080 (port 80:80)
- [ ] ✅ Can add names successfully
- [ ] ✅ Can view names with timestamps
- [ ] ✅ Can delete names by ID
- [ ] ✅ **Data persists after container replacement**
- [ ] ✅ **Data persists after service restart**
- [ ] ✅ **Data persists after stack removal/redeployment**
- [ ] ✅ Health checks passing (pg_isready, {"status":"ok"})

### Phase 5: Hardening
- [ ] ✅ Secrets configured for database credentials
- [ ] ✅ Deployment script working
- [ ] ✅ Rolling updates tested
- [ ] ✅ Monitoring commands documented
- [ ] ✅ Operations guide created

### Overall Project Success

#### Functional Requirements (MUST HAVE)
- [ ] ✅ Application runs on Docker Swarm (not Compose)
- [ ] ✅ Frontend and backend on manager VM (laptop)
- [ ] ✅ Database on worker VM (lab machine)
- [ ] ✅ Port 80 exposed on manager node
- [ ] ✅ Database data stored at `/var/lib/postgres-data`
- [ ] ✅ Overlay network `appnet` for service communication
- [ ] ✅ DNS service discovery working (api → db by name)
- [ ] ✅ DB health check: `pg_isready` passes
- [ ] ✅ API health check: `/api/health` returns `{"status":"ok"}`
- [ ] ✅ All CRUD operations functional
- [ ] ✅ Docker Compose still works for local development

#### Quality Requirements (SHOULD HAVE)
- [ ] ✅ Clean separation: Compose for dev, Stack for prod
- [ ] ✅ Documentation complete and accurate
- [ ] ✅ Deployment process documented
- [ ] ✅ No hardcoded credentials in stack file
- [ ] ✅ Services recover automatically on failure
- [ ] ✅ Logs accessible for debugging
- [ ] ✅ Troubleshooting guide available

#### Performance Requirements (NICE TO HAVE)
- [ ] ✅ Full stack starts within 60 seconds
- [ ] ✅ API responses under 500ms
- [ ] ✅ Zero downtime during rolling updates
- [ ] ✅ Backend scaled to 2+ replicas

---

## Acceptance Testing

### Pre-Deployment Testing (Phase 0)
**Environment**: Local laptop with Docker Compose

1. **Add Name Test**
   - Enter valid name "John Doe"
   - Verify appears in list with timestamp
   - ✅ Pass criteria: Name displayed correctly

2. **View Names Test**
   - Add 3-5 names
   - Verify all appear in list
   - Verify timestamps in human-readable format
   - ✅ Pass criteria: All names visible with timestamps

3. **Delete Name Test**
   - Click delete button on any name
   - Confirm deletion
   - Verify name removed from list
   - ✅ Pass criteria: Name successfully deleted

4. **Error Handling Test**
   - Try to add empty name
   - Try to add name > 50 characters
   - ✅ Pass criteria: Appropriate error messages shown

### Infrastructure Testing (Phase 1)

1. **VM Connectivity Test**
   ```bash
   vagrant ssh manager -c "ping -c 3 192.168.56.11"
   vagrant ssh worker -c "ping -c 3 192.168.56.10"
   ```
   - ✅ Pass criteria: Both pings succeed

2. **Swarm Cluster Test**
   ```bash
   vagrant ssh manager -c "docker node ls"
   ```
   - ✅ Pass criteria: Shows 2 nodes, both Ready
   - Manager shows as Leader
   - Worker shows as Active

3. **Network Test**
   ```bash
   vagrant ssh manager -c "docker network ls | grep appnet"
   ```
   - ✅ Pass criteria: Overlay network exists

### Deployment Testing (Phase 4)

1. **Service Placement Test**
   ```bash
   vagrant ssh manager -c "docker service ps names-app_db"
   vagrant ssh manager -c "docker service ps names-app_backend"
   vagrant ssh manager -c "docker service ps names-app_frontend"
   ```
   - ✅ Pass criteria: 
     - DB running on worker node
     - Backend running on manager node
     - Frontend running on manager node

2. **DNS Service Discovery Test**
   ```bash
   vagrant ssh manager -c "docker exec \$(docker ps -q -f name=backend) ping -c 3 db"
   ```
   - ✅ Pass criteria: Backend can reach DB by name

3. **Health Check Test**
   ```bash
   curl http://localhost:8080/api/health
   curl http://localhost:8080/api/health/db
   ```
   - ✅ Pass criteria:
     - `/api/health` returns `{"status":"ok"}`
     - `/api/health/db` returns healthy status

4. **Database Connection Test**
   ```bash
   vagrant ssh manager -c "docker service logs names-app_backend | grep 'Database connection'"
   ```
   - ✅ Pass criteria: No connection errors in logs

### Functional Testing (Phase 4)
**Environment**: Swarm deployment via browser at http://localhost:8080

1. **Add Name via Swarm**
   - Open http://localhost:8080
   - Add name "Alice Smith"
   - ✅ Pass criteria: Name appears in list

2. **View Names via Swarm**
   - Verify previously added names visible
   - Check timestamps display correctly
   - ✅ Pass criteria: All names with timestamps visible

3. **Delete Name via Swarm**
   - Delete any name using delete button
   - ✅ Pass criteria: Name removed successfully

4. **Data Persistence Test**
   ```bash
   vagrant ssh manager -c "docker service update --force names-app_backend"
   ```
   - Wait for update to complete
   - Refresh browser
   - ✅ Pass criteria: Data still present after restart

5. **Cross-VM Communication Test**
   - Add name (frontend → backend → database across VMs)
   - Verify name stored (database on worker)
   - View name (retrieved from database on worker)
   - ✅ Pass criteria: Full round-trip works

### Load Testing (Optional)

1. **Multiple Concurrent Requests**
   - Add 10 names rapidly
   - ✅ Pass criteria: All saved successfully

2. **Backend Scaling**
   ```bash
   vagrant ssh manager -c "docker service scale names-app_backend=3"
   ```
   - Test application still works
   - ✅ Pass criteria: No errors with 3 replicas

### Rollback Testing (Phase 5)

1. **Service Rollback Test**
   ```bash
   vagrant ssh manager -c "docker service rollback names-app_backend"
   ```
   - ✅ Pass criteria: Service rolls back successfully

2. **Stack Removal/Redeploy Test**
   ```bash
   vagrant ssh manager -c "docker stack rm names-app"
   # Wait for removal
   vagrant ssh manager -c "docker stack deploy -c docker-stack.yml names-app"
   ```
   - ✅ Pass criteria: Stack redeploys successfully

---

## Timeline Summary

| Phase | Duration | Effort | Dependencies | Deliverable |
|-------|----------|--------|--------------|-------------|
| Phase 0 | 2-3 days | 8-10h | None | Working app with bug fixes |
| Phase 1 | 3-4 days | 10-12h | Phase 0 | Swarm cluster ready |
| Phase 2 | 3-4 days | 12-15h | Phase 1 | Stack file configured |
| Phase 3 | 2-3 days | 8-10h | Phase 2 | Images built & transferred |
| Phase 4 | 3-4 days | 12-15h | Phase 3 | App deployed & tested |
| Phase 5 | 2-3 days | 8-10h | Phase 4 | Production ready |
| **Total** | **15-21 days** | **58-72h** | Sequential | Swarm deployment |

**Realistic Timeline**: 3 weeks part-time (15-20 hours/week)

---

## Deliverables Checklist

### Code Changes
- [ ] `src/backend/main.py` - Bug fixes for GET/health endpoints
  - Fix GET /api/names to return `{names: [...]}`
  - Ensure /api/health returns `{"status":"ok"}`
  - Use DATABASE_URL environment variable
- [ ] `src/frontend/app.js` - Bug fixes for display/delete logic
  - Fix to handle response objects properly
  - Update delete to use ID parameter
- [ ] `src/backend/Dockerfile` - Backend container image
- [ ] `src/frontend/Dockerfile` - Frontend container image

### Infrastructure Files (REQUIRED)
- [ ] **`swarm/stack.yaml`** - Complete Swarm stack configuration (**REQUIRED** name/location)
  - Network: `appnet` with `driver: overlay`
  - Volume: `dbdata` bound to `/var/lib/postgres-data`
  - Service `db` with constraint: `node.labels.role == db`
  - Service `web` with ports: `["80:80"]`
  - Service `api` with DATABASE_URL pointing to `db` by name
- [ ] `Vagrantfile` - VM definitions for manager and worker
- [ ] `vagrant/install-docker.sh` - Docker installation script
- [ ] `src/build-images.sh` - Automated image build script
- [ ] `src/deploy.sh` - Automated deployment script

### Documentation
- [ ] `README.md` - Updated with Swarm deployment instructions
- [ ] `docs/OPERATIONS.md` - Operations and monitoring guide
- [ ] `docs/TROUBLESHOOTING.md` - Common issues and solutions
- [ ] `spec/10-current-state-spec.md` - Updated (✅ Done)
- [ ] `spec/20-target-spec.md` - Updated (✅ Done)
- [ ] `spec/30-plan.md` - This document (✅ Done)
- [ ] `spec/40-tasks.md` - Detailed task breakdown (To Do)

### Verification
- [ ] All acceptance tests pass
- [ ] Docker Compose still works for local dev
- [ ] Docker Swarm deployment fully functional
- [ ] Documentation complete and tested
- [ ] Git repository clean and organized

---

## Next Steps

1. **Review this plan** with team/instructor
2. **Set up development environment** (Vagrant, VirtualBox)
3. **Create Git branch** `swarm-orchestration`
4. **Start Phase 0** - Fix critical bugs
5. **Follow plan sequentially** through Phase 5
6. **Test thoroughly** at each milestone
7. **Document** any deviations or issues encountered

This implementation plan provides a complete roadmap for migrating the Names Manager application from Docker Compose to Docker Swarm with distributed deployment across Vagrant VMs.