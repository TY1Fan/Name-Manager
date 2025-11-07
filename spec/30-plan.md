# Names Manager - Implementation Plan: k3s Migration

## Executive Summary

This plan outlines the migration of the Names Manager application from **Docker Swarm** to **k3s (Lightweight Kubernetes)** orchestration. The application will be deployed on a Kubernetes cluster with cloud-native deployment patterns including Deployments, StatefulSets, Services, ConfigMaps, and Secrets.

**Primary Goal**: Migrate from Docker Swarm to k3s/Kubernetes with cloud-native deployment

**Total Timeline**: 2-3 weeks
**Resource Requirements**: 1 developer (part-time)
**Infrastructure**: 1-2 Vagrant VMs (k3s server + optional agent)
**Budget Impact**: None (using existing tools and local VMs)
**Learning Outcome**: Hands-on Kubernetes experience with industry-standard orchestration

## Implementation Phases

### Phase 0: Prerequisites & Preparation
**Duration**: 1-2 days
**Priority**: HIGH
**Effort**: 4-6 hours

#### Milestone 0.1: Verify Current State
**Goal**: Ensure application is functional before k3s migration

**Tasks:**
- [ ] Verify application works with Docker Compose
- [ ] Verify Docker Swarm deployment still functional (for rollback)
- [ ] Test all CRUD operations working correctly
- [ ] Confirm all bug fixes from swarm-orchestration branch present
- [ ] Review current architecture and identify k8s equivalents

**Deliverables:**
- Verified working baseline
- Documentation of current Swarm setup
- List of k8s resources needed

**Acceptance Criteria:**
- ✅ Application fully functional via Docker Compose
- ✅ All bugs previously fixed remain fixed
- ✅ Names list displays correctly with timestamps
- ✅ Can add and delete names successfully
- ✅ Health endpoints working (`/healthz`, `/api/health/db`)
- ✅ Swarm deployment still works (rollback option)

**Testing:**
```bash
# Verify with Docker Compose
cd src/
docker-compose up --build
# Test: Add name, view list, delete name
docker-compose down

# Verify Swarm still works (optional)
docker stack ls
docker stack services names-app  # If deployed
```

---

### Phase 1: k3s Infrastructure Setup
**Duration**: 2-3 days
**Priority**: High
**Effort**: 8-10 hours

#### Milestone 1.1: Vagrant VM Configuration for k3s
**Goal**: Set up VM(s) for k3s cluster

**Tasks:**
- [ ] Update `Vagrantfile` for k3s deployment
- [ ] Configure k3s-server VM: Ubuntu 22.04, 4GB RAM, 2 CPU, IP: 192.168.56.10
- [ ] Optional: Configure k3s-agent VM: Ubuntu 22.04, 2GB RAM, 2 CPU, IP: 192.168.56.11
- [ ] Set up private network
- [ ] Add provisioning script to install k3s automatically
- [ ] Configure port forwarding for NodePort access (30080)

**Deliverables:**
- Updated `Vagrantfile` with k3s VM definitions
- `vagrant/install-k3s-server.sh` provisioning script
- Optional: `vagrant/install-k3s-agent.sh` for worker node
- Network configuration for cluster communication

**Acceptance Criteria:**
- ✅ k3s-server VM starts with `vagrant up k3s-server`
- ✅ k3s installed and running on server
- ✅ kubectl accessible from within VM
- ✅ SSH access works
- ✅ Port 30080 accessible from laptop browser
- ✅ Optional: Agent VM can communicate with server

**Vagrant Configuration:**
```ruby
Vagrant.configure("2") do |config|
  # k3s Server (Control Plane)
  config.vm.define "k3s-server" do |server|
    server.vm.box = "ubuntu/jammy64"
    server.vm.hostname = "k3s-server"
    server.vm.network "private_network", ip: "192.168.56.10"
    server.vm.network "forwarded_port", guest: 30080, host: 8080  # NodePort
    server.vm.network "forwarded_port", guest: 6443, host: 6443   # k8s API
    server.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"  # k3s needs more RAM
      vb.cpus = 2
      vb.name = "k3s-server"
    end
    server.vm.provision "shell", path: "vagrant/install-k3s-server.sh"
  end
  
  # k3s Agent (Worker) - OPTIONAL
  config.vm.define "k3s-agent", autostart: false do |agent|
    agent.vm.box = "ubuntu/jammy64"
    agent.vm.hostname = "k3s-agent"
    agent.vm.network "private_network", ip: "192.168.56.11"
    agent.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
      vb.name = "k3s-agent"
    end
    # Agent provisioning done manually after getting token from server
  end
end
```

**Provisioning Script** (`vagrant/install-k3s-server.sh`):
```bash
#!/bin/bash
set -e

echo "Installing k3s server..."

# Install k3s
curl -sfL https://get.k3s.io | sh -

# Wait for k3s to be ready
sleep 10

# Make kubeconfig accessible to vagrant user
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

# Copy kubeconfig for vagrant user
mkdir -p /home/vagrant/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sudo chown vagrant:vagrant /home/vagrant/.kube/config

echo "k3s server installed successfully!"
echo "Node token (save for agents):"
sudo cat /var/lib/rancher/k3s/server/node-token
```

**Testing:**
```bash
vagrant up k3s-server
vagrant ssh k3s-server

# Inside VM
kubectl get nodes
# Should show: k3s-server Ready control-plane,master

kubectl cluster-info
# Should show cluster running
```

#### Milestone 1.2: kubectl Configuration on Laptop
**Goal**: Access k3s cluster from laptop using kubectl

**Tasks:**
- [ ] Install kubectl on laptop (if not already installed)
- [ ] Copy kubeconfig from k3s-server to laptop
- [ ] Update kubeconfig with VM IP address
- [ ] Set KUBECONFIG environment variable
- [ ] Verify cluster access from laptop
- [ ] Test kubectl commands

**Deliverables:**
- kubectl installed on laptop
- `~/.kube/k3s-config` kubeconfig file
- Working kubectl access from laptop

**Acceptance Criteria:**
- ✅ kubectl installed on laptop
- ✅ Can run `kubectl get nodes` from laptop
- ✅ Can run `kubectl cluster-info` from laptop
- ✅ kubeconfig points to VM IP (192.168.56.10)
- ✅ Can view k3s cluster resources from laptop

**Commands:**
```bash
# Install kubectl on macOS
brew install kubectl

# Or download binary
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Copy kubeconfig from VM
vagrant ssh k3s-server -- sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/k3s-config

# Update server URL in kubeconfig
sed -i '' 's/127.0.0.1/192.168.56.10/g' ~/.kube/k3s-config

# Set KUBECONFIG (add to ~/.zshrc for persistence)
export KUBECONFIG=~/.kube/k3s-config

# Test access from laptop
kubectl get nodes
# Should show: k3s-server Ready control-plane,master

kubectl cluster-info
kubectl get namespaces
```

#### Milestone 1.3: Optional Agent Node Setup
**Goal**: Add worker node to k3s cluster (optional for single-node testing)

**Tasks:**
- [ ] Start k3s-agent VM
- [ ] Get node token from k3s-server
- [ ] Install k3s agent with server URL and token
- [ ] Verify agent joined cluster
- [ ] Test pod scheduling on agent node

**Deliverables:**
- k3s-agent VM running and joined to cluster (optional)
- Multi-node k3s cluster (optional)

**Acceptance Criteria:**
- ✅ Agent VM running
- ✅ `kubectl get nodes` shows both server and agent
- ✅ Both nodes in Ready state
- ✅ Pods can be scheduled on agent node

**Commands:**
```bash
# Get node token from server
vagrant ssh k3s-server -- sudo cat /var/lib/rancher/k3s/server/node-token
# Save token: K10xxx...::server:xxx

# Start agent VM
vagrant up k3s-agent

# Install k3s agent
vagrant ssh k3s-agent

# Inside agent VM
K3S_URL="https://192.168.56.10:6443"
K3S_TOKEN="<TOKEN_FROM_SERVER>"

curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -

# Verify from laptop
kubectl get nodes
# Should show both nodes
```

---

### Phase 2: Kubernetes Manifests Creation
**Duration**: 3-4 days
**Priority**: High
**Effort**: 12-15 hours

#### Milestone 2.1: Create Directory Structure and Namespace
**Goal**: Organize Kubernetes manifests and create namespace

**Tasks:**
- [ ] Create `k8s/` directory in project root
- [ ] Create `k8s/namespace.yaml` for application namespace
- [ ] Create `k8s/configmap.yaml` for application configuration
- [ ] Create `k8s/secret.yaml` for database credentials
- [ ] Document Kubernetes resource organization
- [ ] Apply namespace to cluster

**Deliverables:**
- `k8s/` directory with organized manifests
- `k8s/namespace.yaml` - Namespace definition
- `k8s/configmap.yaml` - Application configuration
- `k8s/secret.yaml` - Database credentials
- Clean separation of configuration from deployment

**Acceptance Criteria:**
- ✅ `k8s/` directory exists in project root
- ✅ Namespace `names-app` defined
- ✅ ConfigMap contains all app configuration (MAX_NAME_LENGTH, LOG_LEVEL, etc.)
- ✅ Secret contains database credentials securely
- ✅ Manifests follow Kubernetes best practices
- ✅ All files use YAML format with proper indentation
- ✅ Resources use consistent naming conventions

**Example Namespace Manifest** (`k8s/namespace.yaml`):
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: names-app
  labels:
    app: names-manager
```

**Example ConfigMap** (`k8s/configmap.yaml`):
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: names-app-config
  namespace: names-app
data:
  MAX_NAME_LENGTH: "50"
  LOG_LEVEL: "INFO"
  DB_HOST: "db-service"
  DB_PORT: "5432"
  DB_NAME: "namesdb"
```

**Example Secret** (`k8s/secret.yaml`):
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: names-app
type: Opaque
stringData:
  POSTGRES_USER: names_user
  POSTGRES_PASSWORD: names_pass
  POSTGRES_DB: namesdb
```

---

#### Milestone 2.2: Database StatefulSet and Persistent Storage
**Goal**: Create StatefulSet for PostgreSQL with persistent volume

**Tasks:**
- [ ] Create `k8s/database-pvc.yaml` for persistent volume claim
- [ ] Create `k8s/database-statefulset.yaml` with PostgreSQL configuration
- [ ] Create `k8s/database-service.yaml` for ClusterIP service
- [ ] Configure health checks with liveness and readiness probes
- [ ] Mount PVC to PostgreSQL data directory
- [ ] Reference ConfigMap and Secret in StatefulSet

**Deliverables:**
- `k8s/database-pvc.yaml` - PersistentVolumeClaim for database storage
- `k8s/database-statefulset.yaml` - PostgreSQL StatefulSet with 1 replica
- `k8s/database-service.yaml` - ClusterIP service for database access
- Complete database configuration with health checks

**Acceptance Criteria:**
- ✅ PVC requests 1Gi storage (or appropriate size)
- ✅ StatefulSet uses `postgres:15` image
- ✅ Environment variables loaded from Secret
- ✅ Volume mounted to `/var/lib/postgresql/data`
- ✅ Liveness probe uses `pg_isready` command
- ✅ Readiness probe verifies database connectivity
- ✅ Service named `db-service` with port 5432
- ✅ Service type ClusterIP for internal access only

**Example Database StatefulSet** (`k8s/database-statefulset.yaml`):
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: names-app
spec:
  serviceName: db-service
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        ports:
        - containerPort: 5432
          name: postgres
        envFrom:
        - secretRef:
            name: db-credentials
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - names_user
            - -d
            - namesdb
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - names_user
            - -d
            - namesdb
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
```

---

#### Milestone 2.3: Backend API Deployment
**Goal**: Create Deployment for Flask backend with 2 replicas

**Tasks:**
- [ ] Create `k8s/backend-deployment.yaml` for Flask API
- [ ] Create `k8s/backend-service.yaml` for ClusterIP service
- [ ] Configure DATABASE_URL from ConfigMap and Secret
- [ ] Set up health check endpoints
- [ ] Configure resource limits and requests
- [ ] Set replica count to 2 for high availability

**Deliverables:**
- `k8s/backend-deployment.yaml` - Flask API Deployment
- `k8s/backend-service.yaml` - ClusterIP service for API access
- Environment variable configuration from ConfigMap/Secret

**Acceptance Criteria:**
- ✅ Deployment uses locally built backend image
- ✅ Replica count set to 2
- ✅ Environment variables loaded from ConfigMap and Secret
- ✅ DATABASE_URL properly constructed
- ✅ Liveness probe uses `/healthz` endpoint
- ✅ Readiness probe uses `/api/health/db` endpoint
- ✅ Service named `api-service` with port 5000
- ✅ Resource requests/limits defined

---

#### Milestone 2.4: Frontend Nginx Deployment with NodePort
**Goal**: Create Deployment for Nginx frontend with external access

**Tasks:**
- [ ] Create `k8s/frontend-deployment.yaml` for Nginx
- [ ] Create `k8s/frontend-service.yaml` with NodePort type
- [ ] Configure proper API_URL for backend service
- [ ] Set up single replica for frontend
- [ ] Expose frontend on NodePort for external access

**Deliverables:**
- `k8s/frontend-deployment.yaml` - Nginx frontend Deployment
- `k8s/frontend-service.yaml` - NodePort service for external access
- Complete frontend configuration

**Acceptance Criteria:**
- ✅ Deployment uses locally built frontend image
- ✅ Replica count set to 1
- ✅ Service type NodePort exposing port 80
- ✅ NodePort in range 30000-32767
- ✅ Frontend can access backend via `api-service`
- ✅ External access works via VM IP and NodePort


---

### Phase 3: Container Image Management for k3s
**Duration**: 1-2 days
**Priority**: High
**Effort**: 4-6 hours

#### Milestone 3.1: Build Docker Images
**Goal**: Create container images for k3s deployment

**Tasks:**
- [ ] Build backend image using existing Dockerfile
- [ ] Build frontend image using existing Dockerfile
- [ ] Tag images appropriately
- [ ] Test images locally with Docker Compose
- [ ] Verify all functionality works in containers

**Deliverables:**
- `names-backend:latest` container image
- `names-frontend:latest` container image
- Verified working images

**Acceptance Criteria:**
- ✅ Images build without errors
- ✅ Backend image includes all Python dependencies
- ✅ Frontend image includes Nginx configuration
- ✅ Images tested locally with Docker Compose
- ✅ All endpoints functional in containers

**Build Commands:**
```bash
# Build images from src/ directory
cd src/

docker build -t names-backend:latest backend/
docker build -t names-frontend:latest frontend/

# Verify images
docker images | grep names
```

#### Milestone 3.2: Import Images to k3s
**Goal**: Make images available to k3s containerd runtime

**Tasks:**
- [ ] Save backend image to tar archive
- [ ] Save frontend image to tar archive
- [ ] Copy tar files to k3s-server VM
- [ ] Import images into k3s containerd using `ctr`
- [ ] Verify images available in k3s image store

**Deliverables:**
- Images imported into k3s containerd
- Images available for pod deployment
- Documentation of import process

**Acceptance Criteria:**
- ✅ Images saved as tar archives
- ✅ Tar files transferred to k3s-server VM
- ✅ Images imported to containerd namespace `k8s.io`
- ✅ `crictl images` shows both images on k3s-server
- ✅ Images use imagePullPolicy: Never in manifests

**Import Commands:**
```bash
# On laptop - Save images
docker save names-backend:latest > names-backend.tar
docker save names-frontend:latest > names-frontend.tar

# Transfer to k3s-server
scp -P $(vagrant port k3s-server --guest 22) \
  names-backend.tar names-frontend.tar \
  vagrant@localhost:/tmp/

# On k3s-server - Import to containerd
vagrant ssh k3s-server

sudo k3s ctr images import /tmp/names-backend.tar
sudo k3s ctr images import /tmp/names-frontend.tar

# Verify with crictl (Kubernetes CRI tool)
sudo crictl images | grep names

# Alternative: Import with ctr in k8s.io namespace
sudo ctr -n k8s.io images import /tmp/names-backend.tar
sudo ctr -n k8s.io images import /tmp/names-frontend.tar

# List images
sudo ctr -n k8s.io images ls | grep names
```

**Note on Image Pull Policy:**
In Deployment manifests, use:
```yaml
spec:
  containers:
  - name: backend
    image: names-backend:latest
    imagePullPolicy: Never  # Don't try to pull from registry
```

---

### Phase 4: k3s Deployment & Testing
**Duration**: 2-3 days
**Priority**: High  
**Effort**: 12-15 hours

#### Milestone 4.1: Deploy Namespace and Configuration
**Goal**: Apply base Kubernetes resources

**Tasks:**
- [ ] Apply namespace manifest
- [ ] Apply ConfigMap manifest
- [ ] Apply Secret manifest
- [ ] Verify resources created in k3s cluster
- [ ] Validate configuration values

**Deliverables:**
- Namespace `names-app` created
- ConfigMap and Secret available in namespace
- Verified resource creation

**Acceptance Criteria:**
- ✅ `kubectl get namespace names-app` shows Active status
- ✅ `kubectl get configmap -n names-app` shows names-app-config
- ✅ `kubectl get secret -n names-app` shows db-credentials
- ✅ ConfigMap contains all required configuration keys
- ✅ Secret contains database credentials

**Commands:**
```bash
# Apply base resources
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml

# Verify creation
kubectl get namespace names-app
kubectl get configmap -n names-app
kubectl get secret -n names-app

# Inspect resources
kubectl describe configmap names-app-config -n names-app
kubectl describe secret db-credentials -n names-app
```

---

#### Milestone 4.2: Deploy Database StatefulSet
**Goal**: Deploy PostgreSQL with persistent storage

**Tasks:**
- [ ] Apply PersistentVolumeClaim manifest
- [ ] Apply database StatefulSet manifest
- [ ] Apply database Service manifest
- [ ] Wait for StatefulSet to become ready
- [ ] Verify pod is running and healthy
- [ ] Check PVC is bound
- [ ] Verify database logs show successful initialization

**Deliverables:**
- PostgreSQL StatefulSet with 1 replica running
- PVC bound to persistent volume
- ClusterIP service for database access
- Verified database health

**Acceptance Criteria:**
- ✅ PVC `postgres-pvc` is Bound
- ✅ StatefulSet `postgres` shows 1/1 replicas ready
- ✅ Pod `postgres-0` in Running status
- ✅ Liveness probe passing
- ✅ Readiness probe passing
- ✅ Service `db-service` created with ClusterIP
- ✅ Database logs show "database system is ready to accept connections"

**Commands:**
```bash
# Apply database resources
kubectl apply -f k8s/database-pvc.yaml
kubectl apply -f k8s/database-statefulset.yaml
kubectl apply -f k8s/database-service.yaml

# Wait for database to be ready
kubectl wait --for=condition=ready pod/postgres-0 -n names-app --timeout=300s

# Check status
kubectl get statefulset -n names-app
kubectl get pods -n names-app
kubectl get pvc -n names-app
kubectl get svc -n names-app

# Check database logs
kubectl logs postgres-0 -n names-app

# Verify health probes
kubectl describe pod postgres-0 -n names-app | grep -A 10 "Liveness\|Readiness"
```

---

#### Milestone 4.3: Deploy Backend API
**Goal**: Deploy Flask backend with database connectivity

**Tasks:**
- [ ] Apply backend Deployment manifest
- [ ] Apply backend Service manifest
- [ ] Wait for deployment to become ready
- [ ] Verify pods are running (2 replicas)
- [ ] Check backend logs for database connection
- [ ] Verify API health endpoints
- [ ] Test backend connectivity from within cluster

**Deliverables:**
- Backend Deployment with 2 replicas running
- ClusterIP service for API access
- Verified API health and database connectivity

**Acceptance Criteria:**
- ✅ Deployment `backend` shows 2/2 replicas ready
- ✅ Both backend pods in Running status
- ✅ Liveness probes passing (`/healthz`)
- ✅ Readiness probes passing (`/api/health/db`)
- ✅ Service `api-service` created with ClusterIP
- ✅ Backend logs show successful database connection
- ✅ `/api/health/db` returns healthy status

**Commands:**
```bash
# Apply backend resources
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml

# Wait for backend to be ready
kubectl wait --for=condition=available deployment/backend -n names-app --timeout=300s

# Check status
kubectl get deployment -n names-app
kubectl get pods -n names-app -l app=backend
kubectl get svc -n names-app

# Check backend logs
kubectl logs -l app=backend -n names-app --tail=50

# Test health endpoint from within cluster
kubectl run test-pod --rm -i --tty --image=curlimages/curl -n names-app -- \
  curl http://api-service:5000/healthz

kubectl run test-pod --rm -i --tty --image=curlimages/curl -n names-app -- \
  curl http://api-service:5000/api/health/db
```

---

#### Milestone 4.4: Deploy Frontend and Verify End-to-End
**Goal**: Deploy Nginx frontend with external access and verify full application

**Tasks:**
- [ ] Apply frontend Deployment manifest
- [ ] Apply frontend Service manifest (NodePort)
- [ ] Wait for deployment to become ready
- [ ] Get NodePort assigned to frontend service
- [ ] Access application via browser using VM IP and NodePort
- [ ] Test all CRUD operations (Create, Read, Delete)
- [ ] Verify frontend can communicate with backend API
- [ ] Test data persistence by restarting database pod

**Deliverables:**
- Frontend Deployment with 1 replica running
- NodePort Service for external access
- Fully functional web application accessible from laptop
- Verified end-to-end functionality

**Acceptance Criteria:**
- ✅ Deployment `frontend` shows 1/1 replica ready
- ✅ Frontend pod in Running status
- ✅ Service `frontend-service` created with NodePort
- ✅ Application accessible via http://<VM_IP>:<NODE_PORT>
- ✅ Can add new names via web interface
- ✅ Can view all names (displays with timestamps)
- ✅ Can delete names via web interface
- ✅ Data persists after database pod restart
- ✅ All pods healthy and ready

**Commands:**
```bash
# Apply frontend resources
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/frontend-service.yaml

# Wait for frontend to be ready
kubectl wait --for=condition=available deployment/frontend -n names-app --timeout=300s

# Get all resources
kubectl get all -n names-app

# Get NodePort
kubectl get svc frontend-service -n names-app
# Note the NodePort (e.g., 80:30080/TCP)

# Get VM IP
vagrant ssh k3s-server -- ip addr show eth1 | grep "inet "
# Or use configured IP: 192.168.56.10

# Access application
# Open browser to: http://192.168.56.10:<NODE_PORT>
```

**Verification Steps:**
```bash
# 1. Check all pods are running
kubectl get pods -n names-app
# Expected: postgres-0, backend-xxx (2 pods), frontend-xxx (1 pod)

# 2. Test data persistence
# Add a name via web UI, then restart database pod
kubectl delete pod postgres-0 -n names-app
kubectl wait --for=condition=ready pod/postgres-0 -n names-app --timeout=300s
# Verify name still exists in UI

# 3. Test backend scaling
kubectl get pods -n names-app -l app=backend
# Should show 2 backend pods

# 4. View logs
kubectl logs -l app=backend -n names-app --tail=20
kubectl logs -l app=frontend -n names-app --tail=20

# 5. Check events for any issues
kubectl get events -n names-app --sort-by='.lastTimestamp'
```


---

### Phase 5: Production Hardening & Optimization
**Duration**: 2-3 days
**Priority**: Medium
**Effort**: 8-10 hours

#### Milestone 5.1: Resource Management
**Goal**: Configure resource requests and limits for all workloads

**Tasks:**
- [ ] Add resource requests to database StatefulSet
- [ ] Add resource limits to database StatefulSet
- [ ] Add resource requests/limits to backend Deployment
- [ ] Add resource requests/limits to frontend Deployment
- [ ] Monitor resource usage with kubectl top
- [ ] Adjust values based on actual usage

**Deliverables:**
- All workloads have resource requests defined
- Resource limits prevent resource exhaustion
- Optimized resource allocation

**Acceptance Criteria:**
- ✅ Database has memory request/limit (e.g., 512Mi/1Gi)
- ✅ Backend has CPU and memory requests/limits
- ✅ Frontend has CPU and memory requests/limits
- ✅ Pods scheduled successfully with resources
- ✅ No pods in Pending state due to resources

**Example Resource Configuration:**
```yaml
# In deployment/statefulset spec
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

**Commands:**
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n names-app

# Verify resource configuration
kubectl describe pod <pod-name> -n names-app | grep -A 5 "Requests\|Limits"

```

---

#### Milestone 5.2: Horizontal Pod Autoscaling (Optional)
**Goal**: Automatically scale backend based on load

**Tasks:**
- [ ] Install metrics-server in k3s (if not already present)
- [ ] Create HorizontalPodAutoscaler for backend
- [ ] Configure CPU-based scaling thresholds
- [ ] Test autoscaling with load testing
- [ ] Document autoscaling behavior

**Deliverables:**
- `k8s/backend-hpa.yaml` - HorizontalPodAutoscaler manifest
- Metrics-server deployed and functional
- Verified autoscaling behavior

**Acceptance Criteria:**
- ✅ Metrics-server running and collecting pod metrics
- ✅ HPA configured for backend deployment
- ✅ Min replicas: 2, Max replicas: 5
- ✅ Scales up when CPU > 70%
- ✅ Scales down when load decreases
- ✅ `kubectl top pods` shows resource usage

**Example HPA:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: names-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

---

#### Milestone 5.3: Monitoring & Operational Tooling
**Goal**: Enable observability and operations

**Tasks:**
- [ ] Document kubectl commands for monitoring
- [ ] Create shell scripts for common operations
- [ ] Set up log viewing procedures
- [ ] Create health check monitoring guide
- [ ] Document backup and restore procedures

**Deliverables:**
- `docs/OPERATIONS.md` - Kubernetes operations guide
- Shell scripts for common tasks
- Monitoring and logging procedures

**Acceptance Criteria:**
- ✅ Can view logs from all pods
- ✅ Can monitor pod/node resource usage
- ✅ Can check pod health status
- ✅ Operations guide covers common scenarios
- ✅ Backup/restore procedure documented

**Monitoring Commands:**
```bash
# View pod logs
kubectl logs -f -l app=backend -n names-app
kubectl logs -f -l app=frontend -n names-app
kubectl logs -f postgres-0 -n names-app

# Monitor resources
kubectl top nodes
kubectl top pods -n names-app

# Check pod status
kubectl get pods -n names-app -o wide
kubectl describe pod <pod-name> -n names-app

# Watch for changes
kubectl get pods -n names-app --watch

# Check events
kubectl get events -n names-app --sort-by='.lastTimestamp'
```

---

## Risk Management

### High-Risk Items

#### Risk 1: PersistentVolume Binding Failure
**Impact**: High | **Probability**: Medium
**Description**: PersistentVolumeClaim for database doesn't bind to volume

**Mitigation:**
- k3s uses local-path-provisioner by default (automatic PV creation)
- Verify storage class exists: `kubectl get storageclass`
- Start with small PVC size (1Gi) to ensure availability
- Test PVC binding before deploying database
- Check node has sufficient disk space

**Contingency:**
- Manually create PersistentVolume if needed
- Use emptyDir for testing (data lost on pod restart)
- Check provisioner logs: `kubectl logs -n kube-system -l app=local-path-provisioner`
- Verify node local-path-provisioner is running

#### Risk 2: Image Pull Policy Issues
**Impact**: High | **Probability**: Medium
**Description**: k3s tries to pull images from registry instead of using local images

**Mitigation:**
- Set `imagePullPolicy: Never` in all Deployments/StatefulSets
- Import images to correct containerd namespace: `k8s.io`
- Use `crictl images` to verify images available
- Tag images without registry prefix (e.g., `names-backend:latest` not `docker.io/names-backend`)

**Contingency:**
- Re-import images with correct namespace
- Use `docker.io/library/postgres:15` for database (allows pull)
- Set up local registry if repeated deployments needed
- Check containerd configuration in k3s

#### Risk 3: Pod Scheduling Failures
**Impact**: High | **Probability**: Low
**Description**: Pods stuck in Pending state, won't schedule

**Mitigation:**
- Verify node(s) in Ready state: `kubectl get nodes`
- Check resource requests don't exceed node capacity
- Start with minimal resource requests
- Verify no taints preventing pod scheduling
- Check PVC binds successfully before pod starts

**Contingency:**
- Describe pod to see scheduling error: `kubectl describe pod <name>`
- Remove or reduce resource requests
- Check node conditions and logs
- Restart k3s if scheduling appears stuck

### Medium-Risk Items

#### Risk 4: Service DNS Resolution Not Working
**Impact**: Medium | **Probability**: Low
**Description**: Pods can't resolve service names (backend can't reach db-service)

**Mitigation:**
- k3s includes CoreDNS by default
- Verify CoreDNS pods running: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
- Use full service name format: `db-service.names-app.svc.cluster.local`
- Test DNS from pod: `kubectl exec -it <pod> -- nslookup db-service`

**Contingency:**
- Restart CoreDNS pods if not resolving
- Use ClusterIP directly as workaround
- Check network policy not blocking DNS (UDP 53)
- Verify service endpoints exist: `kubectl get endpoints -n names-app`

#### Risk 5: k3s Installation Issues on VM
**Impact**: Medium | **Probability**: Low
**Description**: k3s fails to install or start on Vagrant VM

**Mitigation:**
- Use official install script: `curl -sfL https://get.k3s.io | sh -`
- Ensure VM has sufficient resources (2GB+ RAM, 10GB+ disk)
- Check VM has internet connectivity
- Verify no conflicting processes on required ports (6443, 10250)

**Contingency:**
- Check k3s logs: `sudo journalctl -u k3s -f`
- Uninstall and reinstall: `/usr/local/bin/k3s-uninstall.sh`
- Use specific k3s version if latest has issues
- Provision VM with Docker instead and use kind/minikube

#### Risk 6: kubectl Connection Issues from Laptop
**Impact**: Medium | **Probability**: Low
**Description**: Can't connect to k3s cluster from laptop kubectl

**Mitigation:**
- Copy kubeconfig from VM: `/etc/rancher/k3s/k3s.yaml`
- Update server IP from 127.0.0.1 to VM IP (192.168.56.10)
- Set proper file permissions: `chmod 600 ~/.kube/config`
- Test connection: `kubectl cluster-info`

**Contingency:**
- Run kubectl commands from within VM
- Check k3s API server is listening: `sudo ss -tlnp | grep 6443`
- Verify firewall not blocking port 6443
- Use `vagrant ssh` and run commands inside VM

### Low-Risk Items

#### Risk 7: NodePort Not Accessible from Laptop
**Impact**: Low | **Probability**: Low
**Description**: Can't access frontend via NodePort

**Mitigation:**
- Verify service created with NodePort type
- Check NodePort is in valid range (30000-32767)
- Ensure VM port not blocked by firewall
- Test from within VM first: `curl localhost:<NodePort>`

**Contingency:**
- Use `kubectl port-forward` instead of NodePort
- SSH tunnel to VM and access locally
- Change Vagrantfile to forward NodePort explicitly
- Use LoadBalancer type (MetalLB) if available

#### Risk 8: Resource Exhaustion on Single-Node Cluster
**Impact**: Low | **Probability**: Medium
**Description**: VM runs out of resources with all pods running

**Mitigation:**
- Start with minimal replicas (1 for most workloads)
- Set resource limits to prevent over-allocation
- Monitor with `kubectl top nodes` and `kubectl top pods`
- Allocate 2-4GB RAM to k3s-server VM

**Contingency:**
- Increase VM resources in Vagrantfile
- Reduce backend replicas from 2 to 1
- Add agent node for additional capacity
- Use smaller base images to reduce memory footprint

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
- [ ] Create feature branch `k3s-orchestration`
- [ ] Verify current Docker Compose setup works
- [ ] Document current state in spec
- [ ] Review Vagrant and VirtualBox installation
- [ ] Install kubectl on laptop if not already installed

### Implementation Approach

#### Phase-by-Phase Rollout
Each phase must be completed and verified before moving to next phase:

1. **Phase 0**: Prerequisites and preparation (verify current state)
2. **Phase 1**: Set up k3s infrastructure (VM and kubectl access)
3. **Phase 2**: Create Kubernetes manifests (all k8s/*.yaml files)
4. **Phase 3**: Build and import images to k3s
5. **Phase 4**: Deploy and test (the critical phase)
6. **Phase 5**: Harden and optimize (optional enhancements)

#### Testing Strategy
- **After each milestone**: Run acceptance criteria tests
- **Before next phase**: Ensure previous phase fully working
- **Continuous**: Keep Docker Compose working for local dev/testing
- **End-to-end**: Full application test in Phase 4
- **Incremental**: Deploy resources one at a time, verify each

#### Rollback Plan

**If Phase 4 deployment fails:**
1. Delete all resources: `kubectl delete namespace names-app`
2. Fix issue identified in logs or describe output
3. Rebuild manifests if configuration changes needed
4. Reimport images if image issues found
5. Redeploy namespace and resources

**If critical issues found:**
1. Keep Docker Compose as working baseline
2. Fix k3s issues separately
3. Don't delete Compose files until k3s proven working
4. Can always fall back to Compose on laptop
5. k3s can be uninstalled cleanly: `/usr/local/bin/k3s-uninstall.sh`

**Git Strategy:**
```bash
# Work on feature branch
git checkout -b k3s-orchestration

# Commit after each milestone
git add -A
git commit -m "Phase X Milestone Y: Description"

# If need to rollback
git log  # Find last working commit
git checkout <commit-hash>
```

### Parallel Development
- **Keep Compose**: `docker-compose.yml` remains for local development
- **Add k3s**: `k8s/` directory for Kubernetes deployment
- **Both work**: Can switch between them as needed
- **No conflicts**: They use different deployment methods

---

## Success Criteria

### Phase 0: Prerequisites & Preparation
- [ ] ✅ Current application fully functional with Docker Compose
- [ ] ✅ All bug fixes verified (GET returns {names: []}, DELETE uses ID)
- [ ] ✅ kubectl installed on laptop
- [ ] ✅ Vagrant and VirtualBox functional
- [ ] ✅ Git branch `k3s-orchestration` created

### Phase 1: k3s Infrastructure
- [ ] ✅ k3s-server VM running and accessible
- [ ] ✅ k3s installed and running on VM
- [ ] ✅ `kubectl get nodes` shows k3s-server in Ready state
- [ ] ✅ kubectl on laptop can connect to k3s cluster
- [ ] ✅ `kubectl cluster-info` returns cluster information
- [ ] ✅ (Optional) k3s-agent VM joined to cluster

### Phase 2: Kubernetes Manifests
- [ ] ✅ `k8s/` directory created with all manifest files
- [ ] ✅ namespace.yaml defines `names-app` namespace
- [ ] ✅ configmap.yaml contains application configuration
- [ ] ✅ secret.yaml contains database credentials
- [ ] ✅ database-pvc.yaml defines persistent volume claim
- [ ] ✅ database-statefulset.yaml with PostgreSQL configuration
- [ ] ✅ database-service.yaml for ClusterIP access
- [ ] ✅ backend-deployment.yaml with 2 replicas
- [ ] ✅ backend-service.yaml for ClusterIP access
- [ ] ✅ frontend-deployment.yaml with 1 replica
- [ ] ✅ frontend-service.yaml with NodePort type
- [ ] ✅ All manifests use `imagePullPolicy: Never`

### Phase 3: Container Images
- [ ] ✅ Backend image built successfully
- [ ] ✅ Frontend image built successfully
- [ ] ✅ Images saved to tar archives
- [ ] ✅ Tar files transferred to k3s-server VM
- [ ] ✅ Images imported to containerd (k8s.io namespace)
- [ ] ✅ `crictl images` shows both images on k3s-server

### Phase 4: Deployment & Testing
- [ ] ✅ Namespace `names-app` created and Active
- [ ] ✅ ConfigMap and Secret applied successfully
- [ ] ✅ PVC `postgres-pvc` bound to PersistentVolume
- [ ] ✅ StatefulSet `postgres` shows 1/1 replicas ready
- [ ] ✅ Pod `postgres-0` in Running status
- [ ] ✅ Service `db-service` created (ClusterIP)
- [ ] ✅ Deployment `backend` shows 2/2 replicas ready
- [ ] ✅ Both backend pods in Running status
- [ ] ✅ Service `api-service` created (ClusterIP)
- [ ] ✅ Deployment `frontend` shows 1/1 replica ready
- [ ] ✅ Frontend pod in Running status
- [ ] ✅ Service `frontend-service` created (NodePort)
- [ ] ✅ All liveness probes passing
- [ ] ✅ All readiness probes passing
- [ ] ✅ Backend can reach database via `db-service`
- [ ] ✅ Frontend can reach backend via `api-service`
- [ ] ✅ Application accessible via http://<VM_IP>:<NodePort>
- [ ] ✅ Can add names successfully through web UI
- [ ] ✅ Can view names with timestamps
- [ ] ✅ Can delete names by ID
- [ ] ✅ **Data persists after database pod restart**
- [ ] ✅ No error events in `kubectl get events`

### Phase 5: Production Hardening (Optional)
- [ ] ✅ Resource requests and limits configured for all workloads
- [ ] ✅ HorizontalPodAutoscaler configured for backend (optional)
- [ ] ✅ Monitoring commands documented
- [ ] ✅ Operations guide created (docs/OPERATIONS.md)
- [ ] ✅ Backup/restore procedures documented

### Overall Project Success

#### Functional Requirements (MUST HAVE)
- [ ] ✅ Application runs on k3s Kubernetes cluster (not Compose)
- [ ] ✅ All components deployed as Kubernetes resources
- [ ] ✅ Database uses PersistentVolume for data storage
- [ ] ✅ Frontend accessible via NodePort
- [ ] ✅ Service discovery working (backend → db via ClusterIP)
- [ ] ✅ DB health probes: liveness and readiness passing
- [ ] ✅ API health probes: `/healthz` and `/api/health/db` passing
- [ ] ✅ All CRUD operations functional
- [ ] ✅ Docker Compose still works for local development
- [ ] ✅ Data persists across pod restarts

#### Quality Requirements (SHOULD HAVE)
- [ ] ✅ Clean separation: Compose for dev, k3s for production
- [ ] ✅ Documentation complete and accurate
- [ ] ✅ Deployment process documented
- [ ] ✅ Credentials stored in Kubernetes Secret
- [ ] ✅ Pods recover automatically on failure
- [ ] ✅ Logs accessible via kubectl
- [ ] ✅ Operations guide available

#### Performance Requirements (NICE TO HAVE)
- [ ] ✅ All pods start within 2 minutes
- [ ] ✅ API responses under 500ms
- [ ] ✅ Backend scaled to 2 replicas for high availability
- [ ] ✅ Resource limits prevent resource exhaustion
- [ ] ✅ HorizontalPodAutoscaler configured (optional)

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

1. **k3s Cluster Test**
   ```bash
   kubectl get nodes
   ```
   - ✅ Pass criteria: Shows k3s-server (and optional agent) in Ready state

2. **kubectl Connectivity Test**
   ```bash
   kubectl cluster-info
   kubectl version
   ```
   - ✅ Pass criteria: kubectl can communicate with k3s API server

3. **Storage Class Test**
   ```bash
   kubectl get storageclass
   ```
   - ✅ Pass criteria: local-path storage class exists and is default

### Deployment Testing (Phase 4)

1. **Pod Status Test**
   ```bash
   kubectl get pods -n names-app
   ```
   - ✅ Pass criteria: 
     - postgres-0: 1/1 Running
     - backend-xxx: 2/2 Running (2 replicas)
     - frontend-xxx: 1/1 Running

2. **Service Discovery Test**
   ```bash
   kubectl run test-pod --rm -i --tty --image=curlimages/curl -n names-app -- \
     curl http://db-service:5432
   ```
   - ✅ Pass criteria: Backend pods can reach database service by name

3. **Health Check Test**
   ```bash
   kubectl exec -it -n names-app deployment/backend -- curl http://localhost:5000/healthz
   kubectl exec -it -n names-app deployment/backend -- curl http://localhost:5000/api/health/db
   ```
   - ✅ Pass criteria:
     - `/healthz` returns 200 OK
     - `/api/health/db` returns healthy status

4. **Pod Logs Test**
   ```bash
   kubectl logs -l app=backend -n names-app --tail=20
   ```
   - ✅ Pass criteria: No error messages, successful DB connection logs

5. **PVC Binding Test**
   ```bash
   kubectl get pvc -n names-app
   ```
   - ✅ Pass criteria: postgres-pvc shows Bound status

### Functional Testing (Phase 4)
**Environment**: k3s deployment via browser at http://<VM_IP>:<NodePort>

1. **Get NodePort**
   ```bash
   kubectl get svc frontend-service -n names-app
   ```
   - Note the NodePort (e.g., 30080)
   - Open browser to http://192.168.56.10:30080

2. **Add Name via k3s**
   - Add name "Alice Smith"
   - ✅ Pass criteria: Name appears in list

3. **View Names via k3s**
   - Verify previously added names visible
   - Check timestamps display correctly
   - ✅ Pass criteria: All names with timestamps visible

4. **Delete Name via k3s**
   - Delete any name using delete button
   - ✅ Pass criteria: Name removed successfully

5. **Data Persistence Test**
   ```bash
   kubectl delete pod postgres-0 -n names-app
   kubectl wait --for=condition=ready pod/postgres-0 -n names-app --timeout=120s
   ```
   - Refresh browser
   - ✅ Pass criteria: Data still present after pod restart

6. **Backend Scaling Test**
   ```bash
   kubectl get pods -n names-app -l app=backend
   ```
   - ✅ Pass criteria: 2 backend pods running, requests load balanced

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
| Phase 0 | 1 day | 2-4h | None | Prerequisites verified |
| Phase 1 | 2-3 days | 6-8h | Phase 0 | k3s cluster ready |
| Phase 2 | 3-4 days | 12-15h | Phase 1 | All k8s manifests created |
| Phase 3 | 1-2 days | 4-6h | Phase 2 | Images imported to k3s |
| Phase 4 | 2-3 days | 10-12h | Phase 3 | App deployed & tested |
| Phase 5 | 2-3 days | 8-10h | Phase 4 | Production ready (optional) |
| **Total** | **11-16 days** | **42-55h** | Sequential | k3s deployment |

**Realistic Timeline**: 2-3 weeks part-time (15-20 hours/week)

---

## Deliverables Checklist

### Code Changes
- [x] `src/backend/main.py` - All bug fixes completed (✅ Done)
  - GET /api/names returns `{names: [...]}`
  - Health endpoints `/healthz` and `/api/health/db` working
  - DATABASE_URL and DB_URL dual support
- [x] `src/frontend/app.js` - All bug fixes completed (✅ Done)
  - Handles response objects properly
  - Delete uses ID parameter correctly
- [x] `src/backend/Dockerfile` - Backend container image (✅ Exists)
- [x] `src/frontend/Dockerfile` - Frontend container image (✅ Exists)

### Kubernetes Manifests (REQUIRED)
- [ ] **`k8s/`** - Directory for all Kubernetes manifests
- [ ] `k8s/namespace.yaml` - Namespace definition for `names-app`
- [ ] `k8s/configmap.yaml` - Application configuration (MAX_NAME_LENGTH, LOG_LEVEL, etc.)
- [ ] `k8s/secret.yaml` - Database credentials (POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB)
- [ ] `k8s/database-pvc.yaml` - PersistentVolumeClaim for PostgreSQL
- [ ] `k8s/database-statefulset.yaml` - PostgreSQL StatefulSet with health probes
- [ ] `k8s/database-service.yaml` - ClusterIP service for database (db-service:5432)
- [ ] `k8s/backend-deployment.yaml` - Flask backend Deployment (2 replicas, health probes)
- [ ] `k8s/backend-service.yaml` - ClusterIP service for API (api-service:5000)
- [ ] `k8s/frontend-deployment.yaml` - Nginx frontend Deployment (1 replica)
- [ ] `k8s/frontend-service.yaml` - NodePort service for external access
- [ ] `k8s/backend-hpa.yaml` - HorizontalPodAutoscaler (optional)

### Infrastructure Files
- [ ] `Vagrantfile` - Updated for k3s-server (and optional k3s-agent) VM
- [ ] `vagrant/install-k3s.sh` - k3s installation script (optional)
- [ ] `ops/deploy-k3s.sh` - Automated k3s deployment script (optional)

### Documentation
- [ ] `README.md` - Updated with k3s deployment instructions
- [ ] `docs/OPERATIONS.md` - Kubernetes operations and monitoring guide
- [ ] `docs/TROUBLESHOOTING.md` - Common k3s/kubectl issues and solutions
- [x] `spec/10-current-state-spec.md` - Updated (✅ Done)
- [x] `spec/20-target-spec.md` - Updated for k3s (✅ Done)
- [x] `spec/30-plan.md` - This document, updated for k3s (✅ Done)
- [ ] `spec/40-tasks.md` - Detailed task breakdown (To Do)

### Verification
- [ ] All acceptance tests pass
- [ ] Docker Compose still works for local dev
- [ ] k3s deployment fully functional
- [ ] All pods in Running state with passing health checks
- [ ] Data persists across pod restarts
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