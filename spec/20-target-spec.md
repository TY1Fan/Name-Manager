# Names Manager - Target State Specification

## Executive Summary

**Goal**: Refactor the Names Manager 3-tier application from **Docker Swarm** to **k3s (Lightweight Kubernetes)** orchestration with cloud-native deployment patterns.

**Target Architecture**:
- **k3s Cluster**: Distributed Kubernetes cluster with control plane and worker nodes
- **Pod Distribution**: Frontend, Backend, and Database pods managed by Kubernetes
- **Orchestration**: k3s with native Kubernetes resources (Deployments, Services, PersistentVolumes)
- **Cloud-Native Features**: ConfigMaps, Secrets, auto-scaling, rolling updates, self-healing

**Status**: This specification defines the target state for migrating from Docker Swarm to k3s/Kubernetes orchestration, providing production-grade container orchestration with Kubernetes ecosystem benefits.

## Overview

This document outlines the migration from the current Docker Swarm orchestrated deployment to a **k3s (Lightweight Kubernetes)** cloud-native deployment. The application will be refactored to leverage Kubernetes-native resources including Deployments, Services, ConfigMaps, Secrets, and PersistentVolumeClaims, providing production-grade orchestration with declarative configuration management.

## Architecture Changes

### Current Architecture (Docker Swarm)
```
VM1: Swarm Manager                    VM2: Swarm Worker
├── Frontend Service (Nginx) :80      └── Database Service (PostgreSQL)
├── Backend Service (Flask×2)             └── Docker Volume: db_data
└── Overlay Network: appnet               └── Placement Constraint
    └── Service Discovery                 └── Swarm Secrets
```

### Target Architecture (k3s/Kubernetes)
```
k3s Cluster
├── Control Plane Node (Server)
│   ├── k3s API Server
│   ├── Controller Manager
│   ├── Scheduler
│   └── etcd (embedded)
│
├── Worker Nodes
│   ├── Frontend Deployment
│   │   └── Pod: nginx container
│   │       └── Service: LoadBalancer/NodePort
│   ├── Backend Deployment
│   │   └── Pods: flask containers (2 replicas)
│   │       └── Service: ClusterIP
│   │       └── HorizontalPodAutoscaler (optional)
│   └── Database StatefulSet
│       └── Pod: postgresql container
│           └── Service: ClusterIP (headless)
│           └── PersistentVolumeClaim
│
└── Kubernetes Resources
    ├── Namespace: names-app
    ├── ConfigMap: app-config
    ├── Secret: db-credentials
    ├── PersistentVolume: postgres-pv
    ├── PersistentVolumeClaim: postgres-pvc
    ├── Ingress: names-ingress (optional)
    └── NetworkPolicy (optional)
```

## Infrastructure Requirements

### k3s Cluster Setup

#### Control Plane Node (k3s Server)
**Purpose**: Kubernetes Control Plane + Application Workloads

**Specifications**:
- **OS**: Ubuntu 22.04 LTS or similar (k3s supports multiple OS)
- **Memory**: 2 GB RAM minimum (4 GB recommended)
- **CPU**: 2 cores minimum
- **Disk**: 30 GB
- **Network**: Private network with static IP
- **Role**: k3s Server (Control Plane)

**Components Running**:
- k3s Server (API Server, Scheduler, Controller Manager, embedded etcd)
- CoreDNS (Service Discovery)
- Traefik Ingress Controller (default, can be disabled)
- Local Path Provisioner (dynamic PV provisioning)
- Service Load Balancer (Klipper-lb)

#### Worker Nodes (Optional - k3s Agent)
**Purpose**: Additional compute capacity for workloads

**Specifications**:
- **OS**: Ubuntu 22.04 LTS or similar
- **Memory**: 1 GB RAM minimum (2 GB recommended)
- **CPU**: 1 core minimum
- **Disk**: 20 GB
- **Network**: Private network with static IP
- **Role**: k3s Agent (Worker Node)

**Components Running**:
- k3s Agent (kubelet, kube-proxy, containerd)
- Application pods (scheduled by control plane)

**Note**: k3s can run as a single-node cluster with server also running workloads, or as multi-node cluster with dedicated workers.

### Vagrant Configuration
```ruby
# Vagrantfile target structure for k3s cluster
Vagrant.configure("2") do |config|
  # k3s Server (Control Plane)
  config.vm.define "k3s-server" do |server|
    server.vm.box = "ubuntu/jammy64"
    server.vm.hostname = "k3s-server"
    server.vm.network "private_network", ip: "192.168.56.10"
    server.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"  # More RAM for control plane
      vb.cpus = 2
    end
    # Install k3s server
    server.vm.provision "shell", inline: <<-SHELL
      curl -sfL https://get.k3s.io | sh -
      # Make kubeconfig accessible
      sudo chmod 644 /etc/rancher/k3s/k3s.yaml
    SHELL
  end
  
  # k3s Agent (Worker Node) - Optional
  config.vm.define "k3s-agent" do |agent|
    agent.vm.box = "ubuntu/jammy64"
    agent.vm.hostname = "k3s-agent"
    agent.vm.network "private_network", ip: "192.168.56.11"
    agent.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
    end
    # Install k3s agent (join script to be added after server setup)
  end
end
```

## k3s Configuration

### Cluster Initialization

#### Server Node Setup
```bash
# On k3s-server VM
curl -sfL https://get.k3s.io | sh -

# Verify installation
sudo k3s kubectl get nodes
# Should show:
# NAME         STATUS   ROLES                  AGE   VERSION
# k3s-server   Ready    control-plane,master   30s   v1.28.x+k3s1

# Get node token for agents (workers)
sudo cat /var/lib/rancher/k3s/server/node-token
# Save this token: K10xxx...::server:xxx
```

#### Agent Node Setup (Optional)
```bash
# On k3s-agent VM
K3S_URL=https://192.168.56.10:6443
K3S_TOKEN=<NODE_TOKEN_FROM_SERVER>

curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -

# Verify on server
vagrant ssh k3s-server
sudo k3s kubectl get nodes
# Should show both nodes
```

#### kubectl Configuration
```bash
# Copy kubeconfig from server to laptop
vagrant ssh k3s-server -- sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/k3s-config

# Edit the config to use VM IP
sed -i '' 's/127.0.0.1/192.168.56.10/g' ~/.kube/k3s-config

# Set KUBECONFIG
export KUBECONFIG=~/.kube/k3s-config

# Test access from laptop
kubectl get nodes
```

### Network Configuration

#### Kubernetes Networking
k3s includes **Flannel** as default CNI (Container Network Interface) plugin:

**Features**:
- Pod-to-pod communication across nodes
- Service discovery via CoreDNS
- Network policies support (with additional configuration)
- Built-in load balancing via kube-proxy

#### Service Types
- **ClusterIP**: Internal cluster communication (default)
- **NodePort**: Expose service on each node's IP at a static port
- **LoadBalancer**: Uses k3s ServiceLB (Klipper) for external access

### Kubernetes Manifests Structure

#### Namespace Definition
```yaml
# k8s/namespace.yaml
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: names-app
```

#### ConfigMap for Application Configuration
```yaml
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: names-app
data:
  MAX_NAME_LENGTH: "50"
  SERVER_HOST: "0.0.0.0"
  SERVER_PORT: "8000"
  LOG_LEVEL: "INFO"
  DB_ECHO: "false"
```

#### Secret for Database Credentials
```yaml
# k8s/secret.yaml
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
  DATABASE_URL: postgresql+psycopg2://names_user:names_pass@db:5432/namesdb
```

#### PersistentVolume and PersistentVolumeClaim
```yaml
# k8s/postgres-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /var/lib/postgres-data
  storageClassName: local-path
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: names-app
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-path
```

#### Database StatefulSet
```yaml
# k8s/database.yaml
apiVersion: v1
kind: Service
metadata:
  name: db
  namespace: names-app
spec:
  clusterIP: None  # Headless service for StatefulSet
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: names-app
spec:
  serviceName: db
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
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: local-path
      resources:
        requests:
          storage: 5Gi
```

#### Backend Deployment
```yaml
# k8s/backend.yaml
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: names-app
spec:
  selector:
    app: backend
  ports:
    - port: 8000
      targetPort: 8000
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: names-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: names-backend:latest
        imagePullPolicy: Never  # Use local image
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: DATABASE_URL
        envFrom:
        - configMapRef:
            name: app-config
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
```

#### Frontend Deployment
```yaml
# k8s/frontend.yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: names-app
spec:
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080  # Expose on node port 30080
  type: NodePort
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: names-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: names-frontend:latest
        imagePullPolicy: Never  # Use local image
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 5
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

### Deployment Strategy

#### Pod Scheduling
Kubernetes scheduler automatically distributes pods across available nodes based on:
- Resource requests and limits
- Node affinity/anti-affinity rules (optional)
- Taints and tolerations (optional)
- Pod topology spread constraints (optional)

**Default Behavior**:
- Pods scheduled on any available node with sufficient resources
- StatefulSet pods maintain stable identity and storage
- Deployment pods are interchangeable

#### Node Affinity (Optional)
```yaml
# Example: Schedule database on specific node
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-role.kubernetes.io/worker
            operator: In
            values:
            - "true"
```

#### Replicas and Scaling
- **Frontend**: 1 replica (can scale: `kubectl scale deployment frontend --replicas=3`)
- **Backend**: 2 replicas (horizontal scaling via Deployment)
- **Database**: 1 replica (StatefulSet for stable storage)

#### Horizontal Pod Autoscaling (Optional)
```yaml
# k8s/hpa.yaml
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

## Application Code Changes

### No Code Changes Required

The application code is already functional with all critical bugs fixed in the previous swarm-orchestration branch:
- ✅ Backend returns proper JSON format: `{"names": [...]}`
- ✅ Frontend properly handles and displays name objects with timestamps
- ✅ Delete functionality uses integer IDs correctly
- ✅ Health check endpoints support Kubernetes probes (`/healthz`)

### Environment Variable Updates

The backend already supports both `DATABASE_URL` and `DB_URL` environment variables, making it compatible with Kubernetes ConfigMaps and Secrets without modification.

**Backend Configuration** (`main.py` lines 11-17):
```python
DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    os.environ.get(
        "DB_URL",
        "postgresql+psycopg2://names_user:names_pass@db:5432/namesdb"
    )
)
```

This dual support means the application will work seamlessly with Kubernetes Secrets.

### Container Image Building

#### Build Script for k3s
```bash
#!/bin/bash
# build-images.sh - Build and import images for k3s

VERSION=${1:-latest}

echo "Building container images with version: $VERSION"

# Build backend image
docker build -t names-backend:${VERSION} ./backend
docker tag names-backend:${VERSION} names-backend:latest

# Build frontend image
docker build -t names-frontend:${VERSION} ./frontend
docker tag names-frontend:${VERSION} names-frontend:latest

echo "Images built successfully"
docker images | grep names

echo "Importing images to k3s..."
# Import to k3s containerd
docker save names-backend:latest | sudo k3s ctr images import -
docker save names-frontend:latest | sudo k3s ctr images import -

echo "Verifying images in k3s..."
sudo k3s ctr images ls | grep names
```

#### Image Distribution to Nodes

**Option 1: Import on each node** (Recommended for Vagrant)
```bash
# Build on laptop
cd src/
./build-images.sh

# Import to k3s server
docker save names-backend:latest names-frontend:latest | \
  vagrant ssh k3s-server -- sudo k3s ctr images import -

# Import to k3s agent (if using multi-node)
docker save names-backend:latest names-frontend:latest | \
  vagrant ssh k3s-agent -- sudo k3s ctr images import -
```

**Option 2: Use private registry** (Recommended for production)
```bash
# Run registry as k3s deployment
kubectl create deployment registry --image=registry:2 --port=5000 -n kube-system
kubectl expose deployment registry --type=NodePort --port=5000 -n kube-system

# Push images
docker tag names-backend:latest 192.168.56.10:30500/names-backend:latest
docker push 192.168.56.10:30500/names-backend:latest

# Update manifests to use registry
# image: 192.168.56.10:30500/names-backend:latest
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

### Production Workflow (k3s/Kubernetes)

#### Initial Deployment
```bash
# 1. Start VMs and install k3s (one-time)
vagrant up k3s-server

# Optional: Add worker node
vagrant up k3s-agent
# Get node token from server and join

# 2. Configure kubectl on laptop (one-time)
vagrant ssh k3s-server -- sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/k3s-config
sed -i '' 's/127.0.0.1/192.168.56.10/g' ~/.kube/k3s-config
export KUBECONFIG=~/.kube/k3s-config

# 3. Verify cluster
kubectl get nodes
kubectl cluster-info

# 4. Build and import images
cd src/
./build-images.sh latest
docker save names-backend:latest names-frontend:latest | \
  vagrant ssh k3s-server -- sudo k3s ctr images import -

# 5. Create namespace
kubectl apply -f k8s/namespace.yaml

# 6. Create ConfigMap and Secret
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml

# 7. Deploy database (StatefulSet)
kubectl apply -f k8s/database.yaml

# 8. Wait for database to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n names-app --timeout=60s

# 9. Deploy backend
kubectl apply -f k8s/backend.yaml

# 10. Deploy frontend
kubectl apply -f k8s/frontend.yaml

# 11. Verify deployment
kubectl get all -n names-app
kubectl get pods -n names-app -w
```

#### Quick Deployment Script
```bash
#!/bin/bash
# deploy-k3s.sh

# Apply all manifests in order
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/database.yaml

# Wait for database
echo "Waiting for database to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n names-app --timeout=120s

# Deploy application
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml

# Show status
echo "Deployment status:"
kubectl get pods -n names-app
echo "Access application at: http://192.168.56.10:30080"
```

#### Updates and Rollbacks
```bash
# Update application
./build-images.sh v1.0.1
docker save names-backend:latest | vagrant ssh k3s-server -- sudo k3s ctr images import -

# Update deployment (triggers rolling update)
kubectl rollout restart deployment/backend -n names-app
kubectl rollout restart deployment/frontend -n names-app

# Check rollout status
kubectl rollout status deployment/backend -n names-app

# View rollout history
kubectl rollout history deployment/backend -n names-app

# Rollback to previous version
kubectl rollout undo deployment/backend -n names-app

# Rollback to specific revision
kubectl rollout undo deployment/backend --to-revision=2 -n names-app

# Scale deployments
kubectl scale deployment backend --replicas=3 -n names-app
```

#### Resource Management
```bash
# View all resources
kubectl get all -n names-app

# View pods with more detail
kubectl get pods -n names-app -o wide

# View services
kubectl get svc -n names-app

# View deployments
kubectl get deployments -n names-app

# View statefulsets
kubectl get statefulsets -n names-app

# View persistent volumes
kubectl get pv,pvc -n names-app

# Describe resources
kubectl describe pod <pod-name> -n names-app
kubectl describe deployment backend -n names-app

# View logs
kubectl logs -f deployment/backend -n names-app
kubectl logs -f statefulset/postgres -n names-app

# Execute commands in pod
kubectl exec -it deployment/backend -n names-app -- /bin/bash

# Delete resources
kubectl delete -f k8s/frontend.yaml
kubectl delete -f k8s/backend.yaml
kubectl delete -f k8s/database.yaml

# Delete entire namespace (removes all resources)
kubectl delete namespace names-app
```

## Secrets Management

### Kubernetes Secrets
Kubernetes Secrets are used to store sensitive data like database credentials:

#### Creating Secrets Declaratively
```yaml
# k8s/secret.yaml (already shown above)
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: names-app
type: Opaque
stringData:
  POSTGRES_USER: names_user
  POSTGRES_PASSWORD: names_pass  # Change for production
  POSTGRES_DB: namesdb
  DATABASE_URL: postgresql+psycopg2://names_user:names_pass@db:5432/namesdb
```

#### Creating Secrets Imperatively
```bash
# Create secret from literals
kubectl create secret generic db-credentials \
  --from-literal=POSTGRES_USER=names_user \
  --from-literal=POSTGRES_PASSWORD=secure_password_here \
  --from-literal=POSTGRES_DB=namesdb \
  --from-literal=DATABASE_URL=postgresql+psycopg2://names_user:secure_password_here@db:5432/namesdb \
  -n names-app

# Create secret from file
echo -n 'names_user' > ./username
echo -n 'secure_password' > ./password
kubectl create secret generic db-credentials \
  --from-file=POSTGRES_USER=./username \
  --from-file=POSTGRES_PASSWORD=./password \
  -n names-app

# View secrets (values are base64 encoded)
kubectl get secrets -n names-app
kubectl describe secret db-credentials -n names-app

# Decode secret value
kubectl get secret db-credentials -n names-app -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
```

#### Using Secrets in Sealed Secrets (Production)
For production, consider using **Sealed Secrets** to encrypt secrets in Git:

```bash
# Install sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Create sealed secret
kubeseal < secret.yaml > sealed-secret.yaml

# Commit sealed-secret.yaml to Git (safe to commit)
# Controller will decrypt to regular secret in cluster
```

## Monitoring and Health Checks

### Pod Health Monitoring
```bash
# Check pod status
kubectl get pods -n names-app
kubectl get pods -n names-app -o wide

# Watch pod status in real-time
kubectl get pods -n names-app -w

# Check pod events
kubectl get events -n names-app --sort-by='.lastTimestamp'

# Describe pod for detailed info
kubectl describe pod <pod-name> -n names-app

# Check pod logs
kubectl logs -f deployment/backend -n names-app
kubectl logs --tail=50 deployment/frontend -n names-app
kubectl logs statefulset/postgres -n names-app

# Check logs from previous container (if pod crashed)
kubectl logs <pod-name> -n names-app --previous
```

### Kubernetes Probes
The manifests include liveness and readiness probes:

**Liveness Probes**: Restarts unhealthy pods
- Backend: `GET /healthz` every 10s
- Frontend: `GET /` every 10s
- Database: `pg_isready` command every 10s

**Readiness Probes**: Removes unhealthy pods from service endpoints
- Backend: `GET /healthz` every 5s
- Frontend: `GET /` every 5s
- Database: `pg_isready` command every 5s

### Application Health Endpoints
```bash
# Test health endpoints via NodePort
curl http://192.168.56.10:30080/api/health
curl http://192.168.56.10:30080/api/health/db

# Test from within cluster
kubectl run curl --image=curlimages/curl -i --rm --restart=Never -n names-app -- \
  curl http://api:8000/api/health

# Port-forward for local testing
kubectl port-forward -n names-app svc/web 8080:80
# Then access: http://localhost:8080
```

### Metrics and Monitoring (Optional)
For production monitoring, install **Prometheus** and **Grafana**:

```bash
# Install monitoring stack (Helm recommended)
kubectl create namespace monitoring

# Or use k3s metrics-server (included)
kubectl top nodes
kubectl top pods -n names-app
```

## Network Configuration

### Kubernetes Networking Features
- **Service Discovery**: Pods can reach each other by service name via CoreDNS (e.g., `db.names-app.svc.cluster.local` or simply `db`)
- **Load Balancing**: kube-proxy provides built-in load balancing across pod replicas
- **Network Policies**: Control traffic flow between pods (requires CNI plugin support)
- **Multi-host**: Flannel CNI enables pod-to-pod communication across nodes

### Service Types and Access

#### ClusterIP (Internal)
```bash
# Backend and Database use ClusterIP (internal only)
# Accessible only within cluster at: api:8000, db:5432
```

#### NodePort (External Access)
```bash
# Frontend uses NodePort for external access
# Accessible at any node IP on port 30080

# Access from laptop browser
http://192.168.56.10:30080/

# If using multiple nodes, any node IP works:
http://192.168.56.10:30080/  # server node
http://192.168.56.11:30080/  # agent node (if exists)
```

#### LoadBalancer (Cloud/k3s ServiceLB)
k3s includes ServiceLB (Klipper) for LoadBalancer type services:

```yaml
# Alternative: Use LoadBalancer instead of NodePort
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 80
```

### Port Forwarding for Testing
```bash
# Forward service port to laptop
kubectl port-forward -n names-app svc/web 8080:80

# Access at http://localhost:8080

# Forward pod port
kubectl port-forward -n names-app deployment/backend 8000:8000
```

### Ingress Controller (Optional)
k3s includes Traefik by default for Ingress resources:

```yaml
# k8s/ingress.yaml (optional)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: names-ingress
  namespace: names-app
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
  - host: names.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
```

## Backup and Recovery

### Database Backup Strategy

#### Manual Backup
```bash
# Backup database from running pod
POD_NAME=$(kubectl get pod -n names-app -l app=postgres -o jsonpath='{.items[0].metadata.name}')

kubectl exec $POD_NAME -n names-app -- \
  pg_dump -U names_user namesdb > backup_$(date +%Y%m%d).sql

# Copy backup file from pod
kubectl cp names-app/$POD_NAME:/tmp/backup.sql ./backups/backup_$(date +%Y%m%d).sql
```

#### Automated Backup with CronJob
```yaml
# k8s/backup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: names-app
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:15
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: POSTGRES_PASSWORD
            command:
            - /bin/sh
            - -c
            - |
              pg_dump -h db -U names_user namesdb > /backup/backup_$(date +%Y%m%d).sql
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup-storage
            hostPath:
              path: /var/lib/postgres-backups
```

### Disaster Recovery

#### Restore from Backup
```bash
# Restore database from backup file
POD_NAME=$(kubectl get pod -n names-app -l app=postgres -o jsonpath='{.items[0].metadata.name}')

cat backup_20251104.sql | kubectl exec -i $POD_NAME -n names-app -- \
  psql -U names_user namesdb

# Or copy file to pod first
kubectl cp ./backups/backup_20251104.sql names-app/$POD_NAME:/tmp/backup.sql

kubectl exec $POD_NAME -n names-app -- \
  psql -U names_user namesdb < /tmp/backup.sql
```

#### Volume Snapshots (Cloud Providers)
For cloud environments, use VolumeSnapshots:

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: postgres-snapshot
  namespace: names-app
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: postgres-pvc
```

## Project Structure Changes

### Updated Directory Structure
```
HW_3/
├── Vagrantfile                      # UPDATED: k3s VM definitions
├── src/
│   ├── docker-compose.yml           # KEEP: Local development
│   ├── build-images.sh              # UPDATED: k3s image import
│   ├── backend/
│   │   ├── Dockerfile
│   │   ├── main.py                  # NO CHANGES (already fixed)
│   │   ├── requirements.txt
│   │   └── tests/
│   ├── frontend/
│   │   ├── Dockerfile
│   │   ├── app.js                   # NO CHANGES (already fixed)
│   │   ├── index.html
│   │   └── nginx.conf
│   └── db/
│       └── init.sql
├── k8s/                             # NEW: Kubernetes manifests
│   ├── namespace.yaml               # NEW: Namespace definition
│   ├── configmap.yaml               # NEW: Application configuration
│   ├── secret.yaml                  # NEW: Database credentials
│   ├── database.yaml                # NEW: PostgreSQL StatefulSet
│   ├── backend.yaml                 # NEW: Backend Deployment
│   ├── frontend.yaml                # NEW: Frontend Deployment
│   ├── hpa.yaml                     # NEW: HorizontalPodAutoscaler (optional)
│   ├── ingress.yaml                 # NEW: Ingress resource (optional)
│   └── backup-cronjob.yaml          # NEW: Backup CronJob (optional)
├── ops/
│   ├── deploy-k3s.sh                # NEW: k3s deployment script
│   ├── cleanup-k3s.sh               # NEW: k3s cleanup script
│   └── validate-k3s.sh              # NEW: k3s validation script
├── swarm/                           # KEEP: Legacy Swarm configs
│   └── stack.yaml                   # KEEP: For reference/rollback
├── spec/
│   ├── 10-current-state-spec.md     # UPDATED
│   ├── 20-target-spec.md            # UPDATED (this file)
│   ├── 30-plan.md                   # TO BE UPDATED
│   └── 40-tasks.md                  # TO BE UPDATED
└── README.md                        # TO BE UPDATED
```

## Optional Enhancements

### Kubernetes Dashboard
```bash
# Install Kubernetes Dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create admin service account
kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard
kubectl create clusterrolebinding dashboard-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:dashboard-admin

# Get access token
kubectl create token dashboard-admin -n kubernetes-dashboard

# Port-forward dashboard
kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:443

# Access at: https://localhost:8443
```

### Helm Package Manager
```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Create Helm chart for application
helm create names-app

# Package and deploy with Helm
helm install names-app ./names-app-chart -n names-app
```

### GitOps with ArgoCD (Optional)
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Deploy application via GitOps
# ArgoCD will monitor Git repo and auto-deploy changes
```

### Prometheus & Grafana Monitoring
```bash
# Install kube-prometheus-stack (Helm)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Access Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# Default: admin/prom-operator
```

## Success Criteria

### Deployment Success Metrics
- ✅ k3s cluster initialized with control plane (server) node
- ✅ Optional: Worker node joined to cluster
- ✅ kubectl configured and accessible from laptop
- ✅ All Kubernetes manifests applied successfully
- ✅ All pods in Running state
- ✅ Services accessible via NodePort
- ✅ Application accessible from laptop browser
- ✅ Persistent volumes bound and functional
- ✅ Rolling updates work without downtime
- ✅ Docker Compose still works for local development

### Functional Requirements
- ✅ Application already functional (no code changes needed)
- ✅ Names can be added successfully via web UI
- ✅ Names list displays correctly with timestamps
- ✅ Names can be deleted by ID
- ✅ Health checks pass (liveness/readiness probes)
- ✅ Database data persists across pod restarts
- ✅ ConfigMaps and Secrets properly injected
- ✅ Service discovery works (pods can reach each other by service name)

### Kubernetes-Specific Features
- ✅ Deployments manage pod lifecycle
- ✅ StatefulSet manages database with stable storage
- ✅ Services provide stable endpoints for pod communication
- ✅ ConfigMap externalizes configuration
- ✅ Secret securely stores credentials
- ✅ PersistentVolumeClaim provides persistent storage
- ✅ Liveness probes restart unhealthy pods
- ✅ Readiness probes control traffic routing
- ✅ Rolling updates with zero downtime
- ✅ Rollback capability for failed deployments

### Performance Targets
- **Cluster Startup**: < 60 seconds for k3s installation
- **Application Deployment**: < 90 seconds for all pods to be Ready
- **Response Time**: < 500ms for API calls
- **Pod Recovery**: < 30 seconds for automatic pod restart
- **Rolling Update**: < 60 seconds with zero downtime

### Migration Path
- ✅ Swarm deployment remains functional (rollback option)
- ✅ Can run both Swarm and k3s deployments side-by-side
- ✅ Image builds work for both platforms
- ✅ Same application code works on both platforms
- ✅ Clear migration documentation

### Documentation Requirements
- ✅ Updated current state spec (swarm-orchestration branch)
- ✅ Target state spec with k3s architecture (this document)
- ✅ Migration plan with step-by-step instructions
- ✅ Task breakdown for implementation
- ✅ README with k3s deployment instructions
- ✅ Kubernetes manifests with comments
- ✅ Troubleshooting guide for common issues

## Benefits of k3s Over Docker Swarm

### Why Migrate to k3s/Kubernetes?

1. **Industry Standard**: Kubernetes is the de facto standard for container orchestration
2. **Ecosystem**: Vast ecosystem of tools (Helm, ArgoCD, Prometheus, etc.)
3. **Declarative Configuration**: GitOps-friendly manifest-based deployment
4. **Advanced Features**: HPA, Network Policies, RBAC, Custom Resources
5. **Cloud Portability**: Easy migration to managed Kubernetes (EKS, GKE, AKS)
6. **Better Resource Management**: Fine-grained resource requests/limits
7. **Stateful Workloads**: StatefulSets for databases with stable identities
8. **Lightweight**: k3s is optimized for edge/IoT with smaller footprint than full K8s
9. **Active Development**: Kubernetes has stronger community and vendor support
10. **Career Skills**: Kubernetes knowledge is highly valued in the industry

### k3s Specific Advantages
- **Single Binary**: Easy to install and upgrade
- **Low Resource**: Runs on 512MB RAM (suitable for edge devices)
- **Batteries Included**: Comes with Traefik, ServiceLB, Local Path Provisioner
- **Production Ready**: CNCF certified Kubernetes distribution
- **Edge Optimized**: Perfect for edge computing and IoT deployments

This target specification defines the complete migration from Docker Swarm to k3s/Kubernetes orchestration, providing a cloud-native foundation for the Names Manager application.

**Document Version**: 2.0  
**Last Updated**: November 4, 2025  
**Branch**: k3s-orchestration
