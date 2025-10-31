# Live Demo Guide - Names Manager Docker Swarm

This guide provides step-by-step instructions for demonstrating the Docker Swarm deployment of the Names Manager application.

---

## Prerequisites

Before starting the demo, ensure:
- VMs are running: `vagrant status`
- Swarm is initialized
- Stack is deployed

**Quick Setup** (if needed):
```bash
vagrant up
./ops/init-swarm.sh
./ops/deploy.sh
vagrant ssh manager -c 'docker service update --force names_api'
```

---

## Demo Steps

### 1. Show Swarm Cluster with Multiple Nodes

**Demonstrate that the Swarm has 2+ nodes (manager + lab worker)**

```bash
vagrant ssh manager -c 'docker node ls'
```

**Expected Output:**
```
ID                            HOSTNAME        STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
abc123xyz... *                swarm-manager   Ready     Active         Leader           27.3.1
def456uvw...                  swarm-worker    Ready     Active                          27.3.1
```

**Key Points:**
- ✅ Manager node shows `Leader` status
- ✅ Worker node is `Ready` and `Active`
- ✅ Two distinct nodes in the cluster

---

### 2. Show Database Service on Lab Worker Node Only

**Demonstrate DB placement constraint working**

```bash
vagrant ssh manager -c 'docker service ps names_db'
```

**Expected Output:**
```
ID             NAME        IMAGE          NODE           DESIRED STATE   CURRENT STATE
xyz789...      names_db.1  postgres:15    swarm-worker   Running         Running 2 hours ago
```

**Key Points:**
- ✅ Database runs on `swarm-worker` (lab node)
- ✅ NOT on manager node
- ✅ Placement constraint `node.labels.role==db` enforced

**Show the constraint:**
```bash
vagrant ssh manager -c 'docker service inspect names_db --format "{{.Spec.TaskTemplate.Placement}}"'
```

**Expected Output:**
```
{[node.labels.role==db]}
```

---

### 3. Access Web Application & Show Load Balancing

**Demonstrate web accessibility and load balancing across API replicas**

#### 3a. Access the Web Interface

Open in browser or use curl:
```bash
curl -s http://localhost:8081/ | grep -o '<title>.*</title>'
```

**Expected Output:**
```
<title>Names Manager</title>
```

**In Browser:** Navigate to `http://localhost:8081`

**Key Points:**
- ✅ Web interface loads successfully
- ✅ Shows form to add names
- ✅ Displays list of existing names

#### 3b. Show Load Balancing Across API Replicas

**Check API service has 2 replicas:**
```bash
vagrant ssh manager -c 'docker service ls | grep names_api'
```

**Expected Output:**
```
names_api   replicated   2/2   localhost/names-backend:latest
```

**Test load balancing by checking which replica handles requests:**

```bash
# Make multiple requests and check container IDs
for i in {1..5}; do
  echo "Request $i:"
  curl -s http://localhost:8081/api/health | jq -r '.service'
done
```

**Alternative - Check service logs to see requests distributed:**
```bash
vagrant ssh manager -c 'docker service logs names_api --tail 10'
```

**Key Points:**
- ✅ 2/2 API replicas running
- ✅ Ingress routing mesh distributes requests
- ✅ Both replicas on manager node handle traffic

---

### 4. Data Persistence Test

**Demonstrate data persists across DB restart/update**

#### 4a. Insert Test Data

**Add a name via web interface or API:**
```bash
curl -X POST http://localhost:8081/api/names \
  -H "Content-Type: application/json" \
  -d '{"name":"Demo Persistence Test"}'
```

**Expected Output:**
```json
{"id":10,"name":"Demo Persistence Test"}
```

**Verify data exists:**
```bash
curl -s http://localhost:8081/api/names | jq '.names[] | select(.name=="Demo Persistence Test")'
```

**Expected Output:**
```json
{
  "created_at": "2025-10-31T...",
  "id": 10,
  "name": "Demo Persistence Test"
}
```

#### 4b. Restart Database Service

**Force DB restart:**
```bash
vagrant ssh manager -c 'docker service update --force names_db'
```

**Wait for service to stabilize (~10 seconds):**
```bash
vagrant ssh manager -c 'docker service ps names_db'
```

#### 4c. Verify Data Persisted

**Check that data still exists after restart:**
```bash
curl -s http://localhost:8081/api/names | jq '.names[] | select(.name=="Demo Persistence Test")'
```

**Expected Output:**
```json
{
  "created_at": "2025-10-31T...",
  "id": 10,
  "name": "Demo Persistence Test"
}
```

**Show storage location:**
```bash
vagrant ssh worker -c 'sudo du -sh /var/lib/postgres-data'
```

**Expected Output:**
```
47M     /var/lib/postgres-data
```

**Key Points:**
- ✅ Data added successfully
- ✅ Database restarted/updated
- ✅ Data persisted after restart
- ✅ Volume mounted at `/var/lib/postgres-data` on worker

---

### 5. Health Check Endpoint

**Demonstrate health endpoint returns OK**

```bash
curl -s http://localhost:8081/api/health | jq
```

**Expected Output:**
```json
{
  "service": "Names Manager API",
  "status": "ok",
  "timestamp": "2025-10-31T..."
}
```

**Check database health specifically:**
```bash
curl -s http://localhost:8081/api/health/db | jq
```

**Expected Output:**
```json
{
  "connection_url": "db:5432/namesdb",
  "database": "connected",
  "db_time": "2025-10-31T...",
  "service": "Names Manager API - Database",
  "status": "healthy"
}
```

**Key Points:**
- ✅ API health endpoint returns `"status": "ok"`
- ✅ Database health endpoint returns `"status": "healthy"`
- ✅ Shows service discovery working (connects to `db` service name)

---

## Additional Demo Points

### Show Service Placement Constraints

**All services and their placement:**
```bash
vagrant ssh manager -c 'docker service ls --format "table {{.Name}}\t{{.Replicas}}\t{{.Mode}}"'
```

**Check where each service runs:**
```bash
vagrant ssh manager -c 'docker service ps names_db names_api names_web --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}"'
```

**Expected Output:**
```
NAME           NODE           CURRENT STATE
names_db.1     swarm-worker   Running
names_api.1    swarm-manager  Running
names_api.2    swarm-manager  Running
names_web.1    swarm-manager  Running
```

### Show Overlay Network

**List networks:**
```bash
vagrant ssh manager -c 'docker network ls | grep appnet'
```

**Inspect overlay network:**
```bash
vagrant ssh manager -c 'docker network inspect appnet --format "{{.Scope}}: {{.Driver}} - {{.IPAM.Config}}"'
```

**Expected Output:**
```
swarm: overlay - [{10.0.1.0/24  10.0.1.1 map[]}]
```

### Show Docker Secrets

**List secrets:**
```bash
vagrant ssh manager -c 'docker secret ls'
```

**Expected Output:**
```
ID                          NAME                CREATED
abc123...                   postgres_db         2 days ago
def456...                   postgres_password   2 days ago
ghi789...                   postgres_user       2 days ago
```

### Test CRUD Operations Live

**Create:**
```bash
curl -X POST http://localhost:8081/api/names -H "Content-Type: application/json" -d '{"name":"Live Demo User"}'
```

**Read All:**
```bash
curl -s http://localhost:8081/api/names | jq '.names | length'
```

**Read One:**
```bash
DEMO_ID=$(curl -s http://localhost:8081/api/names | jq '.names[] | select(.name=="Live Demo User") | .id')
curl -s http://localhost:8081/api/names/$DEMO_ID | jq
```

**Delete:**
```bash
curl -X DELETE http://localhost:8081/api/names/$DEMO_ID
curl -s http://localhost:8081/api/names | jq '.names[] | select(.name=="Live Demo User")'
# Should return empty
```

---

## Quick Validation

Run the automated validation script:
```bash
./ops/validate.sh
```

**Expected Output:**
```
🎉 ALL TESTS PASSED! System is production-ready.

Total Tests: 38
Passed:      38 ✅
Failed:      0 ❌
```

---

## Troubleshooting During Demo

### If services aren't running:
```bash
./ops/deploy.sh
```

### If API shows connection errors:
```bash
vagrant ssh manager -c 'docker service update --force names_api'
```

### Check service logs:
```bash
vagrant ssh manager -c 'docker service logs names_api --tail 20'
vagrant ssh manager -c 'docker service logs names_db --tail 20'
```

### Verify deployment:
```bash
./ops/verify.sh
```

---

## Demo Script Summary

1. **Show cluster**: `docker node ls` → 2 nodes
2. **Show DB placement**: `docker service ps names_db` → runs on worker only
3. **Show web access**: `curl http://localhost:8081/` → renders HTML
4. **Show load balancing**: API has 2 replicas distributing requests
5. **Test persistence**: Add data → restart DB → data persists
6. **Show health**: `curl http://localhost:8081/api/health` → returns OK

**Total Demo Time:** ~5-10 minutes

---

## Key Talking Points

### Architecture Highlights
- ✅ Multi-node Swarm cluster (manager + worker)
- ✅ Service placement constraints enforced
- ✅ Overlay network for service discovery
- ✅ Persistent volumes for database storage
- ✅ Docker Secrets for credential management
- ✅ Health checks for monitoring
- ✅ Load balancing with ingress routing mesh

### Operational Features
- ✅ Automated deployment scripts
- ✅ Verification tooling
- ✅ Data persistence across service lifecycle
- ✅ Zero-downtime rolling updates
- ✅ Service discovery via DNS
- ✅ Comprehensive monitoring and health checks

**🎉 Production-ready Docker Swarm deployment!**
