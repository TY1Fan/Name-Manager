# Live Demo Guide - Docker Swarm Multi-Node Deployment

This guide provides a complete walkthrough for demonstrating your Docker Swarm deployment with all required verification steps.

---

## Pre-Demo Setup (5 minutes before demo)

### ⚠️ **IMPORTANT: macOS Docker Desktop Limitation**

**Docker Desktop on macOS cannot run a Swarm manager that external nodes can join.**  
Docker Swarm ports (2377, 7946, 4789) run inside Docker Desktop's Linux VM and are NOT accessible from VirtualBox VMs or external networks.

**Two Solutions:**

#### **Solution A: Use Cloud VM or Linux Machine (Recommended for Real Demo)**
- Deploy both manager and worker on actual Linux machines
- Or use cloud VMs (AWS, DigitalOcean, etc.)

#### **Solution B: Run Manager in Vagrant Too (Works for Local Demo)**
- Create 2 Vagrant VMs: one manager, one worker
- Both run in VirtualBox and can communicate
- This sacrifices the "laptop as manager" aspect but demonstrates all Swarm features

**For this demo, if you're on macOS with Docker Desktop:**
1. You can demo **Docker Compose** (works perfectly)
2. For **Swarm demo**, you need Linux machines or cloud VMs
3. Alternative: Show Swarm with `docker-compose` locally (single-node swarm)

### 1. Quick Demo Setup (Works on macOS)

**For a working demo on macOS**, use this simplified approach:

**Option A: Single-Node Swarm (Easiest)**
```bash
# Initialize single-node swarm
docker swarm init

# Deploy locally
cd src
docker stack deploy -c swarm/stack.yaml names-app

# All services run on your Mac
docker service ls
docker service ps names-app_db
```

This demonstrates:
- ✅ Stack deployment with docker-compose syntax
- ✅ Service scaling and updates
- ✅ Health checks
- ✅ Overlay networking  
- ❌ Multi-node placement (not possible with Docker Desktop)

**Option B: Use Docker Compose (Recommended for macOS Demo)**
```bash
cd src
docker-compose up -d

# Show services
docker-compose ps

# Show logs
docker-compose logs backend

# Test scaling
docker-compose up -d --scale backend=2
```

This is what works reliably on macOS!

### 2. Full Multi-Node Demo (Requires Linux or Cloud VMs)

If you have access to Linux machines or cloud VMs, here's the working setup:

```bash
# Get your Mac's main network IP
MY_IP=$(ifconfig en0 | grep "inet " | grep -v inet6 | awk '{print $2}')
echo "My IP: $MY_IP"

# Initialize Swarm with this IP
docker swarm leave --force 2>/dev/null
docker swarm init --advertise-addr $MY_IP

# Get the join token
JOIN_CMD=$(docker swarm join-token worker | grep "docker swarm join")

# Join worker from Vagrant VM
cd vagrant
vagrant ssh -c "sudo $JOIN_CMD"
cd ..

# Label the worker node
WORKER_ID=$(docker node ls --filter "role=worker" --format "{{.ID}}" | head -1)
docker node update --label-add role=db $WORKER_ID

# Create storage on worker
vagrant ssh -c "sudo mkdir -p /var/lib/postgres-data && sudo chown -R 999:999 /var/lib/postgres-data"

# Verify cluster
docker node ls
```

**Note**: Your Mac's IP (`$MY_IP`) should be reachable from the Vagrant VM. Test with:
```bash
vagrant ssh -c "ping -c 2 $MY_IP"
```

### 2. Fix VirtualBox Issues (if needed)

If you get VirtualBox errors when starting the VM, try these steps:

```bash
# Stop any running VirtualBox VMs
VBoxManage list runningvms
VBoxManage list vms

# If you see the swarm-worker VM, try:
VBoxManage controlvm swarm-worker poweroff 2>/dev/null
VBoxManage unregistervm swarm-worker --delete 2>/dev/null

# Or use Vagrant to clean up
cd vagrant
vagrant destroy -f
cd ..
```

### 3. Quick Manual Setup (Recommended for macOS)

Since Docker Desktop has limitations with Swarm networking, use this manual setup:

```bash
# Get your Mac's IP on main network interface
MY_IP=$(ifconfig en0 | grep "inet " | grep -v inet6 | awk '{print $2}')
echo "Using IP: $MY_IP"

# 1. Start Vagrant VM
cd vagrant
vagrant up
cd ..

# 2. Initialize Swarm on your Mac
docker swarm leave --force 2>/dev/null
docker swarm init --advertise-addr $MY_IP

# 3. Join worker node
JOIN_TOKEN=$(docker swarm join-token worker -q)
vagrant ssh -c "sudo docker swarm join --token $JOIN_TOKEN $MY_IP:2377"

# 4. Label worker for database
WORKER_ID=$(docker node ls --filter "role=worker" --format "{{.ID}}" | head -1)
docker node update --label-add role=db $WORKER_ID

# 5. Create persistent storage on worker
vagrant ssh -c "sudo mkdir -p /var/lib/postgres-data && sudo chown -R 999:999 /var/lib/postgres-data"

# 6. Deploy the stack
cd src
docker stack deploy -c swarm/stack.yaml names-app
cd ..

# 7. Wait for services to be ready
sleep 30

# 8. Verify
docker node ls
docker service ls
```

### 4. Alternative: Use init script (may fail on macOS)
```bash
# This may not work due to Docker Desktop limitations
./ops/init-swarm.sh
./ops/deploy.sh
sleep 30
```

### 2. Verify Everything is Ready
```bash
# Quick check
./ops/verify.sh --quick
```

---

## Live Demo Script

### **Demo Step 1: Show Multi-Node Cluster** ✅

**What to say:**
> "First, let me show you our Docker Swarm cluster with multiple nodes - a manager node on my laptop and a worker node running on a Linux VM."

**Command:**
```bash
docker node ls
```

**Expected Output:**
```
ID                            HOSTNAME          STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
abc123def456 *                docker-desktop    Ready     Active         Leader           24.0.x
xyz789uvw012                  vagrant-worker    Ready     Active                          24.0.x
```

**What to point out:**
- ✅ Shows **2+ nodes** (manager + worker)
- ✅ Manager has "Leader" status (indicated by *)
- ✅ Both nodes are "Ready" and "Active"
- ✅ Worker is the Linux lab node (vagrant-worker)

---

### **Demo Step 2: Show Database Placement on Lab Node** ✅

**What to say:**
> "The database service is constrained to run only on the lab worker node using placement constraints. Let me show you where it's actually running."

**Command:**
```bash
docker service ps names-app_db
```

**Expected Output:**
```
ID             NAME              IMAGE          NODE             DESIRED STATE   CURRENT STATE
abc123def456   names-app_db.1    postgres:15    vagrant-worker   Running         Running 2 minutes ago
```

**What to point out:**
- ✅ Shows `names-app_db` service
- ✅ NODE column shows "vagrant-worker" (the lab Linux node)
- ✅ CURRENT STATE is "Running"
- ✅ Database is **only** on the lab node, not on manager

**Alternative detailed view:**
```bash
docker service ps names-app_db --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}"
```

**Show the placement constraint:**
```bash
docker service inspect names-app_db --format '{{json .Spec.TaskTemplate.Placement}}' | jq
```

**Expected Output:**
```json
{
  "Constraints": [
    "node.labels.role == db"
  ]
}
```

---

### **Demo Step 3: Test Web Interface** ✅

**What to say:**
> "Now let's access the web application through the manager node. The frontend is accessible on port 80."

**Get Manager IP:**
```bash
# Manager IP (your Mac)
MANAGER_IP=$(docker node inspect self --format '{{.Status.Addr}}')
echo "Manager IP: $MANAGER_IP"
```

**Command:**
```bash
# Access from browser or curl
curl http://localhost/
# Or use the manager IP
curl http://$MANAGER_IP/
```

**Expected Output:**
```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Names Manager</title>
  ...
</head>
<body>
  ...
</body>
</html>
```

**What to point out:**
- ✅ Web interface renders successfully
- ✅ Accessible via manager IP on port 80
- ✅ Shows the application is working end-to-end

**Open in browser:**
```bash
# macOS
open http://localhost

# Or show in terminal browser
curl -s http://localhost | head -30
```

---

### **Demo Step 4: Show Load Balancing (Optional - if you scale)** 🔄

**What to say:**
> "Docker Swarm provides built-in load balancing. Let me scale the backend to show how requests are distributed."

**Scale backend service:**
```bash
# Scale to 2 replicas
docker service scale names-app_backend=2

# Wait for scaling
sleep 10

# Check both replicas are running
docker service ps names-app_backend
```

**Test load balancing:**
```bash
# Multiple requests show different container IDs
for i in {1..5}; do
  echo "Request $i:"
  curl -s http://localhost/api/names | head -1
  sleep 1
done
```

**What to point out:**
- ✅ Requests distributed across multiple backend replicas
- ✅ Swarm's built-in load balancer routes traffic
- ✅ No external load balancer needed

**Scale back:**
```bash
docker service scale names-app_backend=1
```

---

### **Demo Step 5: Insert Data** ✅

**What to say:**
> "Let me add some data to demonstrate persistence. I'll insert a record through the API."

**Command:**
```bash
# Insert a test record
curl -X POST http://localhost/api/names \
  -H "Content-Type: application/json" \
  -d '{"name":"Demo User - Live Test"}'
```

**Expected Output:**
```json
{"id":6,"name":"Demo User - Live Test"}
```

**Verify data was inserted:**
```bash
# List all names
curl -s http://localhost/api/names | jq
```

**Expected Output:**
```json
[
  ...existing records...,
  {
    "created_at": "2025-10-30T10:30:45.123456",
    "id": 6,
    "name": "Demo User - Live Test"
  }
]
```

**What to point out:**
- ✅ Data inserted successfully
- ✅ Received confirmation with ID
- ✅ Data is stored in PostgreSQL on the lab node
- ✅ Record includes timestamp and auto-generated ID

---

### **Demo Step 6: Restart/Update Database & Verify Persistence** ✅

**What to say:**
> "Now the critical part - I'll force the database container to restart and show that our data persists because of the bind mount to the lab node's filesystem."

**Method A: Force Update (Recommended for Demo):**
```bash
echo "Current database container:"
docker service ps names-app_db --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}"

echo -e "\n🔄 Forcing database update (will restart container)..."
docker service update --force names-app_db

echo -e "\n⏳ Waiting for container restart..."
sleep 15

echo -e "\n✅ New database container:"
docker service ps names-app_db --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}"
```

**Method B: Simulate Failure:**
```bash
# Get container ID on worker
CONTAINER_ID=$(vagrant ssh -c "docker ps -q --filter name=names-app_db" 2>/dev/null)

# Kill the container
vagrant ssh -c "docker kill $CONTAINER_ID"

# Swarm will automatically restart it
sleep 10
```

**Verify Data Persists:**
```bash
echo -e "\n🔍 Checking if our demo data survived the restart..."
curl -s http://localhost/api/names | jq '.[] | select(.name | contains("Demo User"))'
```

**Expected Output:**
```json
{
  "created_at": "2025-10-30T10:30:45.123456",
  "id": 6,
  "name": "Demo User - Live Test"
}
```

**What to point out:**
- ✅ Container was replaced (new ID, newer start time)
- ✅ Data **still exists** after container replacement
- ✅ Demonstrates persistent storage working correctly
- ✅ Bind mount to `/var/lib/postgres-data` preserves data

**Show where data is stored:**
```bash
# Show storage on lab node
vagrant ssh -c "ls -lh /var/lib/postgres-data"
```

---

### **Demo Step 7: Health Check Endpoint** ✅

**What to say:**
> "Finally, let's check the health endpoint to verify all services are operational."

**Command:**
```bash
curl http://localhost/healthz
```

**⚠️ Note:** The health endpoint might not be proxied through nginx. Try these alternatives:

**Option 1: Direct backend access (if healthz not proxied):**
```bash
# Get backend container ID
BACKEND_CONTAINER=$(docker ps --filter "name=names-app_backend" --format "{{.ID}}" | head -1)

# Access healthz directly
docker exec $BACKEND_CONTAINER curl -s http://localhost:8000/healthz
```

**Expected Output:**
```json
{"status":"ok"}
```

**Option 2: Check via service logs:**
```bash
docker service logs names-app_backend --tail 5 | grep healthz
```

**Option 3: Test database connectivity:**
```bash
# Test database is reachable from backend
docker exec $(docker ps -qf "name=names-app_backend") \
  curl -s http://localhost:8000/healthz
```

**What to point out:**
- ✅ Returns `{"status":"ok"}` - all systems operational
- ✅ Health check verifies database connectivity
- ✅ Backend can reach database across nodes (overlay network)

---

## Complete Demo Flow (Quick Reference)

```bash
# 1. Show cluster
docker node ls

# 2. Show DB placement
docker service ps names-app_db

# 3. Test web
curl http://localhost/

# 4. Insert data
curl -X POST http://localhost/api/names \
  -H "Content-Type: application/json" \
  -d '{"name":"Demo User - Live Test"}'

# 5. Verify data
curl -s http://localhost/api/names | jq '.[] | select(.name | contains("Demo User"))'

# 6. Restart DB
docker service update --force names-app_db
sleep 15

# 7. Verify persistence
curl -s http://localhost/api/names | jq '.[] | select(.name | contains("Demo User"))'

# 8. Health check
docker exec $(docker ps -qf "name=names-app_backend") curl -s http://localhost:8000/healthz
```

---

## Troubleshooting During Demo

### Issue: VirtualBox VM won't start

**Error:**
```
VBoxManage: error: The VM session was aborted
VBoxManage: error: Details: code NS_ERROR_FAILURE (0x80004005)
```

**Solutions:**

**Option 1: Clean up and retry**
```bash
# Stop and remove any existing VM
cd vagrant
vagrant destroy -f

# Remove VirtualBox VM if it exists
VBoxManage list vms | grep swarm-worker
VBoxManage unregistervm swarm-worker --delete 2>/dev/null

# Try again
cd ..
./ops/init-swarm.sh
```

**Option 2: Check VirtualBox permissions (macOS)**
```bash
# Check if VirtualBox has necessary permissions
# Go to System Settings > Privacy & Security > Full Disk Access
# Make sure VirtualBox is enabled

# Restart VirtualBox
sudo /Library/Application\ Support/VirtualBox/LaunchDaemons/VirtualBoxStartup.sh restart
```

**Option 3: Manual VM start**
```bash
cd vagrant
vagrant up
vagrant ssh -c "docker --version"  # Verify Docker is installed

# Then continue with manual setup
cd ..
# Follow manual steps in init-swarm.sh
```

**Option 4: Use existing VM if already running**
```bash
# Check if VM is already running elsewhere
VBoxManage list runningvms

# If it's running, you can skip init-swarm.sh and go straight to deploy
./ops/deploy.sh
```

---

### Issue: Services not ready
```bash
# Check service status
docker service ls

# Check logs
docker service logs names-app_backend --tail 20
docker service logs names-app_db --tail 20

# Give it more time
sleep 30
```

### Issue: Can't access web interface
```bash
# Check frontend service
docker service ps names-app_frontend

# Check port is published
docker service inspect names-app_frontend --format '{{json .Endpoint.Ports}}' | jq

# Try local curl
curl -v http://localhost/
```

### Issue: Data not persisting
```bash
# Check volume mount
docker service inspect names-app_db --format '{{json .Spec.TaskTemplate.ContainerSpec.Mounts}}' | jq

# Check storage directory on worker
vagrant ssh -c "ls -la /var/lib/postgres-data"

# Check volume config
docker volume inspect names-app_db_data
```

### Issue: Health check fails
```bash
# Check backend logs
docker service logs names-app_backend --tail 50

# Check database connectivity
docker exec $(docker ps -qf "name=names-app_db") pg_isready -U names_user

# Test API directly
curl http://localhost/api/names
```

---

## Presentation Tips

### Opening Statement
> "Today I'm demonstrating a multi-node Docker Swarm deployment with persistent storage. The application is a names manager with a PostgreSQL database running on a separate lab node, a Flask backend, and an nginx frontend."

### Key Points to Emphasize
1. **Multi-node orchestration** - Manager on laptop, worker on Linux VM
2. **Placement constraints** - Database pinned to specific node using labels
3. **Persistent storage** - Bind mount ensures data survives container lifecycle
4. **Service discovery** - Containers communicate across nodes via overlay network
5. **High availability** - Automatic restart policies and health checks

### Closing Statement
> "As you can see, Docker Swarm provides production-ready orchestration with built-in load balancing, service discovery, and persistent storage - all configured declaratively in the stack.yaml file."

---

## Backup Demo Commands (If Something Goes Wrong)

### Quick Reset
```bash
# If demo goes wrong, quick reset:
./ops/cleanup.sh --yes
./ops/init-swarm.sh
./ops/deploy.sh
sleep 30
```

### Show Everything Works
```bash
# One-liner to show it all works
./ops/verify.sh
```

---

## Demo Checklist

Before starting:
- [ ] Cluster initialized (`docker node ls` shows 2 nodes)
- [ ] Stack deployed (`docker service ls` shows 3 services)
- [ ] All services running (`docker service ls` shows 1/1 replicas)
- [ ] Web accessible (`curl http://localhost/` returns HTML)
- [ ] Terminal ready with commands copied
- [ ] Browser tab open to `http://localhost` (optional)

During demo:
- [ ] Show multi-node cluster
- [ ] Show DB placement on lab node
- [ ] Test web interface
- [ ] Insert test data
- [ ] Restart database service
- [ ] Verify data persisted
- [ ] Show health check

After demo:
- [ ] Answer questions about:
  - How placement constraints work
  - Why bind mount vs volume
  - How overlay networking works
  - How to scale services

---

## Advanced Demo Points (If Time Permits)

### Show Automatic Scaling
```bash
docker service scale names-app_backend=3
watch docker service ls  # Show replicas increasing
docker service scale names-app_backend=1
```

### Show Rolling Update
```bash
docker service update --image names-manager-backend:latest names-app_backend
docker service ps names-app_backend  # Shows old and new containers
```

### Show Network Isolation
```bash
docker network ls | grep names-app
docker network inspect names-app_appnet
```

### Show Service Discovery
```bash
# From backend, ping database by service name
docker exec $(docker ps -qf "name=names-app_backend") ping -c 2 db
```

---

## Time Estimates

- **Quick Demo**: 5 minutes (steps 1-2-5-6-7)
- **Standard Demo**: 10 minutes (all steps)
- **Detailed Demo**: 15 minutes (all steps + advanced points)

---

## Final Verification (Before Audience)

Run this complete test sequence:

```bash
echo "=== Testing Complete Demo Flow ==="
echo "1. Cluster status:"
docker node ls
echo -e "\n2. DB placement:"
docker service ps names-app_db --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}"
echo -e "\n3. Web test:"
curl -s http://localhost/ | grep -o "<title>.*</title>"
echo -e "\n4. Insert data:"
curl -X POST http://localhost/api/names -H "Content-Type: application/json" -d '{"name":"Test"}'
echo -e "\n5. Verify data:"
curl -s http://localhost/api/names | jq -r '.[-1].name'
echo -e "\n6. Restarting DB..."
docker service update --force names-app_db > /dev/null
sleep 15
echo -e "\n7. Data persists:"
curl -s http://localhost/api/names | jq -r '.[-1].name'
echo -e "\n8. Health check:"
docker exec $(docker ps -qf "name=names-app_backend") curl -s http://localhost:8000/healthz
echo -e "\n✅ All tests passed! Ready for demo."
```

Good luck with your live demo! 🚀
