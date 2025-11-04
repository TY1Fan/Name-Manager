# Names Manager - k3s Migration Traceability Matrix

## Overview

This document provides traceability from requirements through implementation for the k3s migration project. It ensures all specification requirements (topology, constraints, functionality) are addressed by planned tasks and can be verified through tests and deliverables.

## Project Context

**Migration Goal**: Refactor Names Manager from single-host Docker Compose to k3s (Lightweight Kubernetes)
- **From**: Docker Compose (local development)
- **To**: k3s (Kubernetes production deployment)
- **Infrastructure**: 1-2 VMs (k3s-server + optional k3s-agent) via Vagrant

## Traceability Legend

- **CONST**: Constitution requirement (original project constraints)
- **TARGET**: Target specification requirement (k3s/Kubernetes architecture)
- **PLAN**: Implementation plan milestone (6 phases)
- **TASK**: Specific task from task breakdown (30+ tasks total)
- **TEST**: Test case or verification method
- **IMPL**: Implementation artifact (file/script/configuration/manifest)
- **OPS**: Operational script or automation

## Complete Traceability Matrix

### Topology & Placement Requirements

| Requirement | Target Spec | Plan Phase | Tasks | Verification | Implementation |
|------------|-------------|------------|-------|--------------|----------------|
| **TOPO-1**: Server runs web+api | **TARGET-TOPO-1**: Pods on k3s-server | **PHASE-1**: Infrastructure<br/>**PHASE-2**: Manifests | **TASK-1.2**: Install k3s<br/>**TASK-2.2**: Create k8s manifests | Verify pod placement on server node | `k8s/*.yaml`<br/>nodeSelector or tolerations |
| **TOPO-2**: DB persistence | **TARGET-TOPO-2**: Persistent storage | **PHASE-2**: Manifests<br/>**PHASE-4**: Deployment | **TASK-2.4**: Create PVC manifest<br/>**TASK-2.7**: Create DB StatefulSet | Data persists across pod restarts | `k8s/pvc.yaml`<br/>`volumeClaimTemplates` in StatefulSet |
| **TOPO-3**: Web publishes NodePort | **TARGET-TOPO-3**: External access | **PHASE-2**: Manifests | **TASK-2.10**: Create Web Service | NodePort accessible externally | `k8s/web-service.yaml`<br/>`type: NodePort` |
| **TOPO-4**: Resource limits | **TARGET-TOPO-4**: Resource management | **PHASE-5**: Hardening | **TASK-5.1**: Add resource limits | Pods have CPU/memory limits | `resources: limits/requests` in manifests |

### Network & Service Discovery Requirements

| Requirement | Target Spec | Plan Phase | Tasks | Verification | Implementation |
|------------|-------------|------------|-------|--------------|----------------|
| **NET-1**: Cluster networking | **TARGET-NET-1**: K8s CNI | **PHASE-1**: Infrastructure | **TASK-1.2**: Install k3s | Verify pod networking works | k3s built-in CNI (flannel) |
| **NET-2**: Service discovery | **TARGET-NET-2**: DNS-based discovery | **PHASE-2**: Manifests<br/>**PHASE-4**: Testing | **TASK-2.3**: Create ConfigMap<br/>**TASK-4.4**: Test connectivity | API reaches DB by service name | `DATABASE_URL: ...@db:5432/...`<br/>CoreDNS service discovery |
| **NET-3**: Services expose pods | **TARGET-NET-3**: Service connectivity | **PHASE-2**: Manifests | **TASK-2.8-2.10**: Create Services | All pods reachable via Services | ClusterIP services for DB/API, NodePort for Web |
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
| **HEALTH-1**: DB readiness probe | **TARGET-HEALTH-1**: DB liveness/readiness | **PHASE-0**: Bug Fixes<br/>**PHASE-2**: Manifests | **TASK-0.4**: Fix health endpoints<br/>**TASK-2.7**: Create DB StatefulSet | pg_isready probe succeeds | `livenessProbe/readinessProbe` with pg_isready |
| **HEALTH-2**: API health endpoint | **TARGET-HEALTH-2**: API liveness/readiness | **PHASE-0**: Bug Fixes<br/>**PHASE-4**: Testing | **TASK-0.4**: Fix health format<br/>**TASK-4.3**: Test health probes | `/api/health` returns `{"status":"ok"}` | `livenessProbe/readinessProbe` HTTP checks |

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
| **INFRA-1**: k3s VM(s) | **TARGET-INFRA-1**: Vagrant VMs | **PHASE-1**: Infrastructure | **TASK-1.1**: Update Vagrantfile<br/>**TASK-1.3**: Start VMs | VM(s) running and accessible | `Vagrantfile` (k3s-server, optional k3s-agent) |
| **INFRA-2**: k3s installed | **TARGET-INFRA-2**: k3s cluster | **PHASE-1**: Infrastructure | **TASK-1.2**: Install k3s<br/>**TASK-1.4**: Configure kubectl | k3s cluster operational | k3s installation script in Vagrantfile |
| **INFRA-3**: kubectl access | **TARGET-INFRA-3**: Cluster management | **PHASE-1**: Infrastructure | **TASK-1.4**: Copy kubeconfig<br/>**TASK-1.5**: Test kubectl | `kubectl get nodes` works | kubeconfig at ~/.kube/config |
| **INFRA-4**: Namespace | **TARGET-INFRA-4**: Resource isolation | **PHASE-2**: Manifests | **TASK-2.1**: Create namespace | names-app namespace exists | `k8s/namespace.yaml` |

### Operational Automation Requirements

| Requirement | Target Spec | Plan Phase | Task | Verification | Implementation |
|------------|-------------|------------|------|--------------|----------------|
| **OPS-1**: Cluster initialization | **TARGET-OPS-1**: init-k3s.sh | **PHASE-5**: Operations | **TASK-5.4**: Create init script | Script initializes k3s cluster | `ops/init-k3s.sh` |
| **OPS-2**: Deployment automation | **TARGET-OPS-2**: deploy.sh | **PHASE-5**: Operations | **TASK-5.5**: Create deploy.sh | Script deploys to k3s | `ops/deploy.sh` (kubectl apply) |
| **OPS-3**: Verification script | **TARGET-OPS-3**: verify.sh | **PHASE-5**: Operations | **TASK-5.6**: Create verify.sh | Script verifies all requirements | `ops/verify.sh` |
| **OPS-4**: Cleanup automation | **TARGET-OPS-4**: cleanup.sh | **PHASE-5**: Operations | **TASK-5.7**: Create cleanup.sh | Script removes resources safely | `ops/cleanup.sh` |
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

#### Requirement Group: VM & k3s Infrastructure
```
INFRA-1, INFRA-2, INFRA-3, INFRA-4 (Infrastructure Foundation)
├── TARGET-INFRA-1: VM(s) via Vagrant
├── TARGET-INFRA-2: k3s cluster
├── TARGET-INFRA-3: kubectl access
├── TARGET-INFRA-4: Namespace setup
    └── PHASE-1: Infrastructure Setup
        ├── TASK-1.1: Update Vagrantfile for k3s
        │   ├── IMPL: Vagrantfile (k3s-server VM)
        │   ├── CONFIG: 192.168.56.10 (k3s-server), optional .11 (k3s-agent)
        │   └── VERIFY: Syntax validation
        ├── TASK-1.2: Install k3s
        │   ├── IMPL: k3s installation in Vagrantfile
        │   └── VERIFY: k3s cluster operational
        ├── TASK-1.3: Start and Verify VM(s)
        │   ├── TEST: vagrant up succeeds
        │   ├── TEST: vagrant ssh k3s-server works
        │   └── VERIFY: k3s running on VM(s)
        ├── TASK-1.4: Configure kubectl Access
        │   ├── TEST: Copy kubeconfig from VM
        │   ├── IMPL: Copy /etc/rancher/k3s/k3s.yaml to ~/.kube/config
        │   └── VERIFY: kubectl access works
        └── TASK-1.5: Test Cluster Connectivity
            ├── TEST: kubectl get nodes shows Ready
            ├── TEST: kubectl cluster-info works
            └── VERIFY: k3s cluster fully operational

NET-1 (Kubernetes Networking)
├── TARGET-NET-1: k3s CNI networking
    └── PHASE-1: Infrastructure Setup
        └── TASK-1.2: Install k3s
            ├── IMPL: k3s with built-in CNI (flannel)
            └── VERIFY: Pod-to-pod connectivity
```

### Phase 2: Kubernetes Manifests Creation

#### Requirement Group: Kubernetes Resources Definition
```
TOPO-1, TOPO-2, TOPO-3, TOPO-4 (Resource Topology)
├── NET-2, NET-3 (Service Discovery & Networking)
├── HEALTH-1, HEALTH-2 (Pod Health Probes)
    └── PHASE-2: Kubernetes Manifests
        ├── TASK-2.1: Create k8s Directory & Namespace
        │   ├── IMPL: k8s/namespace.yaml
        │   └── VERIFY: Namespace definition valid
        ├── TASK-2.2: Create ConfigMap Manifest
        │   ├── IMPL: k8s/configmap.yaml
        │   ├── CONFIG: POSTGRES_USER, POSTGRES_DB
        │   └── VERIFY: ConfigMap valid
        ├── TASK-2.3: Create Secret Manifest
        │   ├── IMPL: k8s/secret.yaml
        │   ├── CONFIG: POSTGRES_PASSWORD, DATABASE_URL (base64)
        │   └── VERIFY: Secret properly encoded
        ├── TASK-2.4: Create PVC Manifest
        │   ├── IMPL: k8s/pvc.yaml
        │   ├── CONFIG: 1Gi storage, ReadWriteOnce
        │   └── VERIFY: PVC definition valid
        ├── TASK-2.5-2.6: Create DB StatefulSet & Service
        │   ├── IMPL: k8s/db-statefulset.yaml, k8s/db-service.yaml
        │   ├── CONFIG: postgres:15, pg_isready probes, volumeClaimTemplates
        │   └── VERIFY: DB resources valid
        ├── TASK-2.7-2.8: Create API Deployment & Service
        │   ├── IMPL: k8s/api-deployment.yaml, k8s/api-service.yaml
        │   ├── CONFIG: replicas: 2, /api/health probes, ClusterIP
        │   └── VERIFY: API resources valid
        └── TASK-2.9-2.10: Create Web Deployment & Service
            ├── IMPL: k8s/web-deployment.yaml, k8s/web-service.yaml
            ├── CONFIG: NodePort, port 80
            └── VERIFY: Web resources valid
```

### Phase 3: Container Image Management

#### Requirement Group: Container Images for k3s
```
Image Build, Save, Transfer & Import
└── PHASE-3: Container Image Management
    ├── TASK-3.1: Build Images Locally
    │   ├── TEST: Backend image builds
    │   ├── TEST: Frontend image builds
    │   └── VERIFY: Images tagged correctly
    ├── TASK-3.2: Save & Transfer Images
    │   ├── TEST: docker save images to tar
    │   ├── TEST: Transfer to k3s-server VM
    │   └── VERIFY: Tar files on VM
    └── TASK-3.3: Import Images to containerd
        ├── TEST: k3s ctr images import succeeds
        ├── TEST: crictl images shows images
        └── VERIFY: Images available in k3s
```

### Phase 4: k3s Deployment & Testing

#### Requirement Group: Kubernetes Deployment & Verification
```
TOPO-1, TOPO-2, TOPO-3, TOPO-4 (Full Deployment)
├── NET-2 (Service Discovery Testing)
├── HEALTH-1, HEALTH-2 (Probe Testing)
    └── PHASE-4: k3s Deployment & Testing
        ├── TASK-4.1: Apply Namespace
        │   ├── TEST: kubectl apply namespace.yaml
        │   └── VERIFY: Namespace created
        ├── TASK-4.2: Apply ConfigMap & Secret
        │   ├── TEST: kubectl apply configmap & secret
        │   └── VERIFY: Resources created
        ├── TASK-4.3: Deploy Database
        │   ├── TEST: kubectl apply PVC & StatefulSet
        │   ├── TEST: kubectl apply db-service
        │   └── VERIFY: DB pod Running, PVC Bound
        ├── TASK-4.4: Deploy API
        │   ├── TEST: kubectl apply api-deployment & service
        │   └── VERIFY: API pods Running
        ├── TASK-4.5: Deploy Web
        │   ├── TEST: kubectl apply web-deployment & service
        │   └── VERIFY: Web pod Running
        ├── TASK-4.6: Test Pod Health Probes
        │   ├── TEST: DB readiness probe succeeds (pg_isready)
        │   ├── TEST: API readiness probe succeeds (/api/health)
        │   └── VERIFY: All pods Ready
        ├── TASK-4.7: Test Service Discovery
        │   ├── TEST: API can reach db.names-app.svc.cluster.local
        │   ├── TEST: kubectl exec API pod - ping db
        │   └── VERIFY: DATABASE_URL connection works
        ├── TASK-4.8: Verify PVC Persistence
        │   ├── TEST: Add data, delete DB pod
        │   ├── TEST: Data persists after pod recreation
        │   └── VERIFY: PVC survives pod restarts
        └── TASK-4.9: End-to-End Application Testing
            ├── TEST: Access via NodePort
            ├── TEST: Add names via UI
            ├── TEST: View names with timestamps
            ├── TEST: Delete names
            └── VERIFY: Full CRUD functionality
```

### Phase 5: Production Hardening & Operations

#### Requirement Group: Operational Automation & Hardening
```
OPS-1, OPS-2, OPS-3, OPS-4, OPS-5 (DevOps Automation)
└── PHASE-5: Production Hardening & Operations
    ├── TASK-5.0: Ensure compose.yaml for Local Development
    │   ├── IMPL: src/compose.yaml (or docker-compose.yml)
    │   ├── VERIFY: Local development works
    │   └── VERIFY: Parallel dev/prod workflows
    ├── TASK-5.1: Add Resource Limits/Requests
    │   ├── IMPL: Update k8s manifests with resources
    │   ├── CONFIG: CPU/memory limits and requests
    │   └── VERIFY: Pods have resource constraints
    ├── TASK-5.2: Configure HPA (Optional)
    │   ├── IMPL: k8s/api-hpa.yaml
    │   ├── CONFIG: CPU-based autoscaling for API
    │   └── VERIFY: HPA monitors API deployment
    ├── TASK-5.3: Create Operations Guide
    │   ├── IMPL: k8s/README.md or ops/K3S_OPS.md
    │   ├── DOCUMENT: Deployment procedures
    │   ├── DOCUMENT: Troubleshooting steps
    │   └── VERIFY: Guide complete
    ├── TASK-5.4: Create ops/init-k3s.sh
    │   ├── IMPL: ops/init-k3s.sh
    │   ├── SCRIPT: k3s cluster initialization
    │   ├── SCRIPT: kubectl configuration
    │   └── VERIFY: Full cluster initialization
    ├── TASK-5.5: Create ops/deploy.sh
    │   ├── IMPL: ops/deploy.sh
    │   ├── SCRIPT: Build & transfer images
    │   ├── SCRIPT: Import to containerd
    │   ├── SCRIPT: kubectl apply all manifests
    │   └── VERIFY: One-command deployment
    ├── TASK-5.6: Create ops/verify.sh
    │   ├── IMPL: ops/verify.sh
    │   ├── SCRIPT: Check pod status
    │   ├── SCRIPT: Test health probes
    │   ├── SCRIPT: Verify services & persistence
    │   ├── SCRIPT: Comprehensive pass/fail report
    │   └── VERIFY: All requirements validated
    ├── TASK-5.7: Create ops/cleanup.sh
    │   ├── IMPL: ops/cleanup.sh
    │   ├── SCRIPT: kubectl delete resources
    │   ├── SCRIPT: Preserve PVC option
    │   └── VERIFY: Safe cleanup process
    │   ├── IMPL: Updated README.md
    │   ├── DOC: compose.yaml workflow (local dev)
    │   ├── DOC: k3s deployment workflow
    │   ├── DOC: ops scripts usage
    │   └── VERIFY: Documentation complete
    └── TASK-5.9: Final End-to-End Validation
        ├── TEST: Clean deployment from scratch
        ├── TEST: All ops scripts work
        ├── VERIFY: All topology requirements met
        ├── VERIFY: All resource constraints applied
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

#### Task 1.4: Configure kubectl Access
- **Requirements**: INFRA-3, Cluster management
- **Expected Commands**: Copy `/etc/rancher/k3s/k3s.yaml` to `~/.kube/config`, update server IP
- **Verification**: `kubectl get nodes` shows k3s nodes as Ready

#### Task 1.5: Test Cluster Connectivity
- **Requirements**: INFRA-3, Verify k3s operational
- **Expected Commands**: `kubectl cluster-info`, `kubectl get pods -A`
- **Verification**: All system pods Running, cluster accessible

### Phase 2: Kubernetes Manifests

#### Task 2.1-2.10: Create All Kubernetes Manifests
- **Requirements**: ALL TOPOLOGY, NETWORK, HEALTH requirements
- **Expected Commits**: `feat: add k8s manifests for k3s deployment`
- **Expected Files**: `k8s/` directory with all manifests
  - `k8s/namespace.yaml` - names-app namespace
  - `k8s/configmap.yaml` - DB config (non-sensitive)
  - `k8s/secret.yaml` - DB credentials (base64 encoded)
  - `k8s/pvc.yaml` - 1Gi persistent volume claim
  - `k8s/db-statefulset.yaml` - DB with pg_isready probes
  - `k8s/db-service.yaml` - ClusterIP service on port 5432
  - `k8s/api-deployment.yaml` - API with 2 replicas, /api/health probes
  - `k8s/api-service.yaml` - ClusterIP service
  - `k8s/web-deployment.yaml` - Web frontend
  - `k8s/web-service.yaml` - NodePort service on port 80
- **Verification**: `kubectl apply --dry-run=client` validates all manifests

### Phase 3: Container Image Management

#### Task 3.1: Build Images Locally
- **Requirements**: Container images for k3s
- **Expected Commands**: `docker build` commands for backend and frontend
- **Verification**: `docker images` shows both images tagged

#### Task 3.3: Import Images to containerd
- **Requirements**: Image availability in k3s
- **Expected Commands**: `docker save`, `scp` to VM, `k3s ctr images import`
- **Verification**: `vagrant ssh k3s-server -- sudo crictl images` shows both images

### Phase 4: k3s Deployment & Testing

#### Task 4.1: Apply Namespace
- **Requirements**: INFRA-4, Resource isolation
- **Expected Commands**: `kubectl apply -f k8s/namespace.yaml`
- **Verification**: `kubectl get namespace names-app` shows Active

#### Task 4.2: Apply ConfigMap & Secret
- **Requirements**: Configuration management
- **Expected Commands**: `kubectl apply -f k8s/configmap.yaml -f k8s/secret.yaml -n names-app`
- **Verification**: Resources created in names-app namespace

#### Task 4.3-4.5: Deploy All Services
- **Requirements**: ALL deployment requirements
- **Expected Commands**: `kubectl apply -f k8s/ -n names-app`
- **Verification**:
  - `kubectl get pods -n names-app` shows all pods Running
  - `kubectl get pvc -n names-app` shows PVC Bound
  - `kubectl get svc -n names-app` shows all services

#### Task 4.6: Test Pod Health Probes
- **Requirements**: HEALTH-1, HEALTH-2 validation
- **Verification**:
  - DB pod readiness probe (pg_isready) succeeds
  - API pod liveness/readiness probes (/api/health) succeed
  - All pods show Ready status

#### Task 4.7: Test Service Discovery
- **Requirements**: NET-2, DNS-based discovery
- **Verification**:
  - `kubectl exec <api-pod> -n names-app -- ping db` succeeds
  - API connects to database using service name (db.names-app.svc.cluster.local)

#### Task 4.8: Verify PVC Persistence
- **Requirements**: TOPO-2, Data persistence
- **Test Procedure**:
  1. Add data via API
  2. Delete DB pod: `kubectl delete pod <db-pod> -n names-app`
  3. Wait for StatefulSet to recreate pod
  4. Verify data still exists
- **Verification**: Data persists across pod restarts, PVC remains Bound

### Phase 5: Operations

#### Task 5.0: Ensure compose.yaml for Development
- **Requirements**: OPS-5, Parallel workflows
- **Expected Files**: `src/compose.yaml` or `src/docker-compose.yml`
- **Verification**:
  - Local development with `docker-compose up` works
  - Contains all bug fixes from Phase 0

#### Task 5.4: Create ops/init-k3s.sh
- **Requirements**: OPS-1, Cluster initialization automation
- **Expected Commits**: `feat: add ops/init-k3s.sh cluster initialization script`
- **Expected Files**: `ops/init-k3s.sh` (new, executable)
- **Script Functions**:
  - Check VMs running
  - Install/verify k3s
  - Configure kubectl access
  - Verify cluster operational
- **Verification**: Running script from scratch initializes complete k3s cluster

#### Task 5.5: Create ops/deploy.sh
- **Requirements**: OPS-2, Deployment automation
- **Expected Commits**: `feat: add ops/deploy.sh k3s deployment script`
- **Expected Files**: `ops/deploy.sh` (new, executable)
- **Script Functions**:
  - Build images locally
  - Save and transfer images to VM
  - Import images to containerd via k3s ctr
  - Apply all k8s manifests
  - Show deployment status
- **Verification**: Single command deploys entire application to k3s

#### Task 5.6: Create ops/verify.sh
- **Requirements**: OPS-3, Automated verification
- **Expected Commits**: `feat: add ops/verify.sh k3s verification script`
- **Expected Files**: `ops/verify.sh` (new, executable)
- **Script Functions**:
  - Check namespace and pod status
  - Verify pod health probes (HEALTH-1, HEALTH-2)
  - Test service discovery (NET-2)
  - Verify PVC persistence (TOPO-2)
  - Test application endpoints
  - Provide pass/fail summary
- **Verification**: Script validates all k3s requirements

#### Task 5.8: Update README
- **Requirements**: OPS-5, Documentation
- **Expected Commits**: `docs: update README with k3s deployment instructions`
- **Expected Files**: `README.md` (modified)
- **Documentation Sections**:
  - Architecture (dev vs prod)
  - Prerequisites (Vagrant, VirtualBox, kubectl)
  - Local development with compose.yaml
  - Production deployment to k3s with ops scripts
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
| **TOPO-1**: Server runs web+api | `kubectl get pods -n names-app -o wide` | Pods scheduled on k3s nodes | Task 4.3-4.5, 5.6 |
| **TOPO-2**: PVC persistence | `kubectl get pvc -n names-app` | PVC Bound, data survives pod restarts | Task 4.8, 5.6 |
| **TOPO-3**: NodePort access | `curl http://192.168.56.10:<nodeport>` | Web accessible via NodePort | Task 4.9, 5.6 |
| **TOPO-4**: Resource limits | `kubectl describe pod <pod> -n names-app` | Pods have resource limits/requests | Task 5.1, 5.6 |

### Network Verification
| Network Requirement | Verification Method | Success Criteria | Task Reference |
|--------------------|-------------------|------------------|----------------|
| **NET-1**: Cluster networking | `kubectl get pods -n names-app` | All pods Running | Task 1.2, 4.3-4.5 |
| **NET-2**: DNS service discovery | `kubectl exec <api-pod> -n names-app -- ping db` | API reaches DB by service name | Task 4.7, 5.6 |
| **NET-3**: Services expose pods | `kubectl get svc -n names-app` | All services have endpoints | Task 2.6-2.10, 4.3-4.5 |

### Health Check Verification
| Health Requirement | Verification Method | Success Criteria | Task Reference |
|-------------------|-------------------|------------------|----------------|
| **HEALTH-1**: DB readiness probe | `kubectl describe pod <db-pod> -n names-app` | pg_isready probe succeeds | Task 2.5, 4.6 |
| **HEALTH-2**: API health probes | `kubectl describe pod <api-pod> -n names-app` | /api/health probes succeed | Task 0.4, 2.7, 4.6, 5.6 |

### Infrastructure Verification
| Infrastructure Req | Verification Method | Success Criteria | Task Reference |
|-------------------|-------------------|------------------|----------------|
| **INFRA-1**: k3s VM(s) running | `vagrant status` | VM(s) running | Task 1.3 |
| **INFRA-2**: k3s installed | `vagrant ssh k3s-server -- sudo k3s kubectl get nodes` | k3s cluster operational | Task 1.2 |
| **INFRA-3**: kubectl access | `kubectl get nodes` | Nodes shown as Ready | Task 1.4, 1.5 |
| **INFRA-4**: Namespace exists | `kubectl get namespace names-app` | Namespace Active | Task 2.1, 4.1 |

### Operational Automation Verification
| Ops Requirement | Verification Method | Success Criteria | Task Reference |
|----------------|-------------------|------------------|----------------|
| **OPS-1**: init-k3s.sh | Run script from scratch | Initializes k3s cluster | Task 5.4 |
| **OPS-2**: deploy.sh | Run script | Deploys full application to k3s | Task 5.5 |
| **OPS-3**: verify.sh | Run script | All k3s checks pass | Task 5.6 |
| **OPS-4**: cleanup.sh | Run script | Safely removes k8s resources | Task 5.7 |
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
- [ ] **Vagrantfile**: Task 1.1 completed - k3s VM(s) configured
- [ ] **k3s Installed**: Task 1.2 completed - k3s cluster operational
- [ ] **VMs Running**: Task 1.3 completed - Vagrant up successful
- [ ] **kubectl Access**: Task 1.4 completed - kubeconfig configured
- [ ] **Cluster Verified**: Task 1.5 passed - kubectl get nodes shows Ready

### Phase 2: Kubernetes Manifests Completion
- [ ] **k8s/ Directory**: All manifests created in k8s/ directory
- [ ] **Namespace**: Task 2.1 completed - names-app namespace defined
- [ ] **ConfigMap**: Task 2.2 completed - Database config defined
- [ ] **Secret**: Task 2.3 completed - Credentials properly encoded
- [ ] **PVC**: Task 2.4 completed - Persistent volume claim defined
- [ ] **DB StatefulSet & Service**: Tasks 2.5-2.6 completed - DB resources with pg_isready probes
- [ ] **API Deployment & Service**: Tasks 2.7-2.8 completed - API with 2 replicas and health probes
- [ ] **Web Deployment & Service**: Tasks 2.9-2.10 completed - Web with NodePort
- [ ] **Validation**: All manifests validate with kubectl --dry-run=client

### Phase 3: Container Image Management Completion
- [ ] **Images Built**: Task 3.1 completed - Both images built locally
- [ ] **Images Saved**: Task 3.2 completed - Saved to tar and transferred to VM
- [ ] **Images Imported**: Task 3.3 completed - Imported to containerd, visible in crictl

### Phase 4: k3s Deployment & Testing Completion
- [ ] **Namespace Applied**: Task 4.1 completed - Namespace active
- [ ] **Config Applied**: Task 4.2 completed - ConfigMap and Secret created
- [ ] **DB Deployed**: Task 4.3 completed - DB pod Running, PVC Bound
- [ ] **API Deployed**: Task 4.4 completed - API pods Running
- [ ] **Web Deployed**: Task 4.5 completed - Web pod Running
- [ ] **Health Probes**: Task 4.6 passed - All probes succeeding
- [ ] **DNS Working**: Task 4.7 passed - API reaches DB by service name
- [ ] **Persistence Verified**: Task 4.8 passed - Data survives pod restarts
- [ ] **E2E Testing**: Task 4.9 passed - Full CRUD works via NodePort

### Phase 5: Production Hardening & Operations Completion
- [ ] **compose.yaml**: Task 5.0 verified - Local dev workflow preserved
- [ ] **Resource Limits**: Task 5.1 completed - CPU/memory limits added
- [ ] **HPA (Optional)**: Task 5.2 completed - Horizontal Pod Autoscaler configured
- [ ] **Operations Guide**: Task 5.3 completed - k3s operations documented
- [ ] **init-k3s.sh**: Task 5.4 completed - Cluster init automation
- [ ] **deploy.sh**: Task 5.5 completed - k3s deployment automation
- [ ] **verify.sh**: Task 5.6 completed - Verification automation
- [ ] **cleanup.sh**: Task 5.7 completed - Cleanup automation
- [ ] **README Updated**: Task 5.8 completed - Documentation complete
- [ ] **Final Validation**: Task 5.9 passed - All requirements met

### Final Acceptance Checklist

#### Topology & Constraints ✅
- [ ] **TOPO-1**: k3s server runs web + api pods (verified)
- [ ] **TOPO-2**: DB data persists via PVC (verified)
- [ ] **TOPO-3**: Web accessible via NodePort (verified)
- [ ] **TOPO-4**: Resource limits configured on pods (verified)

#### Network & Service Discovery ✅
- [ ] **NET-1**: k3s CNI networking operational (verified)
- [ ] **NET-2**: DNS service discovery works (API→db) (verified)
- [ ] **NET-3**: All pods reachable via Services (verified)

#### Health Checks ✅
- [ ] **HEALTH-1**: DB uses pg_isready readiness probe (verified)
- [ ] **HEALTH-2**: API `/api/health` liveness/readiness probes (verified)

#### Infrastructure ✅
- [ ] **INFRA-1**: k3s VM(s) running via Vagrant (verified)
- [ ] **INFRA-2**: k3s cluster operational (verified)
- [ ] **INFRA-3**: kubectl access configured (verified)
- [ ] **INFRA-4**: names-app namespace created (verified)

#### Operations ✅
- [ ] **OPS-1**: ops/init-k3s.sh works (verified)
- [ ] **OPS-2**: ops/deploy.sh works (verified)
- [ ] **OPS-3**: ops/verify.sh validates all requirements (verified)
- [ ] **OPS-4**: ops/cleanup.sh safely removes resources (verified)
- [ ] **OPS-5**: compose.yaml for local development works (verified)

#### Bug Fixes ✅
- [ ] **BUG-1**: GET response format fixed (verified)
- [ ] **BUG-2**: Frontend display logic fixed (verified)
- [ ] **BUG-3**: DELETE uses ID parameter (verified)
- [ ] **BUG-4**: Health endpoint format fixed (verified)
- [ ] **BUG-5**: DATABASE_URL environment variable supported (verified)

### Documentation Completeness
- [ ] **README.md**: Updated with dev and k3s prod workflows
- [ ] **k8s/ manifests**: Complete Kubernetes resource definitions
- [ ] **ops/ scripts**: All 4 k3s scripts created and documented
- [ ] **Current State Spec**: Documents bugs and current state
- [ ] **Target State Spec**: Documents k3s/Kubernetes architecture
- [ ] **Plan**: 6 phases with milestones
- [ ] **Tasks**: 30+ tasks with acceptance criteria
- [ ] **Traceability**: This document complete

## Summary

This traceability matrix ensures complete coverage from requirements through implementation for the k3s migration:

- **30+ tasks** across **6 phases** (Phase 0-5)
- **All topology constraints** traced and verified (pod placement, persistence, resources)
- **All network requirements** implemented and tested (CNI, Services, DNS)
- **All health checks** configured and validated (readiness/liveness probes)
- **Complete operational automation** via ops/ scripts
- **Parallel dev/prod workflows** maintained (Docker Compose + k3s)
- **Comprehensive verification** at each phase

Every requirement from the target specification is implemented through specific tasks, with clear verification methods and success criteria for k3s/Kubernetes deployment.