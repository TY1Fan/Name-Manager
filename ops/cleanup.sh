#!/bin/bash
# ops/cleanup.sh - Clean up Swarm deployment

echo "=== Names Manager Cleanup ==="
echo ""
echo "This script will remove the deployed stack."
echo "Data in /var/lib/postgres-data on worker will be preserved."
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Remove stack
echo "Removing stack 'names'..."
if vagrant ssh manager -c "docker stack rm names"; then
    echo "✓ Stack removal initiated"
else
    echo "✗ Stack not deployed or already removed"
fi

echo "Waiting for services to stop..."
sleep 15

# Verify stack is gone
echo ""
echo "Verifying removal..."
REMAINING=$(vagrant ssh manager -c "docker stack ls | grep -c names" 2>/dev/null || echo "0")
if [ "$REMAINING" -eq 0 ]; then
    echo "✓ Stack removed successfully"
else
    echo "⚠ Stack still removing... (check with: docker stack ps names)"
fi

# Show remaining resources
echo ""
echo "Remaining Docker resources:"
echo ""
echo "Overlay network:"
vagrant ssh manager -c "docker network ls | grep appnet" || echo "  (network removed)"

echo ""
echo "Persistent storage:"
vagrant ssh worker -c "sudo ls -ldh /var/lib/postgres-data 2>/dev/null" && \
vagrant ssh worker -c "sudo du -sh /var/lib/postgres-data 2>/dev/null" || \
echo "  (storage directory not found)"

echo ""
echo "Docker images:"
vagrant ssh manager -c "docker images | grep names" || echo "  (no images found)"

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Stack removed. Persistent data and infrastructure preserved."
echo ""
echo "To fully reset (WARNING: destroys data):"
echo "  - Remove data:       vagrant ssh worker -c 'sudo rm -rf /var/lib/postgres-data'"
echo "  - Remove network:    vagrant ssh manager -c 'docker network rm appnet'"
echo "  - Remove images:     vagrant ssh manager -c 'docker rmi localhost/names-backend:latest localhost/names-frontend:latest'"
echo "  - Leave Swarm:       vagrant ssh worker -c 'docker swarm leave'"
echo "  - Leave Swarm:       vagrant ssh manager -c 'docker swarm leave --force'"
echo "  - Destroy VMs:       vagrant destroy -f"
echo ""
echo "To redeploy:           ./ops/deploy.sh"
echo "To reinitialize:       ./ops/init-swarm.sh"
