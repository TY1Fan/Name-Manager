#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Cleaning up Names Manager from k3s ==="
echo ""

# Check kubectl access
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to k3s cluster${NC}"
    exit 1
fi

# Prompt for confirmation
read -p "This will delete all resources in the 'names-app' namespace. Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo "Step 1: Deleting HPA..."
kubectl delete hpa backend-hpa -n names-app --ignore-not-found=true
echo -e "${GREEN}✓${NC} HPA deleted"

echo ""
echo "Step 2: Deleting frontend..."
kubectl delete -f k8s/frontend-service.yaml --ignore-not-found=true
kubectl delete -f k8s/frontend-deployment.yaml --ignore-not-found=true
echo -e "${GREEN}✓${NC} Frontend deleted"

echo ""
echo "Step 3: Deleting backend..."
kubectl delete -f k8s/backend-service.yaml --ignore-not-found=true
kubectl delete -f k8s/backend-deployment.yaml --ignore-not-found=true
echo -e "${GREEN}✓${NC} Backend deleted"

echo ""
echo "Step 4: Deleting database..."
kubectl delete -f k8s/database-service.yaml --ignore-not-found=true
kubectl delete -f k8s/database-statefulset.yaml --ignore-not-found=true
echo -e "${GREEN}✓${NC} Database deleted"

echo ""
echo "Step 5: Deleting PVC (this will delete all data)..."
read -p "Delete PersistentVolumeClaim? This will delete all database data! (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete -f k8s/database-pvc.yaml --ignore-not-found=true
    echo -e "${GREEN}✓${NC} PVC deleted"
else
    echo -e "${YELLOW}⚠${NC}  PVC kept (data preserved)"
fi

echo ""
echo "Step 6: Deleting configuration..."
kubectl delete -f k8s/secret.yaml --ignore-not-found=true
kubectl delete -f k8s/configmap.yaml --ignore-not-found=true
echo -e "${GREEN}✓${NC} Configuration deleted"

echo ""
read -p "Delete entire namespace? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete namespace names-app --ignore-not-found=true
    echo -e "${GREEN}✓${NC} Namespace deleted"
else
    echo -e "${YELLOW}⚠${NC}  Namespace kept"
fi

echo ""
echo -e "${GREEN}✓✓✓ Cleanup completed! ✓✓✓${NC}"
echo ""
echo "To verify cleanup:"
echo "  kubectl get all -n names-app"
echo "  kubectl get pvc -n names-app"
