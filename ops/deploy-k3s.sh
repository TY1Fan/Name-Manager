#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Deploying Names Manager to k3s ==="
echo ""

# Check kubectl access
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to k3s cluster${NC}"
    echo "Please ensure kubectl is configured and k3s is running"
    exit 1
fi

echo -e "${GREEN}✓${NC} kubectl connection verified"

# 1. Create namespace and configuration
echo ""
echo "Step 1: Creating namespace and configuration..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
echo -e "${GREEN}✓${NC} Namespace and configuration created"

# 2. Deploy database
echo ""
echo "Step 2: Deploying database..."
kubectl apply -f k8s/database-pvc.yaml
kubectl apply -f k8s/database-statefulset.yaml
kubectl apply -f k8s/database-service.yaml

echo -e "${YELLOW}⏳${NC} Waiting for database to be ready (timeout: 300s)..."
if kubectl wait --for=condition=ready pod/postgres-0 -n names-app --timeout=300s; then
    echo -e "${GREEN}✓${NC} Database is ready"
else
    echo -e "${RED}✗${NC} Database failed to become ready"
    exit 1
fi

# 3. Deploy backend
echo ""
echo "Step 3: Deploying backend API..."
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml

echo -e "${YELLOW}⏳${NC} Waiting for backend to be ready (timeout: 300s)..."
if kubectl wait --for=condition=available deployment/backend -n names-app --timeout=300s; then
    echo -e "${GREEN}✓${NC} Backend is ready"
else
    echo -e "${RED}✗${NC} Backend failed to become ready"
    exit 1
fi

# 4. Deploy frontend
echo ""
echo "Step 4: Deploying frontend..."
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/frontend-service.yaml

echo -e "${YELLOW}⏳${NC} Waiting for frontend to be ready (timeout: 300s)..."
if kubectl wait --for=condition=available deployment/frontend -n names-app --timeout=300s; then
    echo -e "${GREEN}✓${NC} Frontend is ready"
else
    echo -e "${RED}✗${NC} Frontend failed to become ready"
    exit 1
fi

# 5. Deploy HPA (optional)
echo ""
echo "Step 5: Deploying HorizontalPodAutoscaler..."
if [ -f k8s/backend-hpa.yaml ]; then
    kubectl apply -f k8s/backend-hpa.yaml
    echo -e "${GREEN}✓${NC} HPA deployed"
else
    echo -e "${YELLOW}⚠${NC}  HPA manifest not found, skipping"
fi

# Show status
echo ""
echo "=== Deployment Status ==="
kubectl get all -n names-app

# Get NodePort
echo ""
NODEPORT=$(kubectl get svc frontend-service -n names-app -o jsonpath='{.spec.ports[0].nodePort}')
echo -e "${GREEN}✓✓✓ Deployment completed successfully! ✓✓✓${NC}"
echo ""
echo "Application is accessible at: http://localhost:${NODEPORT}"
echo ""
echo "Useful commands:"
echo "  View pods:    kubectl get pods -n names-app"
echo "  View logs:    kubectl logs -n names-app -l app=backend --tail=50 -f"
echo "  Access DB:    kubectl exec -it -n names-app postgres-0 -- psql -U namesuser -d namesdb"
echo "  Health check: curl http://localhost:${NODEPORT}/api/health/db"
