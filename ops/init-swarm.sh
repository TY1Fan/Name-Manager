#!/bin/bash
# ops/init-swarm.sh - Initialize Docker Swarm cluster

set -e

echo "=== Initializing Docker Swarm Cluster ==="

# Check if VMs are running
echo "Checking VM status..."
vagrant status | grep -E "manager.*running" || { echo "ERROR: Manager VM not running. Run 'vagrant up' first."; exit 1; }
vagrant status | grep -E "worker.*running" || { echo "ERROR: Worker VM not running. Run 'vagrant up' first."; exit 1; }

# Initialize Swarm on manager
echo "Step 1: Initializing Swarm on manager node..."
SWARM_INIT_OUTPUT=$(vagrant ssh manager -c "docker swarm init --advertise-addr 192.168.56.10 2>&1" || echo "already initialized")

if echo "$SWARM_INIT_OUTPUT" | grep -q "already initialized"; then
    echo "Swarm already initialized on manager."
    JOIN_TOKEN=$(vagrant ssh manager -c "docker swarm join-token worker -q")
else
    echo "Swarm initialized successfully."
    JOIN_TOKEN=$(vagrant ssh manager -c "docker swarm join-token worker -q")
fi

echo "Worker join token: $JOIN_TOKEN"

# Join worker to Swarm
echo "Step 2: Joining worker node to Swarm..."
vagrant ssh worker -c "docker swarm join --token $JOIN_TOKEN 192.168.56.10:2377 2>&1" || echo "Worker already joined."

# Wait for nodes to be ready
echo "Step 3: Waiting for nodes to be ready..."
sleep 5

# Verify cluster
echo "Step 4: Verifying Swarm cluster..."
vagrant ssh manager -c "docker node ls"

# Label worker node for database placement
echo "Step 5: Labeling worker node with role=db..."
vagrant ssh manager -c "docker node update --label-add role=db swarm-worker"

# Verify label
echo "Verifying label..."
vagrant ssh manager -c "docker node inspect swarm-worker --format '{{.Spec.Labels}}'"

# Create overlay network
echo "Step 6: Creating overlay network 'appnet'..."
vagrant ssh manager -c "docker network create --driver overlay --attachable --subnet 10.0.1.0/24 appnet 2>&1" || echo "Network already exists."

# Verify network
vagrant ssh manager -c "docker network ls | grep appnet"

# Create storage directory on worker
echo "Step 7: Creating storage directory on worker node..."
vagrant ssh worker << 'EOF'
sudo mkdir -p /var/lib/postgres-data
sudo chmod 700 /var/lib/postgres-data
sudo chown 999:999 /var/lib/postgres-data
ls -ld /var/lib/postgres-data
EOF

echo ""
echo "=== Swarm Cluster Initialized Successfully ==="
echo "Manager: 192.168.56.10"
echo "Worker: 192.168.56.11 (labeled with role=db)"
echo "Network: appnet (overlay, 10.0.1.0/24)"
echo "Storage: /var/lib/postgres-data on worker"
echo ""
echo "Next step: Run 'ops/deploy.sh' to deploy the application"
