# Names Manager - Docker Swarm Migration Traceability Matrix

## Overview

This document provides traceability from requirements through implementation for the Docker Swarm migration project. It ensures all specification requirements (topology, constraints, functionality) are addressed by planned tasks and can be verified through tests and deliverables.

## Project Context

**Migration Goal**: Refactor Names Manager from single-host Docker Compose to multi-host Docker Swarm
- **From**: Docker Compose (local development)
- **To**: Docker Swarm (production deployment)
- **Infrastructure**: 2 VMs (manager + worker) via Vagrant

## Traceability Legend

- **CONST**: Constitution requirement (original project constraints)
- **TARGET**: Target specification requirement (Swarm architecture)
- **PLAN**: Implementation plan milestone (6 phases)
- **TASK**: Specific task from task breakdown (37 tasks total)
- **TEST**: Test case or verification method
- **IMPL**: Implementation artifact (file/script/configuration)
- **OPS**: Operational script or automation

## Complete Traceability Matrix

### Topology & Placement Requirements

| Requirement | Target Spec | Plan Phase | Tasks | Verification | Implementation |
|------------|-------------|------------|-------|--------------|----------------|
| **TOPO-1**: Manager runs web+api | **TARGET-TOPO-1**: Services on manager | **PHASE-1**: Infrastructure<br/>**PHASE-2**: Stack Config | **TASK-1.5**: Init Swarm on manager<br/>**TASK-2.2**: Create stack.yaml | Verify service placement on manager node | `swarm/stack.yaml`<br/>`node.role == manager` constraints |
| **TOPO-2**: Worker runs db only | **TARGET-TOPO-2**: DB on worker | **PHASE-1**: Infrastructure<br/>**PHASE-2**: Stack Config | **TASK-1.7**: Label worker node<br/>**TASK-2.2**: Create stack.yaml | Verify DB service on worker node | Node label: `role=db`<br/>`node.labels.role == db` constraint |
| **TOPO-3**: Port 80:80 published | **TARGET-TOPO-3**: Web ingress | **PHASE-2**: Stack Config | **TASK-2.2**: Create stack.yaml | Access app on port 80 | `ports: ["80:80"]` on web service |
| **TOPO-4**: DB data on worker | **TARGET-TOPO-4**: Persistent storage | **PHASE-2**: Stack Config<br/>**PHASE-4**: Deploy | **TASK-2.2**: Create stack.yaml<br/>**TASK-4.1**: Create storage dir | Verify data in `/var/lib/postgres-data` | Volume bind: `/var/lib/postgres-data` |

### Network & Service Discovery Requirements

| Requirement | Target Spec | Plan Phase | Tasks | Verification | Implementation |
|------------|-------------|------------|-------|--------------|----------------|
| **NET-1**: Overlay network | **TARGET-NET-1**: appnet overlay | **PHASE-1**: Infrastructure | **TASK-1.8**: Create overlay network | Verify appnet exists with overlay driver | `docker network create --driver overlay appnet` |
| **NET-2**: Service discovery | **TARGET-NET-2**: DNS-based discovery | **PHASE-2**: Stack Config<br/>**PHASE-4**: Testing | **TASK-2.2**: DATABASE_URL config<br/>**TASK-4.4**: Test DNS discovery | API reaches DB by service name | `DATABASE_URL: ...@db:5432/...` |
| **NET-3**: All services on appnet | **TARGET-NET-3**: Network connectivity | **PHASE-2**: Stack Config | **TASK-2.2**: Create stack.yaml | All services connected | `networks: [appnet]` for all services |

### Health Check Requirements

| Requirement | Target Spec | Plan Phase | Tasks | Verification | Implementation |
|------------|-------------|------------|-------|--------------|----------------|
| **HEALTH-1**: DB pg_isready | **TARGET-HEALTH-1**: DB healthcheck | **PHASE-0**: Bug Fixes<br/>**PHASE-2**: Stack Config | **TASK-0.4**: Fix health endpoints<br/>**TASK-2.2**: Create stack.yaml | pg_isready returns success | `healthcheck: pg_isready -U names_user -d namesdb` |
| **HEALTH-2**: API /healthz | **TARGET-HEALTH-2**: API healthcheck | **PHASE-0**: Bug Fixes<br/>**PHASE-4**: Testing | **TASK-0.4**: Fix health format<br/>**TASK-4.5**: Test health endpoints | `/api/health` returns `{"status":"ok"}` | Updated `backend/main.py` |

### Bug Fix Requirements

| Bug ID | Current State | Plan Phase | Task | Verification | Implementation |
|--------|---------------|------------|------|--------------|----------------|
| **BUG-1**: GET format mismatch | Backend returns array, frontend expects object | **PHASE-0**: Bug Fixes | **TASK-0.1**: Fix backend response | GET returns `{names: [...]}` | Updated `backend/main.py` |
| **BUG-2**: Display logic error | Frontend treats objects as strings | **PHASE-0**: Bug Fixes | **TASK-0.2**: Fix frontend display | Names display correctly with timestamps | Updated `frontend/app.js` |
| **BUG-3**: DELETE uses name string | DELETE passes name instead of ID | **PHASE-0**: Bug Fixes | **TASK-0.3**: Fix DELETE to use ID | Delete by ID works | Updated `frontend/app.js` |
| **BUG-4**: Health format wrong | Returns `{"status":"healthy"}` not `"ok"` | **PHASE-0**: Bug Fixes | **TASK-0.4**: Fix health format | Returns `{"status":"ok"}` | Updated `backend/main.py` |
| **BUG-5**: DATABASE_URL support | Backend uses hardcoded connection | **PHASE-0**: Bug Fixes | **TASK-0.5**: Support DATABASE_URL | Reads from env var | Updated `backend/main.py` |

### Infrastructure Requirements

| Requirement | Target Spec | Plan Phase | Tasks | Verification | Implementation |
|------------|-------------|------------|-------|--------------|----------------|
| **INFRA-1**: 2 VMs (manager+worker) | **TARGET-INFRA-1**: Vagrant VMs | **PHASE-1**: Infrastructure | **TASK-1.2**: Create Vagrantfile<br/>**TASK-1.4**: Start VMs | VMs running and accessible | `Vagrantfile` |
| **INFRA-2**: Docker on VMs | **TARGET-INFRA-2**: Docker installed | **PHASE-1**: Infrastructure | **TASK-1.3**: Docker install script<br/>**TASK-1.4**: Verify VMs | Docker works on both VMs | `vagrant/install-docker.sh` |
| **INFRA-3**: Swarm cluster | **TARGET-INFRA-3**: Swarm initialized | **PHASE-1**: Infrastructure | **TASK-1.5**: Init Swarm<br/>**TASK-1.6**: Join worker | `docker node ls` shows 2 nodes | Swarm commands |
| **INFRA-4**: Node labeling | **TARGET-INFRA-4**: Worker labeled | **PHASE-1**: Infrastructure | **TASK-1.7**: Label worker node | Worker has `role=db` label | `docker node update --label-add role=db` |

### Operational Automation Requirements

| Requirement | Target Spec | Plan Phase | Task | Verification | Implementation |
|------------|-------------|------------|------|--------------|----------------|
| **OPS-1**: Cluster initialization | **TARGET-OPS-1**: init-swarm.sh | **PHASE-5**: Operations | **TASK-5.2**: Create init-swarm.sh | Script initializes cluster | `ops/init-swarm.sh` |
| **OPS-2**: Deployment automation | **TARGET-OPS-2**: deploy.sh | **PHASE-5**: Operations | **TASK-5.3**: Create deploy.sh | Script deploys stack | `ops/deploy.sh` |
| **OPS-3**: Verification script | **TARGET-OPS-3**: verify.sh | **PHASE-5**: Operations | **TASK-5.4**: Create verify.sh | Script verifies all requirements | `ops/verify.sh` |
| **OPS-4**: Cleanup automation | **TARGET-OPS-4**: cleanup.sh | **PHASE-5**: Operations | **TASK-5.5**: Create cleanup.sh | Script removes stack safely | `ops/cleanup.sh` |
| **OPS-5**: Dev workflow preserved | **TARGET-OPS-5**: compose.yaml | **PHASE-5**: Operations | **TASK-5.0**: Ensure compose.yaml | Local dev still works | `src/compose.yaml` or `docker-compose.yml` |

## Detailed Requirement Mappings

### Phase 0: Bug Fixes (Foundation)

#### Requirement Group: Application Functionality
```
BUG-1, BUG-2, BUG-3 (API/Frontend Integration)
├── TARGET: Functional application baseline
    └── PHASE-0: Bug Fixes
        ├── TASK-0.1: Fix Backend GET /api/names Response Format
        │   ├── TEST: Returns {names: [...]} format
        │   ├── IMPL: backend/main.py (GET endpoint)
        │   └── VERIFY: Frontend displays names correctly
        ├── TASK-0.2: Fix Frontend Display Logic
        │   ├── TEST: Displays name + timestamp separately
        │   ├── IMPL: frontend/app.js (displayNames function)
        │   └── VERIFY: UI shows formatted output
        └── TASK-0.3: Fix Frontend DELETE to Use ID
            ├── TEST: DELETE uses numeric ID not name string
            ├── IMPL: frontend/app.js (deleteName function)
            └── VERIFY: Delete functionality works

BUG-4, BUG-5 (Health & Configuration)
├── HEALTH-2: API healthcheck format
├── TARGET-NET-2: DATABASE_URL support
    └── PHASE-0: Bug Fixes
        ├── TASK-0.4: Fix Health Endpoint Format
        │   ├── TEST: /api/health returns {"status":"ok"}
        │   ├── IMPL: backend/main.py (health_check function)
        │   └── VERIFY: curl returns exact format
        ├── TASK-0.5: Update Backend to Use DATABASE_URL
        │   ├── TEST: Reads connection from env var
        │   ├── IMPL: backend/main.py (database init)
        │   └── VERIFY: Works with custom DATABASE_URL
        └── TASK-0.6: End-to-End Testing with Docker Compose
            ├── TEST: All CRUD operations work
            ├── VERIFY: docker-compose up works
            └── VERIFY: Application fully functional
```

### Phase 1: Infrastructure Setup

#### Requirement Group: VM & Swarm Infrastructure
```
INFRA-1, INFRA-2, INFRA-3, INFRA-4 (Infrastructure Foundation)
├── TARGET-INFRA-1: 2 VMs via Vagrant
├── TARGET-INFRA-2: Docker on both VMs
├── TARGET-INFRA-3: Swarm cluster initialized
├── TARGET-INFRA-4: Node labeling
    └── PHASE-1: Infrastructure Setup
        ├── TASK-1.1: Install Vagrant and VirtualBox
        │   ├── TEST: vagrant --version works
        │   └── VERIFY: VirtualBox installed
        ├── TASK-1.2: Create Vagrantfile
        │   ├── IMPL: Vagrantfile (2 VMs: manager, worker)
        │   ├── CONFIG: 192.168.56.10 (manager), .11 (worker)
        │   └── VERIFY: Syntax validation
        ├── TASK-1.3: Create Docker Installation Script
        │   ├── IMPL: vagrant/install-docker.sh
        │   └── VERIFY: Script installs Docker on Ubuntu
        ├── TASK-1.4: Start and Verify VMs
        │   ├── TEST: vagrant up succeeds
        │   ├── TEST: vagrant ssh manager works
        │   └── VERIFY: Docker runs on both VMs
        ├── TASK-1.5: Initialize Docker Swarm on Manager
        │   ├── TEST: docker swarm init succeeds
        │   ├── IMPL: Swarm on 192.168.56.10
        │   └── VERIFY: Manager node active
        ├── TASK-1.6: Join Worker to Swarm
        │   ├── TEST: docker swarm join succeeds
        │   └── VERIFY: docker node ls shows 2 nodes
        ├── TASK-1.7: Label Worker Node for Database
        │   ├── IMPL: docker node update --label-add role=db
        │   ├── TEST: Label applied successfully
        │   └── VERIFY: Inspection shows role=db
        └── TASK-1.8: Create Overlay Network
            ├── IMPL: docker network create --driver overlay appnet
            ├── TEST: Network created successfully
            └── VERIFY: docker network ls shows appnet

NET-1 (Overlay Network)
├── TARGET-NET-1: appnet overlay network
    └── PHASE-1: Infrastructure Setup
        └── TASK-1.8: Create Overlay Network
            ├── IMPL: Overlay network 'appnet'
            └── VERIFY: Cross-host connectivity
```

### Phase 2: Stack Configuration

#### Requirement Group: Swarm Stack Definition
```
TOPO-1, TOPO-2, TOPO-3, TOPO-4 (Service Topology)
├── NET-2, NET-3 (Service Discovery & Networking)
├── HEALTH-1 (DB Health Check)
    └── PHASE-2: Stack Configuration
        ├── TASK-2.1: Create swarm Directory
        │   ├── IMPL: swarm/ directory
        │   └── VERIFY: Directory structure
        ├── TASK-2.2: Create stack.yaml File
        │   ├── IMPL: swarm/stack.yaml (CRITICAL FILE)
        │   ├── CONFIG: db service
        │   │   ├── placement: node.labels.role == db
        │   │   ├── healthcheck: pg_isready
        │   │   └── volume: /var/lib/postgres-data
        │   ├── CONFIG: api service
        │   │   ├── placement: node.role == manager
        │   │   ├── replicas: 2
        │   │   └── DATABASE_URL: ...@db:5432/...
        │   ├── CONFIG: web service
        │   │   ├── placement: node.role == manager
        │   │   ├── ports: "80:80"
        │   │   └── replicas: 1
        │   ├── CONFIG: networks
        │   │   └── appnet: driver: overlay
        │   └── CONFIG: volumes
        │       └── dbdata: bind to /var/lib/postgres-data
        └── TASK-2.3: Validate Stack File
            ├── TEST: docker stack config validates
            └── VERIFY: No YAML syntax errors
```

### Phase 3: Image Building & Distribution

#### Requirement Group: Docker Images
```
Image Build & Transfer
└── PHASE-3: Image Building
    ├── TASK-3.1: Create Build Script
    │   ├── IMPL: src/build-images.sh
    │   └── VERIFY: Script builds both images
    ├── TASK-3.2: Build Images Locally
    │   ├── TEST: Backend image builds
    │   ├── TEST: Frontend image builds
    │   └── VERIFY: Images tagged correctly
    └── TASK-3.3: Transfer Images to Manager VM
        ├── TEST: Save and transfer images
        ├── TEST: Load images on manager
        └── VERIFY: Images available on manager
```

### Phase 4: Deployment & Testing

#### Requirement Group: Stack Deployment & Verification
```
TOPO-1, TOPO-2, TOPO-3, TOPO-4 (Full Deployment)
├── NET-2 (Service Discovery Testing)
├── HEALTH-1, HEALTH-2 (Health Check Testing)
    └── PHASE-4: Deployment & Testing
        ├── TASK-4.1: Create Database Storage Directory
        │   ├── IMPL: /var/lib/postgres-data on worker
        │   ├── TEST: Directory permissions (999:999)
        │   └── VERIFY: Directory exists and accessible
        ├── TASK-4.2: Deploy Stack to Swarm
        │   ├── TEST: docker stack deploy succeeds
        │   ├── VERIFY: All services running
        │   └── VERIFY: Correct replica counts
        ├── TASK-4.3: Verify Service Placement
        │   ├── TEST: DB on worker node
        │   ├── TEST: API on manager node
        │   ├── TEST: Web on manager node
        │   └── VERIFY: Placement constraints enforced
        ├── TASK-4.4: Test DNS Service Discovery
        │   ├── TEST: API can reach 'db' by DNS name
        │   ├── TEST: Ping db from API container
        │   └── VERIFY: DATABASE_URL connection works
        ├── TASK-4.5: Test Health Check Endpoints
        │   ├── TEST: GET /api/health → {"status":"ok"}
        │   ├── TEST: pg_isready check passes
        │   └── VERIFY: Both healthchecks working
        ├── TASK-4.6: Verify Database Storage Persistence
        │   ├── TEST: Add data, restart service
        │   ├── TEST: Data still exists after restart
        │   └── VERIFY: /var/lib/postgres-data persists
        └── TASK-4.7: End-to-End Application Testing
            ├── TEST: Add names via UI
            ├── TEST: View names with timestamps
            ├── TEST: Delete names
            └── VERIFY: Full CRUD functionality
```

### Phase 5: Operations & Hardening

#### Requirement Group: Operational Automation
```
OPS-1, OPS-2, OPS-3, OPS-4, OPS-5 (DevOps Automation)
└── PHASE-5: Operations & Hardening
    ├── TASK-5.0: Ensure compose.yaml for Local Development
    │   ├── IMPL: src/compose.yaml (or docker-compose.yml)
    │   ├── VERIFY: Local development works
    │   └── VERIFY: Parallel dev/prod workflows
    ├── TASK-5.1: Create ops Directory Structure
    │   ├── IMPL: ops/ directory
    │   └── VERIFY: Directory created
    ├── TASK-5.2: Create ops/init-swarm.sh
    │   ├── IMPL: ops/init-swarm.sh
    │   ├── SCRIPT: Swarm initialization
    │   ├── SCRIPT: Worker join
    │   ├── SCRIPT: Node labeling
    │   ├── SCRIPT: Network creation
    │   ├── SCRIPT: Storage setup
    │   └── VERIFY: Full cluster initialization
    ├── TASK-5.3: Create ops/deploy.sh
    │   ├── IMPL: ops/deploy.sh
    │   ├── SCRIPT: Build images
    │   ├── SCRIPT: Transfer images
    │   ├── SCRIPT: Deploy stack
    │   └── VERIFY: One-command deployment
    ├── TASK-5.4: Create ops/verify.sh
    │   ├── IMPL: ops/verify.sh
    │   ├── SCRIPT: Check service placement
    │   ├── SCRIPT: Test health endpoints
    │   ├── SCRIPT: Verify network & storage
    │   ├── SCRIPT: Comprehensive pass/fail report
    │   └── VERIFY: All requirements validated
    ├── TASK-5.5: Create ops/cleanup.sh
    │   ├── IMPL: ops/cleanup.sh
    │   ├── SCRIPT: Remove stack
    │   ├── SCRIPT: Preserve data option
    │   └── VERIFY: Safe cleanup process
    ├── TASK-5.6: Create Docker Secrets (Optional)
    │   ├── IMPL: Docker secrets for credentials
    │   └── VERIFY: No plaintext passwords
    ├── TASK-5.7: Update Project README
    │   ├── IMPL: Updated README.md
    │   ├── DOC: compose.yaml workflow
    │   ├── DOC: swarm/stack.yaml workflow
    │   ├── DOC: ops scripts usage
    │   └── VERIFY: Documentation complete
    ├── TASK-5.8: Create Operations Documentation (Optional)
    │   ├── IMPL: docs/OPERATIONS.md
    │   └── DOC: Detailed operational procedures
    └── TASK-5.9: Final End-to-End Validation
        ├── TEST: Clean deployment from scratch
        ├── TEST: All ops scripts work
        ├── VERIFY: All topology requirements met
        ├── VERIFY: All constraints enforced
        └── VERIFY: Complete functionality
```

## Implementation Tracking by Phase

### Phase 0: Bug Fixes

#### Task 0.1: Fix Backend GET Response Format
- **Requirements**: BUG-1, Frontend-Backend Integration
- **Expected Commits**: `fix: change GET /api/names to return {names: []} format`
- **Expected Files**: `src/backend/main.py` (modified)
- **Verification**: 
  - `curl http://localhost:8080/api/names` returns `{"names":[...]}`
  - Frontend displays names correctly
  
#### Task 0.4: Fix Health Endpoint Format
- **Requirements**: HEALTH-2, API healthcheck compliance
- **Expected Commits**: `fix: change /api/health to return {"status":"ok"}`
- **Expected Files**: `src/backend/main.py` (modified)
- **Verification**:
  - `curl http://localhost:8080/api/health` returns `{"status":"ok"}`
  - No extra fields in response

#### Task 0.5: Support DATABASE_URL
- **Requirements**: BUG-5, NET-2 (Service Discovery)
- **Expected Commits**: `feat: add DATABASE_URL environment variable support`
- **Expected Files**: `src/backend/main.py` (modified)
- **Verification**:
  - Backend reads from `DATABASE_URL` env var
  - Works with Swarm service names (e.g., `@db:5432`)

### Phase 1: Infrastructure Setup

#### Task 1.2: Create Vagrantfile
- **Requirements**: INFRA-1, 2 VMs for Swarm
- **Expected Commits**: `feat: add Vagrantfile for 2-node Swarm cluster`
- **Expected Files**: `Vagrantfile` (new)
- **Configuration**:
  - Manager VM: 192.168.56.10, 2GB RAM, 2 CPU
  - Worker VM: 192.168.56.11, 2GB RAM, 2 CPU
- **Verification**: `vagrant up` creates both VMs successfully

#### Task 1.7: Label Worker Node
- **Requirements**: INFRA-4, TOPO-2 (DB placement)
- **Expected Commands**: `docker node update --label-add role=db swarm-worker`
- **Verification**: `docker node inspect swarm-worker` shows `role: db` label

#### Task 1.8: Create Overlay Network
- **Requirements**: NET-1, Overlay network for services
- **Expected Commands**: `docker network create --driver overlay --attachable appnet`
- **Verification**: `docker network ls | grep appnet` shows overlay driver

### Phase 2: Stack Configuration

#### Task 2.2: Create stack.yaml File
- **Requirements**: ALL TOPOLOGY, NETWORK, HEALTH requirements
- **Expected Commits**: `feat: add swarm/stack.yaml for production deployment`
- **Expected Files**: `swarm/stack.yaml` (NEW - CRITICAL)
- **Configuration Requirements**:
  - DB service: `node.labels.role == db` constraint
  - API service: `node.role == manager`, `DATABASE_URL` with service name
  - Web service: `node.role == manager`, `ports: ["80:80"]`
  - Network: `appnet` with `driver: overlay`
  - Volume: bind to `/var/lib/postgres-data`
  - DB healthcheck: `pg_isready`
- **Verification**: `docker stack config -c swarm/stack.yaml` validates successfully

### Phase 3: Image Building

#### Task 3.1: Create Build Script
- **Requirements**: Image automation
- **Expected Commits**: `feat: add build-images.sh script`
- **Expected Files**: `src/build-images.sh` (new)
- **Verification**: Script builds both backend and frontend images

#### Task 3.3: Transfer Images to Manager
- **Requirements**: Image distribution to Swarm
- **Expected Commands**: Save, SCP, and load images on manager VM
- **Verification**: `vagrant ssh manager -- docker images` shows both images

### Phase 4: Deployment & Testing

#### Task 4.1: Create Storage Directory on Worker
- **Requirements**: TOPO-4, Persistent storage
- **Expected Commands**: Create `/var/lib/postgres-data` on worker with proper permissions
- **Verification**: 
  - Directory exists with 700 permissions
  - Owned by 999:999 (postgres user)

#### Task 4.2: Deploy Stack
- **Requirements**: ALL deployment requirements
- **Expected Commands**: `docker stack deploy -c /vagrant/swarm/stack.yaml names-app`
- **Verification**:
  - `docker stack services names-app` shows all services
  - `docker stack ps names-app` shows tasks running

#### Task 4.3: Verify Service Placement
- **Requirements**: TOPO-1, TOPO-2 validation
- **Verification**:
  - DB tasks on worker node only
  - API tasks on manager node only
  - Web tasks on manager node only

#### Task 4.4: Test DNS Service Discovery
- **Requirements**: NET-2, Service discovery
- **Verification**:
  - `docker exec <api-container> ping db` succeeds
  - API connects to database using service name

#### Task 4.6: Verify Storage Persistence
- **Requirements**: TOPO-4, Data persistence
- **Test Procedure**:
  1. Add data via API
  2. Remove DB service: `docker service rm names-app_db`
  3. Redeploy: `docker stack deploy -c stack.yaml names-app`
  4. Verify data still exists
- **Verification**: Data persists across container replacements

### Phase 5: Operations

#### Task 5.0: Ensure compose.yaml for Development
- **Requirements**: OPS-5, Parallel workflows
- **Expected Files**: `src/compose.yaml` or `src/docker-compose.yml`
- **Verification**:
  - Local development with `docker-compose up` works
  - Contains all bug fixes from Phase 0

#### Task 5.2: Create ops/init-swarm.sh
- **Requirements**: OPS-1, Cluster initialization automation
- **Expected Commits**: `feat: add ops/init-swarm.sh cluster initialization script`
- **Expected Files**: `ops/init-swarm.sh` (new, executable)
- **Script Functions**:
  - Check VMs running
  - Initialize Swarm on manager
  - Join worker to Swarm
  - Label worker with role=db
  - Create overlay network
  - Create storage directory
- **Verification**: Running script from scratch initializes complete cluster

#### Task 5.3: Create ops/deploy.sh
- **Requirements**: OPS-2, Deployment automation
- **Expected Commits**: `feat: add ops/deploy.sh deployment automation script`
- **Expected Files**: `ops/deploy.sh` (new, executable)
- **Script Functions**:
  - Build images locally
  - Save and compress images
  - Transfer to manager VM
  - Load images on manager
  - Deploy stack
  - Show deployment status
- **Verification**: Single command deploys entire application

#### Task 5.4: Create ops/verify.sh
- **Requirements**: OPS-3, Automated verification
- **Expected Commits**: `feat: add ops/verify.sh verification script`
- **Expected Files**: `ops/verify.sh` (new, executable)
- **Script Functions**:
  - Check stack deployment
  - Verify service placement (TOPO-1, TOPO-2)
  - Test health endpoints (HEALTH-1, HEALTH-2)
  - Verify overlay network (NET-1)
  - Verify persistent storage (TOPO-4)
  - Verify node labels (INFRA-4)
  - Provide pass/fail summary
- **Verification**: Script validates all topology and constraint requirements

#### Task 5.7: Update README
- **Requirements**: OPS-5, Documentation
- **Expected Commits**: `docs: update README with Swarm deployment instructions`
- **Expected Files**: `README.md` (modified)
- **Documentation Sections**:
  - Architecture (dev vs prod)
  - Prerequisites
  - Local development with compose.yaml
  - Production deployment with ops scripts
  - Troubleshooting
- **Verification**: New user can follow instructions successfully

### Task 1.3: Create Basic API Endpoint Tests
- **Specification Sources**: CONST-T2, TARGET-T2
- **Plan Reference**: PLAN-1.1
- **Expected Commits**:
  - [ ] `test: add API endpoint test cases`
- **Expected Files**:
  - [ ] `backend/tests/test_main.py`
- **Test Verification**: All API endpoints have success and failure test cases
- **Coverage Target**: Core API functionality covered

### Task 1.4: Add Basic Logging to Backend
- **Specification Sources**: CONST-Q1, TARGET-Q1
- **Plan Reference**: PLAN-1.2
- **Expected Commits**:
  - [ ] `feat: add basic logging to API endpoints`
- **Expected Files**:
  - [ ] Updated `backend/main.py`
- **Test Verification**: Log messages appear when running application
- **Manual Test**: Check logs for request/response information

### Task 1.5: Extract Configuration to Environment Variables
- **Specification Sources**: CONST-Q2, CONST-S2, TARGET-Q2
- **Plan Reference**: PLAN-1.2
- **Expected Commits**:
  - [ ] `refactor: extract configuration to environment variables`
  - [ ] `feat: add environment variable documentation`
- **Expected Files**:
  - [ ] Updated `backend/main.py`
  - [ ] Updated `docker-compose.yml`
  - [ ] `.env.example`
- **Test Verification**: Application works with custom environment variables
- **Security Check**: No hardcoded credentials in source code

### Task 1.6: Improve Frontend Error Handling
- **Specification Sources**: CONST-Q3, TARGET-Q3
- **Plan Reference**: PLAN-1.2
- **Expected Commits**:
  - [ ] `feat: improve frontend error handling and user feedback`
- **Expected Files**:
  - [ ] Updated `frontend/app.js`
  - [ ] Updated `frontend/index.html` (if needed)
- **Test Verification**: Error messages are user-friendly and clear
- **Manual Test**: Try invalid inputs and verify error display

### Task 2.1: Add Health Check Endpoints
- **Specification Sources**: CONST-M1, TARGET-M1
- **Plan Reference**: PLAN-2.1
- **Expected Commits**:
  - [ ] `feat: add health check endpoints`
- **Expected Files**:
  - [ ] Updated `backend/main.py`
- **Test Verification**: 
  - [ ] `curl http://localhost:8080/health` returns 200
  - [ ] `curl http://localhost:8080/health/db` returns 200 with DB connected
- **Documentation**: Health endpoints documented in README

### Task 2.2: Add Basic Input Sanitization
- **Specification Sources**: CONST-S1, TARGET-S1
- **Plan Reference**: PLAN-2.1
- **Expected Commits**:
  - [ ] `security: add basic input sanitization`
- **Expected Files**:
  - [ ] Updated `backend/main.py`
- **Test Verification**: XSS attempts are safely handled
- **Security Test**: Try submitting `<script>alert('xss')</script>` as name

### Task 2.3: Create Manual Testing Checklist
- **Specification Sources**: CONST-T4, TARGET-T4
- **Plan Reference**: PLAN-2.1
- **Expected Commits**:
  - [ ] `docs: add manual testing checklist`
- **Expected Files**:
  - [ ] `TESTING.md`
- **Test Verification**: Manual test checklist can be followed successfully
- **Review**: Another person can follow the checklist

### Task 2.4: Update Documentation
- **Specification Sources**: CONST-Q4, TARGET-Q4
- **Plan Reference**: PLAN-2.1
- **Expected Commits**:
  - [ ] `docs: update README with improved setup instructions`
  - [ ] `docs: document new features and environment variables`
- **Expected Files**:
  - [ ] Updated `README.md`
  - [ ] Updated `src/README.md`
- **Test Verification**: New developer can set up project from README
- **Review**: Documentation is clear and complete

## Verification Matrix

### Topology Verification
| Topology Requirement | Verification Method | Success Criteria | Task Reference |
|---------------------|-------------------|------------------|----------------|
| **TOPO-1**: Manager runs web+api | `docker service ps names-app_api names-app_web` | All tasks on manager node | Task 4.3, 5.4 |
| **TOPO-2**: Worker runs db only | `docker service ps names-app_db` | All tasks on worker node | Task 4.3, 5.4 |
| **TOPO-3**: Port 80:80 published | `curl http://localhost:80` | Web accessible on port 80 | Task 4.7, 5.4 |
| **TOPO-4**: DB data on worker | Check `/var/lib/postgres-data` on worker | Data directory exists with data | Task 4.6, 5.4 |

### Network Verification
| Network Requirement | Verification Method | Success Criteria | Task Reference |
|--------------------|-------------------|------------------|----------------|
| **NET-1**: Overlay network exists | `docker network ls \| grep appnet` | appnet with overlay driver | Task 1.8, 5.4 |
| **NET-2**: DNS service discovery | `docker exec <api> ping db` | API reaches DB by name | Task 4.4, 5.4 |
| **NET-3**: All services connected | Inspect each service network | All on appnet network | Task 2.2 |

### Health Check Verification
| Health Requirement | Verification Method | Success Criteria | Task Reference |
|-------------------|-------------------|------------------|----------------|
| **HEALTH-1**: DB pg_isready | `docker exec <db> pg_isready` | Returns success | Task 2.2, 4.5 |
| **HEALTH-2**: API /healthz | `curl http://localhost:80/api/health` | Returns `{"status":"ok"}` | Task 0.4, 4.5, 5.4 |

### Infrastructure Verification
| Infrastructure Req | Verification Method | Success Criteria | Task Reference |
|-------------------|-------------------|------------------|----------------|
| **INFRA-1**: 2 VMs running | `vagrant status` | Both VMs running | Task 1.4 |
| **INFRA-2**: Docker on VMs | `vagrant ssh <vm> -- docker version` | Docker works on both | Task 1.4 |
| **INFRA-3**: Swarm cluster | `docker node ls` | 2 nodes (manager + worker) | Task 1.5, 1.6 |
| **INFRA-4**: Node labeled | `docker node inspect swarm-worker` | Has `role=db` label | Task 1.7, 5.4 |

### Operational Automation Verification
| Ops Requirement | Verification Method | Success Criteria | Task Reference |
|----------------|-------------------|------------------|----------------|
| **OPS-1**: init-swarm.sh | Run script from scratch | Initializes complete cluster | Task 5.2 |
| **OPS-2**: deploy.sh | Run script | Deploys full application | Task 5.3 |
| **OPS-3**: verify.sh | Run script | All checks pass | Task 5.4 |
| **OPS-4**: cleanup.sh | Run script | Safely removes stack | Task 5.5 |
| **OPS-5**: compose.yaml | `docker-compose up` in src/ | Local dev works | Task 5.0 |

### Bug Fix Verification
| Bug | Verification Method | Success Criteria | Task Reference |
|-----|-------------------|------------------|----------------|
| **BUG-1**: GET format | `curl http://localhost/api/names` | Returns `{"names":[...]}` | Task 0.1 |
| **BUG-2**: Display logic | Check UI | Names display with timestamps | Task 0.2 |
| **BUG-3**: DELETE by ID | Delete a name via UI | Uses ID parameter | Task 0.3 |
| **BUG-4**: Health format | `curl http://localhost/api/health` | Returns `{"status":"ok"}` | Task 0.4 |
| **BUG-5**: DATABASE_URL | Check backend code | Reads from env var | Task 0.5 |

## Compliance Dashboard

### Phase 0: Bug Fixes Completion
- [ ] **BUG-1**: GET format fixed (Task 0.1) - Returns `{names: [...]}`
- [ ] **BUG-2**: Display logic fixed (Task 0.2) - UI shows timestamps
- [ ] **BUG-3**: DELETE uses ID (Task 0.3) - Sends numeric ID
- [ ] **BUG-4**: Health format fixed (Task 0.4) - Returns `{"status":"ok"}`
- [ ] **BUG-5**: DATABASE_URL support (Task 0.5) - Reads from env var
- [ ] **E2E Testing**: Task 0.6 passed - Application fully functional

### Phase 1: Infrastructure Setup Completion
- [ ] **VMs**: Tasks 1.1-1.4 completed - 2 VMs running with Docker
- [ ] **Swarm Cluster**: Tasks 1.5-1.6 completed - Cluster initialized
- [ ] **Node Labeling**: Task 1.7 completed - Worker labeled `role=db`
- [ ] **Overlay Network**: Task 1.8 completed - appnet created
- [ ] **Verification**: `docker node ls` shows 2 nodes, network exists

### Phase 2: Stack Configuration Completion
- [ ] **swarm/stack.yaml**: Task 2.2 completed - File created with all configs
- [ ] **DB Placement**: `node.labels.role == db` constraint defined
- [ ] **Web/API Placement**: `node.role == manager` constraints defined
- [ ] **Port Publishing**: `80:80` configured on web service
- [ ] **Overlay Network**: appnet configured for all services
- [ ] **Volume Binding**: `/var/lib/postgres-data` configured
- [ ] **Health Checks**: pg_isready and API health configured
- [ ] **Validation**: Task 2.3 passed - Stack file validates

### Phase 3: Image Building Completion
- [ ] **Build Script**: Task 3.1 completed - build-images.sh created
- [ ] **Images Built**: Task 3.2 completed - Both images built locally
- [ ] **Images Transferred**: Task 3.3 completed - Images on manager VM

### Phase 4: Deployment & Testing Completion
- [ ] **Storage Setup**: Task 4.1 completed - Directory on worker created
- [ ] **Stack Deployed**: Task 4.2 completed - All services running
- [ ] **Placement Verified**: Task 4.3 passed - Services on correct nodes
- [ ] **DNS Working**: Task 4.4 passed - API reaches DB by name
- [ ] **Health Checks**: Task 4.5 passed - Both healthchecks working
- [ ] **Persistence Verified**: Task 4.6 passed - Data survives restarts
- [ ] **E2E Testing**: Task 4.7 passed - Full CRUD works

### Phase 5: Operations & Hardening Completion
- [ ] **compose.yaml**: Task 5.0 verified - Local dev workflow preserved
- [ ] **ops/ Directory**: Task 5.1 completed - Directory structure created
- [ ] **init-swarm.sh**: Task 5.2 completed - Cluster init automation
- [ ] **deploy.sh**: Task 5.3 completed - Deployment automation
- [ ] **verify.sh**: Task 5.4 completed - Verification automation
- [ ] **cleanup.sh**: Task 5.5 completed - Cleanup automation
- [ ] **README Updated**: Task 5.7 completed - Documentation complete
- [ ] **Final Validation**: Task 5.9 passed - All requirements met

### Final Acceptance Checklist

#### Topology & Constraints ✅
- [ ] **TOPO-1**: Manager runs web + api services (verified)
- [ ] **TOPO-2**: Worker runs db service only (verified)
- [ ] **TOPO-3**: Web publishes port 80:80 (verified)
- [ ] **TOPO-4**: DB data at `/var/lib/postgres-data` on worker (verified)

#### Network & Service Discovery ✅
- [ ] **NET-1**: Overlay network `appnet` exists (verified)
- [ ] **NET-2**: DNS service discovery works (API→db) (verified)
- [ ] **NET-3**: All services on appnet network (verified)

#### Health Checks ✅
- [ ] **HEALTH-1**: DB uses pg_isready healthcheck (verified)
- [ ] **HEALTH-2**: API `/api/health` returns `{"status":"ok"}` (verified)

#### Infrastructure ✅
- [ ] **INFRA-1**: 2 VMs (manager + worker) running (verified)
- [ ] **INFRA-2**: Docker installed on both VMs (verified)
- [ ] **INFRA-3**: Swarm cluster initialized (verified)
- [ ] **INFRA-4**: Worker node labeled with `role=db` (verified)

#### Operations ✅
- [ ] **OPS-1**: ops/init-swarm.sh works (verified)
- [ ] **OPS-2**: ops/deploy.sh works (verified)
- [ ] **OPS-3**: ops/verify.sh validates all requirements (verified)
- [ ] **OPS-4**: ops/cleanup.sh safely removes stack (verified)
- [ ] **OPS-5**: compose.yaml for local development works (verified)

#### Bug Fixes ✅
- [ ] **BUG-1**: GET response format fixed (verified)
- [ ] **BUG-2**: Frontend display logic fixed (verified)
- [ ] **BUG-3**: DELETE uses ID parameter (verified)
- [ ] **BUG-4**: Health endpoint format fixed (verified)
- [ ] **BUG-5**: DATABASE_URL environment variable supported (verified)

### Documentation Completeness
- [ ] **README.md**: Updated with both dev and prod workflows
- [ ] **swarm/stack.yaml**: Complete with all requirements
- [ ] **ops/ scripts**: All 4 scripts created and documented
- [ ] **Current State Spec**: Documents bugs and current state
- [ ] **Target State Spec**: Documents Swarm architecture
- [ ] **Plan**: 6 phases with milestones
- [ ] **Tasks**: 37 tasks with acceptance criteria
- [ ] **Traceability**: This document complete

## Summary

This traceability matrix ensures complete coverage from requirements through implementation for the Docker Swarm migration:

- **37 tasks** across **6 phases** (Phase 0-5)
- **All topology constraints** traced and verified
- **All network requirements** implemented and tested
- **All health checks** configured and validated
- **Complete operational automation** via ops/ scripts
- **Parallel dev/prod workflows** maintained
- **Comprehensive verification** at each phase

Every requirement from the target specification is implemented through specific tasks, with clear verification methods and success criteria.