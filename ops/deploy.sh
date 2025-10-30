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

# Build images
echo "Step 1: Building Docker images..."
cd src/
if [ ! -f build-images.sh ]; then
    echo "ERROR: build-images.sh not found. Creating it..."
    cat > build-images.sh << 'BUILDEOF'
#!/bin/bash
set -e
echo "Building backend image..."
docker build -t localhost/names-backend:latest ./backend
echo "Building frontend image..."
docker build -t localhost/names-frontend:latest ./frontend
echo "✅ Build complete!"
docker images | grep names
BUILDEOF
    chmod +x build-images.sh
fi
./build-images.sh
cd ..

# Save images
echo "Step 2: Saving images..."
docker save localhost/names-backend:latest | gzip > /tmp/names-backend.tar.gz
docker save localhost/names-frontend:latest | gzip > /tmp/names-frontend.tar.gz
echo "✅ Backend image: $(ls -lh /tmp/names-backend.tar.gz | awk '{print $5}')"
echo "✅ Frontend image: $(ls -lh /tmp/names-frontend.tar.gz | awk '{print $5}')"

# Get SSH port for manager
MANAGER_PORT=$(vagrant port manager --guest 22)

# Transfer images to manager
echo "Step 3: Transferring images to manager VM (port $MANAGER_PORT)..."
scp -P "$MANAGER_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    /tmp/names-backend.tar.gz /tmp/names-frontend.tar.gz \
    vagrant@localhost:/home/vagrant/

# Load images on manager
echo "Step 4: Loading images on manager VM..."
vagrant ssh manager << 'EOF'
echo "Loading backend image..."
gunzip < names-backend.tar.gz | docker load
echo "Loading frontend image..."
gunzip < names-frontend.tar.gz | docker load
rm -f names-*.tar.gz
echo "✅ Images loaded:"
docker images | grep names
EOF

# Deploy stack
echo "Step 5: Deploying stack..."
vagrant ssh manager -c "docker stack deploy -c /vagrant/swarm/stack.yaml names"

# Wait for services
echo "Step 6: Waiting for services to start..."
sleep 20

# Show deployment status
echo "Step 7: Verifying deployment..."
echo ""
echo "Services:"
vagrant ssh manager -c "docker stack services names"
echo ""
echo "Service Tasks:"
vagrant ssh manager -c "docker stack ps names --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}' | grep Running"

# Clean up local files
rm -f /tmp/names-*.tar.gz

echo ""
echo "=== Deployment Complete ==="
echo "Application URL: http://localhost:8081"
echo "API Health: http://localhost:8081/api/health"
echo ""
echo "To verify deployment, run: ops/verify.sh"
