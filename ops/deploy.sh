#!/bin/bash
# ops/deploy.sh - Deploy application to Docker Swarm

set -e

echo "=== Deploying Names Manager to Swarm ==="

# Check if Swarm is initialized
echo "Checking Swarm status..."
vagrant ssh manager -c "docker node ls" > /dev/null || { 
    echo "ERROR: Swarm not initialized. Run 'ops/init-swarm.sh' first."; 
    exit 1; 
}

# Build images directly on manager VM
echo "Step 1: Building Docker images on manager VM..."
echo "Building backend image..."
vagrant ssh manager -c "cd /vagrant/src/backend && docker build -t localhost/names-backend:latest ."

echo "Building frontend image..."
vagrant ssh manager -c "cd /vagrant/src/frontend && docker build -t localhost/names-frontend:latest ."

echo "✅ Images built:"
vagrant ssh manager -c "docker images | grep names"

# Deploy stack
echo "Step 2: Deploying stack..."
vagrant ssh manager -c "docker stack deploy -c /vagrant/swarm/stack.yaml names"

# Wait for services
echo "Step 3: Waiting for services to start..."
sleep 20

# Show deployment status
echo "Step 4: Verifying deployment..."
echo ""
echo "Services:"
vagrant ssh manager -c "docker stack services names"
echo ""
echo "Service Tasks:"
vagrant ssh manager -c "docker stack ps names --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}' | grep Running || true"

echo ""
echo "=== Deployment Complete ==="
echo "Application URL: http://localhost:8081"
echo "API Health: http://localhost:8081/api/health"
echo ""
echo "To verify deployment, run: ops/verify.sh"
