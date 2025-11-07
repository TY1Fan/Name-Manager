#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Update Names Manager Images on k3s ==="
echo ""

# Check kubectl access
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to k3s cluster${NC}"
    exit 1
fi

# Default component (if not specified)
COMPONENT="${1:-all}"

update_backend() {
    echo -e "${BLUE}Updating backend...${NC}"
    
    # Build new image
    echo "Building backend image..."
    cd src
    docker build -t names-backend:latest -f backend/Dockerfile backend/
    cd ..
    
    # Save and transfer to k3s
    echo "Saving image to tar..."
    docker save names-backend:latest -o /tmp/backend.tar
    
    echo "Transferring to k3s-server..."
    scp /tmp/backend.tar vagrant@192.168.56.10:/tmp/
    
    echo "Importing to k3s containerd..."
    ssh vagrant@192.168.56.10 "sudo k3s ctr images import /tmp/backend.tar && rm /tmp/backend.tar"
    rm /tmp/backend.tar
    
    # Restart deployment
    echo "Restarting backend deployment..."
    kubectl rollout restart deployment/backend -n names-app
    
    echo -e "${YELLOW}⏳${NC} Waiting for rollout to complete..."
    kubectl rollout status deployment/backend -n names-app --timeout=300s
    
    echo -e "${GREEN}✓${NC} Backend updated successfully"
}

update_frontend() {
    echo -e "${BLUE}Updating frontend...${NC}"
    
    # Build new image
    echo "Building frontend image..."
    cd src
    docker build -t names-frontend:latest -f frontend/Dockerfile frontend/
    cd ..
    
    # Save and transfer to k3s
    echo "Saving image to tar..."
    docker save names-frontend:latest -o /tmp/frontend.tar
    
    echo "Transferring to k3s-server..."
    scp /tmp/frontend.tar vagrant@192.168.56.10:/tmp/
    
    echo "Importing to k3s containerd..."
    ssh vagrant@192.168.56.10 "sudo k3s ctr images import /tmp/frontend.tar && rm /tmp/frontend.tar"
    rm /tmp/frontend.tar
    
    # Restart deployment
    echo "Restarting frontend deployment..."
    kubectl rollout restart deployment/frontend -n names-app
    
    echo -e "${YELLOW}⏳${NC} Waiting for rollout to complete..."
    kubectl rollout status deployment/frontend -n names-app --timeout=300s
    
    echo -e "${GREEN}✓${NC} Frontend updated successfully"
}

# Main logic
case "$COMPONENT" in
    backend)
        update_backend
        ;;
    frontend)
        update_frontend
        ;;
    all)
        update_backend
        echo ""
        update_frontend
        ;;
    *)
        echo -e "${RED}Error: Invalid component '${COMPONENT}'${NC}"
        echo "Usage: $0 [backend|frontend|all]"
        echo "  backend  - Update only backend"
        echo "  frontend - Update only frontend"
        echo "  all      - Update both (default)"
        exit 1
        ;;
esac

# Show final status
echo ""
echo "=== Current Status ==="
kubectl get pods -n names-app

echo ""
NODEPORT=$(kubectl get svc frontend-service -n names-app -o jsonpath='{.spec.ports[0].nodePort}')
echo -e "${GREEN}✓✓✓ Update completed! ✓✓✓${NC}"
echo ""
echo "Application URL: http://localhost:${NODEPORT}"
echo ""
echo "To verify:"
echo "  curl http://localhost:${NODEPORT}/api/health/db"
