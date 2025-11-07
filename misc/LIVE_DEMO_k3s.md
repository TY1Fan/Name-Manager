# Live Demo Guide - Names Manager k3s

This guide provides step-by-step instructions for demonstrating the k3s deployment of the Names Manager application.

---

## Prerequisites

Before starting the demo, ensure:
- VMs are running: `vagrant status`
- k3s cluster is ready
- Application is deployed

**Quick Setup** (if needed):
```bash
vagrant up
vagrant status
./ops/deploy-k3s.sh
kubectl cluster-info
```

---

## Demo Steps

### 1. Show k3s Cluster with Multiple Nodes

**Demonstrate that the k3s cluster has 2 nodes (control-plane + worker)**

```bash
kubectl get nodes
```

**Expected Output:**
```
NAME         STATUS   ROLES                  AGE   VERSION
k3s-server   Ready    control-plane,master   19h   v1.33.5+k3s1
k3s-agent    Ready    <none>                 7h    v1.33.5+k3s1
```

**Show detailed node information:**
```bash
kubectl get nodes -o wide
```

**Key Points:**
- ✅ k3s-server has `control-plane,master` roles
- ✅ k3s-agent is a worker node
- ✅ Both nodes are `Ready`
- ✅ Running k3s v1.33.5+k3s1

---

### 2. Show Database Pod on Specific Node Only

**Demonstrate DB placement constraint working with nodeSelector**

```bash
kubectl get pods -n names-app -o wide | grep postgres
```

**Expected Output:**
```
NAME         READY   STATUS    RESTARTS   AGE   IP           NODE
postgres-0   1/1     Running   0          70m   10.42.0.28   k3s-server
```

**Show the nodeSelector constraint:**
```bash
kubectl get statefulset postgres -n names-app -o jsonpath='{.spec.template.spec.nodeSelector}' | jq
```

**Expected Output:**
```json
{
  "kubernetes.io/hostname": "k3s-server"
}
```

**Or describe the pod to see node selector:**
```bash
kubectl describe pod postgres-0 -n names-app | grep -A 2 "Node-Selectors"
```

**Expected Output:**
```
Node-Selectors:              kubernetes.io/hostname=k3s-server
```

**Key Points:**
- ✅ Database runs on `k3s-server` only
- ✅ NOT scheduled on k3s-agent
- ✅ nodeSelector constraint enforced
- ✅ Ensures PVC locality (local-path storage)

---

### 3. Access Web Application & Show Load Balancing

**Demonstrate web accessibility and load balancing across backend replicas**

#### 3a. Access the Web Interface

Open in browser or use curl:
```bash
curl -s http://localhost:30080/ | grep -o '<title>.*</title>'
```

**Expected Output:**
```
<title>Names Manager</title>
```

**In Browser:** Navigate to `http://localhost:30080`

**Key Points:**
- ✅ Web interface loads successfully via NodePort 30080
- ✅ Shows form to add names
- ✅ Displays list of existing names

#### 3b. Show Load Balancing Across Backend Replicas

**Check backend deployment has 2 replicas:**
```bash
kubectl get deployment backend -n names-app
```

**Expected Output:**
```
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
backend   2/2     2            2           113m
```

**Show both backend pods:**
```bash
kubectl get pods -n names-app -l app=backend -o wide
```

**Expected Output:**
```
NAME                       READY   STATUS    RESTARTS   AGE    IP           NODE
backend-68687c58d7-4lh5q   1/1     Running   5          114m   10.42.0.22   k3s-server
backend-68687c58d7-vtxhg   1/1     Running   5          114m   10.42.0.23   k3s-server
```

**Test load balancing by making multiple requests:**
```bash
for i in {1..6}; do
  echo "Request $i:"
  POD=$(kubectl exec -n names-app deployment/backend -- hostname)
  echo "  Handled by: $POD"
done
```

**Alternative - Watch logs from both pods:**
```bash
# In one terminal
kubectl logs -n names-app -l app=backend --tail=0 -f
# In another terminal, make requests
curl http://localhost:30080/api/names
```

**Key Points:**
- ✅ 2/2 backend replicas running
- ✅ Service load balances requests across pods
- ✅ Both pods handle traffic via ClusterIP service

---

### 4. Data Persistence Test

**Demonstrate data persists across database pod restart/deletion**

#### 4a. Insert Test Data

**Add a name via web interface or API:**
```bash
curl -X POST http://localhost:30080/api/names \
  -H "Content-Type: application/json" \
  -d '{"name":"k3s Demo Persistence Test"}'
```

**Expected Output:**
```json
{"id":8,"name":"k3s Demo Persistence Test"}
```

**Verify data exists:**
```bash
curl -s http://localhost:30080/api/names | jq '.names[] | select(.name=="k3s Demo Persistence Test")'
```

**Expected Output:**
```json
{
  "created_at": "2025-11-05T...",
  "id": 8,
  "name": "k3s Demo Persistence Test"
}
```

#### 4b. Restart Database Pod

**Delete the database pod (StatefulSet will recreate it):**
```bash
kubectl delete pod postgres-0 -n names-app
```

**Watch pod recreation:**
```bash
kubectl get pods -n names-app -w | grep postgres
```

**Wait for pod to be ready:**
```bash
kubectl wait --for=condition=ready pod/postgres-0 -n names-app --timeout=120s
```

**Expected Output:**
```
pod/postgres-0 condition met
```

#### 4c. Verify Data Persisted

**Check that data still exists after pod restart:**
```bash
curl -s http://localhost:30080/api/names | jq '.names[] | select(.name=="k3s Demo Persistence Test")'
```

**Expected Output:**
```json
{
  "created_at": "2025-11-05T...",
  "id": 8,
  "name": "k3s Demo Persistence Test"
}
```

**Show PersistentVolume and PVC:**
```bash
kubectl get pv,pvc -n names-app
```

**Expected Output:**
```
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM
persistentvolume/pvc-95864012-d138...     1Gi        RWO            Delete           Bound    names-app/postgres-pvc

NAME                                 STATUS   VOLUME                                     CAPACITY
persistentvolumeclaim/postgres-pvc   Bound    pvc-95864012-d138-470c-b4ba-546dff4d78d3   1Gi
```

**Show storage location on k3s-server:**
```bash
vagrant ssh k3s-server -c "sudo du -sh /var/lib/rancher/k3s/storage/pvc-*_names-app_postgres-pvc"
```

**Expected Output:**
```
47M     /var/lib/rancher/k3s/storage/pvc-95864012-d138-470c-b4ba-546dff4d78d3_names-app_postgres-pvc
```

**Key Points:**
- ✅ Data added successfully
- ✅ Pod deleted and recreated
- ✅ Data persisted after restart
- ✅ PersistentVolume uses k3s local-path provisioner
- ✅ Storage on k3s-server node

---

### 5. Health Check Endpoint

**Demonstrate health endpoint returns OK**

```bash
curl -s http://localhost:30080/api/health | jq
```

**Expected Output:**
```json
{
  "status": "ok"
}
```

**Check database health specifically:**
```bash
curl -s http://localhost:30080/api/health/db | jq
```

**Expected Output:**
```json
{
  "connection_url": "db-service:5432/namesdb",
  "database": "connected",
  "db_time": "2025-11-05T08:58:53.173435+00:00",
  "service": "Names Manager API - Database",
  "status": "healthy"
}
```

**Check backend liveness probe:**
```bash
kubectl exec -n names-app deployment/backend -- curl -s http://localhost:8000/healthz
```

**Expected Output:**
```
OK
```

**Key Points:**
- ✅ API health endpoint returns `"status": "ok"`
- ✅ Database health endpoint returns `"status": "healthy"`
- ✅ Service discovery working (connects to `db-service`)
- ✅ Liveness and readiness probes configured

---

## Additional Demo Points

### Show All Resources in Namespace

```bash
kubectl get all -n names-app
```

**Expected Output:**
```
NAME                           READY   STATUS    RESTARTS   AGE
pod/backend-68687c58d7-4lh5q   1/1     Running   5          2h
pod/backend-68687c58d7-vtxhg   1/1     Running   5          2h
pod/frontend-99fd98d5b-l4hmm   1/1     Running   0          2h
pod/postgres-0                 1/1     Running   0          1h

NAME                       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
service/api-service        ClusterIP   10.43.171.155   <none>        5000/TCP
service/db-service         ClusterIP   10.43.190.168   <none>        5432/TCP
service/frontend-service   NodePort    10.43.139.97    <none>        80:30080/TCP

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/backend    2/2     2            2           2h
deployment.apps/frontend   1/1     1            1           2h

NAME                        READY   AGE
statefulset.apps/postgres   1/1     2h

NAME                                              REFERENCE            TARGETS
horizontalpodautoscaler.autoscaling/backend-hpa   Deployment/backend   cpu: 0%/70%
```

### Show Pod Placement and Node Selectors

**Check where each pod runs:**
```bash
kubectl get pods -n names-app -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,NODE-SELECTOR:.spec.nodeSelector
```

**Expected Output:**
```
NAME                       NODE         NODE-SELECTOR
backend-68687c58d7-4lh5q   k3s-server   map[kubernetes.io/hostname:k3s-server]
backend-68687c58d7-vtxhg   k3s-server   map[kubernetes.io/hostname:k3s-server]
frontend-99fd98d5b-l4hmm   k3s-server   map[kubernetes.io/hostname:k3s-server]
postgres-0                 k3s-server   map[kubernetes.io/hostname:k3s-server]
```

**Key Point:** All pods run on k3s-server due to nodeSelector (ensures connectivity with port-forwarding setup)

### Show Resource Limits and Requests

```bash
kubectl top nodes
kubectl top pods -n names-app
```

**Expected Output:**
```
NAME         CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
k3s-server   40m          2%       1376Mi          36%
k3s-agent    40m          2%       1376Mi          74%

NAME                       CPU(cores)   MEMORY(bytes)
backend-68687c58d7-4lh5q   1m           167Mi
backend-68687c58d7-vtxhg   1m           167Mi
frontend-99fd98d5b-l4hmm   0m           3Mi
postgres-0                 5m           30Mi
```

**Show resource configuration:**
```bash
kubectl describe pod postgres-0 -n names-app | grep -A 5 "Limits\|Requests"
```

**Expected Output:**
```
    Limits:
      cpu:     500m
      memory:  1Gi
    Requests:
      cpu:      250m
      memory:   512Mi
```

### Show HorizontalPodAutoscaler

```bash
kubectl get hpa -n names-app
kubectl describe hpa backend-hpa -n names-app
```

**Expected Output:**
```
NAME          REFERENCE            TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
backend-hpa   Deployment/backend   cpu: 0%/70%   2         5         2          56m
```

**Key Points:**
- ✅ HPA configured for backend
- ✅ Min replicas: 2, Max replicas: 5
- ✅ Target CPU utilization: 70%
- ✅ Currently at minimum replicas (low load)

### Show ConfigMap and Secrets

```bash
kubectl get configmap names-app-config -n names-app -o yaml
kubectl get secret db-credentials -n names-app -o jsonpath='{.data}' | jq
```

**Key Points:**
- ✅ Configuration externalized via ConfigMap
- ✅ Sensitive data in Secrets (base64 encoded)
- ✅ Environment variables injected into pods

### Test CRUD Operations Live

**Create:**
```bash
curl -X POST http://localhost:30080/api/names \
  -H "Content-Type: application/json" \
  -d '{"name":"k3s Live Demo User"}'
```

**Read All:**
```bash
curl -s http://localhost:30080/api/names | jq '.names | length'
```

**Read One:**
```bash
DEMO_ID=$(curl -s http://localhost:30080/api/names | jq '.names[] | select(.name=="k3s Live Demo User") | .id')
curl -s http://localhost:30080/api/names/$DEMO_ID | jq
```

**Delete:**
```bash
curl -X DELETE http://localhost:30080/api/names/$DEMO_ID
curl -s http://localhost:30080/api/names | jq '.names[] | select(.name=="k3s Live Demo User")'
# Should return empty
```

---

## Advanced Demo Features

### Show Rolling Updates

**Update backend deployment:**
```bash
kubectl rollout restart deployment/backend -n names-app
```

**Watch rollout in real-time:**
```bash
kubectl rollout status deployment/backend -n names-app -w
```

**View rollout history:**
```bash
kubectl rollout history deployment/backend -n names-app
```

### Show Service Discovery

**Test DNS resolution from within a pod:**
```bash
kubectl exec -n names-app deployment/backend -- nslookup db-service
kubectl exec -n names-app deployment/backend -- nslookup api-service
```

**Expected Output:**
```
Server:    10.43.0.10
Address:   10.43.0.10:53

Name:      db-service.names-app.svc.cluster.local
Address:   10.43.190.168
```

### Show Logs from All Pods

**Backend logs:**
```bash
kubectl logs -n names-app -l app=backend --tail=20
```

**Database logs:**
```bash
kubectl logs -n names-app postgres-0 --tail=20
```

**Frontend logs:**
```bash
kubectl logs -n names-app -l app=frontend --tail=20
```

---

## Quick Validation

**Check all pods are running:**
```bash
kubectl get pods -n names-app
```

**All should show `STATUS: Running` and `READY: 1/1`**

**Test full application stack:**
```bash
# Frontend
curl -I http://localhost:30080/

# API health
curl http://localhost:30080/api/health

# Database health
curl http://localhost:30080/api/health/db

# CRUD operations
curl http://localhost:30080/api/names
```

---

## Troubleshooting During Demo

### If VMs aren't running:
```bash
vagrant up
```

### If cluster isn't accessible:
```bash
vagrant ssh k3s-server -c "sudo systemctl status k3s"
kubectl cluster-info
```

### If pods aren't running:
```bash
kubectl get pods -n names-app
kubectl describe pod <pod-name> -n names-app
kubectl logs -n names-app <pod-name>
```

### Redeploy application:
```bash
./ops/deploy-k3s.sh
```

### Check events:
```bash
kubectl get events -n names-app --sort-by='.lastTimestamp'
```

---

## Demo Script Summary

1. **Show cluster**: `kubectl get nodes` → 2 nodes (control-plane + worker)
2. **Show DB placement**: `kubectl get pods -n names-app -o wide` → postgres on k3s-server only
3. **Show web access**: `curl http://localhost:30080/` → renders HTML via NodePort
4. **Show load balancing**: Backend has 2 replicas, ClusterIP service distributes requests
5. **Test persistence**: Add data → delete pod → data persists via PVC
6. **Show health**: `curl http://localhost:30080/api/health/db` → returns healthy status

**Total Demo Time:** ~5-10 minutes

---

## Key Talking Points

### Architecture Highlights
- ✅ Multi-node k3s cluster (control-plane + worker)
- ✅ Pod placement with nodeSelector constraints
- ✅ Service-based networking (ClusterIP, NodePort)
- ✅ Persistent volumes with local-path provisioner
- ✅ ConfigMaps and Secrets for configuration management
- ✅ Liveness and readiness probes for health monitoring
- ✅ HorizontalPodAutoscaler for automatic scaling
- ✅ Resource requests and limits for efficient resource utilization

### Kubernetes-Native Features
- ✅ Declarative configuration with YAML manifests
- ✅ StatefulSet for database with ordered deployment
- ✅ Deployments for stateless applications
- ✅ Service discovery via DNS
- ✅ Rolling updates with zero downtime
- ✅ Pod autoscaling based on metrics
- ✅ Storage abstraction with PV/PVC

### Operational Features
- ✅ Automated deployment scripts (`ops/deploy-k3s.sh`)
- ✅ Data persistence across pod lifecycle
- ✅ Health check endpoints for monitoring
- ✅ Comprehensive logging via kubectl
- ✅ Resource monitoring with `kubectl top`
- ✅ Easy rollback capabilities
- ✅ Scalable architecture (2-5 backend replicas via HPA)

**🎉 Production-ready k3s deployment!**
