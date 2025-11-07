# Names Manager

A secure, containerized 3-tier web application for managing personal contact names with comprehensive input validation and XSS protection.

## Features

- ✅ **Add, List, and Delete Names**: Simple interface for managing personal contacts
- 🔒 **Security First**: XSS prevention with HTML sanitization and input validation  
- 🏥 **Health Monitoring**: Built-in health check endpoints for application monitoring
- 🐳 **Containerized**: Fully containerized with Docker for easy deployment
- 📊 **Logging & Monitoring**: Comprehensive logging and audit trails
- 🧪 **Well Tested**: Unit tests and comprehensive manual testing procedures

## Architecture

This application supports three deployment modes:

- **Development (Single-Host)**: Uses `src/docker-compose.yml` for local development with Docker Compose
- **Production (Docker Swarm)**: Uses `swarm/stack.yaml` for distributed deployment with Docker Swarm
  - **Manager VM** (192.168.56.10): Runs web and API services
  - **Worker VM** (192.168.56.11): Runs database service with persistent storage
- **Production (Kubernetes/k3s)**: Uses `k8s/*.yaml` manifests for Kubernetes deployment
  - **k3s-server** (192.168.56.10): Control plane node running all application pods
  - **k3s-agent** (192.168.56.11): Worker node (available for scaling)

## Prerequisites

### For Local Development
- **Docker Desktop** (version 20.0+ recommended)
- **Docker Compose** (version 2.0+ recommended)  
- **Web Browser** (Chrome, Firefox, Safari, or Edge)
- **4GB RAM** minimum for containers

### For Production Deployment
- **Vagrant** (version 2.2+ recommended)
- **VirtualBox** (version 6.1+ recommended)
- **8GB RAM** minimum for VMs
- **20GB disk space** for VM images
- **kubectl** (for k3s deployment management)

## Local Development (Single-Host)

### Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/TY1Fan/Name-Manager.git
cd Name-Manager

# 2. Set up environment (optional - defaults work)
cd src
cp .env.example .env
# Edit .env if needed

# 3. Start the application
docker compose up -d

# 4. Access the application
open http://localhost:8080

# 5. Stop when done
docker compose down
```

**Access Points:**
- **Web Interface**: http://localhost:8080
- **API Health**: http://localhost:8080/api/health
- **Database Health**: http://localhost:8080/api/health/db

**Quick Test:** Add "John Doe", verify it appears, then delete it

## How it works

### System Architecture

**Development (Single-Host):**
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Frontend      │    │     Backend      │    │   Database      │
│   (Nginx)       │    │    (FastAPI)     │    │  (PostgreSQL)   │
│   Port 8080     │◄──►│   Port 8000      │◄──►│   Port 5432     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         Single Docker Host (Docker Compose)
```

**Production (Docker Swarm - Multi-Host):**
```
┌──────────────────────────────────────────────────────────────┐
│                     Docker Swarm Cluster                     │
├──────────────────────────────┬───────────────────────────────┤
│     Manager Node             │      Worker Node              │
│   (192.168.56.10)            │    (192.168.56.11)            │
│                              │                               │
│  ┌────────────┐              │   ┌─────────────────┐        │
│  │  Frontend  │              │   │    Database     │        │
│  │  (Nginx)   │              │   │  (PostgreSQL)   │        │
│  │  1 replica │              │   │   1 replica     │        │
│  └────────────┘              │   └─────────────────┘        │
│       ▲                      │          ▲                    │
│       │                      │          │                    │
│  ┌────┴───────┐              │          │                    │
│  │    API     │              │          │                    │
│  │ (FastAPI)  │◄─────────────┼──────────┘                    │
│  │ 2 replicas │   Overlay    │   /var/lib/postgres-data     │
│  └────────────┘   Network    │   (Persistent Storage)        │
└──────────────────────────────┴───────────────────────────────┘
```

**Production (Kubernetes/k3s - Multi-Node):**
```
┌──────────────────────────────────────────────────────────────┐
│                      k3s Cluster                             │
├──────────────────────────────┬───────────────────────────────┤
│    k3s-server Node           │     k3s-agent Node            │
│  (Control Plane)             │     (Worker)                  │
│   (192.168.56.10)            │    (192.168.56.11)            │
│                              │                               │
│  ┌────────────────┐          │   Available for               │
│  │   Frontend     │          │   scaling                     │
│  │   (Nginx)      │          │                               │
│  │   1 replica    │          │                               │
│  │   NodePort     │          │                               │
│  │   30080        │          │                               │
│  └────────────────┘          │                               │
│         ▲                    │                               │
│         │                    │                               │
│  ┌──────┴────────┐           │                               │
│  │   Backend     │           │                               │
│  │   (FastAPI)   │           │                               │
│  │   2 replicas  │           │                               │
│  │   + HPA       │           │                               │
│  └───────────────┘           │                               │
│         ▲                    │                               │
│         │                    │                               │
│  ┌──────┴────────┐           │                               │
│  │   Database    │           │                               │
│  │  (PostgreSQL) │           │                               │
│  │  StatefulSet  │           │                               │
│  │   1 replica   │           │                               │
│  └───────────────┘           │                               │
│         │                    │                               │
│    PersistentVolume          │                               │
│    (local-path)              │                               │
│    /var/lib/rancher/k3s/     │                               │
│    storage/pvc-*/            │                               │
└──────────────────────────────┴───────────────────────────────┘
```

### Components

- **Frontend**: Nginx-served static HTML/JS/CSS with API proxying
- **Backend**: FastAPI REST API with input validation and sanitization
- **Database**: PostgreSQL 15 with persistent storage
- **Security**: XSS prevention, input validation, health monitoring
- **Secrets Management**: Docker Secrets (Swarm) or Kubernetes Secrets (k3s)
- **Auto-scaling**: HorizontalPodAutoscaler (k3s only)

### API Endpoints
- `GET /api/names` - List all names
- `POST /api/names` - Add a new name
- `DELETE /api/names/{id}` - Delete a name by ID
- `GET /api/health` - Application health check
- `GET /api/health/db` - Database connectivity check

## Testing

### Automated Testing
```bash
# Run backend unit tests
cd src
docker compose exec backend python -m pytest

# Run tests with coverage
docker compose exec backend python -m pytest --cov
```

### Manual Testing  
Comprehensive manual testing procedures are available in [`TESTING.md`](src/backend/tests/TESTING.md), including:
- Functional testing (add/delete/list operations)
- Security testing (XSS prevention validation)  
- Error handling and edge cases
- Cross-browser compatibility
- Performance and load testing

### Quick Manual Test

**For Local Development (port 8080):**
```bash
curl http://localhost:8080/api/health
curl http://localhost:8080/api/names
```

**For Production Swarm (port 8081):**
```bash
./ops/verify.sh  # Automated verification
curl http://localhost:8081/api/health
curl http://localhost:8081/api/names
```

**For Production k3s (port 30080):**
```bash
kubectl get pods -n names-app
curl http://localhost:30080/api/health
curl http://localhost:30080/api/names
```

**Test Checklist:**
1. **Basic Functionality**: Add "John Doe", verify it appears, then delete it
2. **Input Validation**: Try empty name, long name (>50 chars), whitespace only
3. **Security Test**: Try `<script>alert('test')</script>` - should be safely escaped
4. **Health Check**: Verify both `/api/health` and `/api/health/db` return healthy status

## Production Deployment (Docker Swarm)

For production deployment on a distributed multi-node Docker Swarm cluster:

### Complete Deployment Workflow

```bash
# 1. Start VMs (manager + worker)
vagrant up

# 2. Initialize Swarm cluster (first time only)
./ops/init-swarm.sh

# 3. Build and deploy application
./ops/deploy.sh

# 4. Verify deployment health
./ops/verify.sh

# 5. Access application
open http://localhost:8081

# 6. Clean up (when done - preserves data)
./ops/cleanup.sh
```

**Access Points:**
- **Web Interface**: http://localhost:8081
- **API Health**: http://localhost:8081/api/health
- **Database Health**: http://localhost:8081/api/health/db

### Operations Scripts

All operational scripts are in the `ops/` directory:

| Script | Purpose | Usage |
|--------|---------|-------|
| **init-swarm.sh** | Initialize Docker Swarm cluster with node labels and network | Run once after `vagrant up` |
| **deploy.sh** | Build images, transfer to manager, deploy stack | Run to deploy/update app |
| **verify.sh** | Verify deployment health, placement, and connectivity | Run after deployment |
| **cleanup.sh** | Remove stack safely (preserves persistent data) | Run to clean up |

See [`ops/README.md`](ops/README.md) for detailed documentation.

### Service Placement

- **Manager Node** (192.168.56.10):
  - Web service (1 replica) - Port 80
  - API service (2 replicas) - Port 8000
  
- **Worker Node** (192.168.56.11):
  - Database service (1 replica) - PostgreSQL 15
  - Persistent storage: `/var/lib/postgres-data`

### Troubleshooting

View service logs:
```bash
vagrant ssh manager -c "docker service logs names_<service>"
```

Check service status:
```bash
vagrant ssh manager -c "docker service ps names_<service>"
```

List all services:
```bash
vagrant ssh manager -c "docker stack services names"
```

Restart a service:
```bash
vagrant ssh manager -c "docker service update --force names_<service>"
```

---

## Production Deployment (Kubernetes/k3s)

For production deployment on a Kubernetes cluster using k3s:

### Complete Deployment Workflow

```bash
# 1. Start VMs (k3s-server + k3s-agent)
vagrant up

# 2. Verify cluster is ready
kubectl get nodes
# Both nodes should show "Ready"

# 3. Deploy application (automated)
./ops/deploy-k3s.sh

# 4. Verify deployment
kubectl get all -n names-app
curl http://localhost:30080/api/health/db

# 5. Access application
open http://localhost:30080

# 6. Clean up (when done)
./ops/cleanup-k3s.sh
```

**Access Points:**
- **Web Interface**: http://localhost:30080
- **API Health**: http://localhost:30080/api/health
- **Database Health**: http://localhost:30080/api/health/db

### Operations Scripts

k3s-specific scripts are in the `ops/` directory:

| Script | Purpose | Usage |
|--------|---------|-------|
| **deploy-k3s.sh** | Full automated deployment to k3s cluster | Run to deploy application |
| **cleanup-k3s.sh** | Remove all resources safely (prompts before data deletion) | Run to clean up |
| **update-k3s.sh** | Build new images and update deployments | Run to update application |

See [`ops/README-k3s.md`](ops/README-k3s.md) for detailed documentation.

### Pod Placement

All pods run on **k3s-server** node (192.168.56.10) due to nodeSelector constraints:
- **Frontend** (1 replica) - Nginx, NodePort 30080
- **Backend** (2 replicas, auto-scales 2-5 via HPA) - FastAPI
- **Database** (1 replica) - PostgreSQL 15 StatefulSet
- **Persistent Storage**: k3s local-path provisioner at `/var/lib/rancher/k3s/storage/`

### Kubernetes Resources

All manifests are in the `k8s/` directory:

| Resource | File | Description |
|----------|------|-------------|
| **Namespace** | namespace.yaml | Isolates application resources |
| **ConfigMap** | configmap.yaml | Non-sensitive configuration |
| **Secret** | secret.yaml | Database credentials |
| **PVC** | database-pvc.yaml | 1Gi persistent volume claim |
| **StatefulSet** | database-statefulset.yaml | PostgreSQL with persistent storage |
| **Deployments** | backend-deployment.yaml<br>frontend-deployment.yaml | Backend API and frontend |
| **Services** | database-service.yaml<br>backend-service.yaml<br>frontend-service.yaml | Internal and external networking |
| **HPA** | backend-hpa.yaml | Auto-scaling for backend (2-5 replicas) |

### Troubleshooting

View pod logs:
```bash
kubectl logs -n names-app <pod-name>
kubectl logs -n names-app -l app=backend --tail=50 -f
```

Check pod status:
```bash
kubectl get pods -n names-app -o wide
kubectl describe pod <pod-name> -n names-app
```

Check events:
```bash
kubectl get events -n names-app --sort-by='.lastTimestamp'
```

Restart deployments:
```bash
kubectl rollout restart deployment/backend -n names-app
kubectl rollout restart deployment/frontend -n names-app
```

Check resource usage:
```bash
kubectl top nodes
kubectl top pods -n names-app
```

For comprehensive operations guide, see [`docs/OPERATIONS.md`](docs/OPERATIONS.md).

---

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for development guidelines and contribution process.

## License

See [`LICENSE`](LICENSE) for license information.