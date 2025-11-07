# Operations Guide - k3s Deployment# Kubernetes Operations Guide - Names Manager



This guide provides comprehensive operational procedures for managing the Names Manager application on k3s.This document provides comprehensive operational procedures for managing the Names Manager application in a k3s Kubernetes environment.



## Table of Contents## Table of Contents



1. [Prerequisites](#prerequisites)1. [Architecture Overview](#architecture-overview)

2. [Common Operations](#common-operations)2. [Deployment Procedures](#deployment-procedures)

3. [Deployment Procedures](#deployment-procedures)3. [Service Management](#service-management)

4. [Monitoring & Health Checks](#monitoring--health-checks)4. [Monitoring & Health Checks](#monitoring--health-checks)

5. [Scaling Operations](#scaling-operations)5. [Scaling Operations](#scaling-operations)

6. [Backup & Restore](#backup--restore)6. [Rolling Updates](#rolling-updates)

7. [Troubleshooting](#troubleshooting)7. [Rollback Procedures](#rollback-procedures)

8. [Emergency Procedures](#emergency-procedures)8. [Backup & Restore](#backup--restore)

9. [Troubleshooting](#troubleshooting)

---10. [Common Issues & Solutions](#common-issues--solutions)



## Prerequisites---



### Access Requirements## Architecture Overview

- SSH access to k3s VMs (k3s-server, k3s-agent)

- kubectl configured with k3s cluster access### Environment Structure

- Port forwarding configured: `127.0.0.1:6443 -> 192.168.56.10:6443`

**Local Development (Single-Host):**

### Verify Access- Uses `src/docker-compose.yml`

```bash- All services on one machine

# Check cluster access- Port: 8080

kubectl cluster-info- Storage: Docker volume



# Check node status**Production (Multi-Host Swarm):**

kubectl get nodes- Uses `swarm/stack.yaml`

- 2 VMs: manager (192.168.56.10) + worker (192.168.56.11)

# Expected output:- Port: 8081 (forwarded from manager VM port 80)

# k3s-server   Ready    control-plane,master   <age>- Storage: Bind mount at `/var/lib/postgres-data` on worker

# k3s-agent    Ready    <none>                 <age>

```### Service Placement



---| Service | Replicas | Node | Constraint |

|---------|----------|------|------------|

## Common Operations| `names_db` | 1 | Worker | `node.labels.role == db` |

| `names_api` | 2 | Manager | `node.role == manager` |

### Viewing Application Status| `names_web` | 1 | Manager | `node.role == manager` |



```bash### Network Architecture

# View all resources in names-app namespace

kubectl get all -n names-app- **Overlay Network**: `appnet` (10.0.1.0/24)

- **DNS**: Automatic service discovery

# View pods with more details- **Ingress**: Port 80 published on manager

kubectl get pods -n names-app -o wide

---

# View persistent volumes

kubectl get pvc -n names-app## Deployment Procedures

kubectl get pv

```### Initial Deployment (From Scratch)



### Accessing Logs```bash

# 1. Start Virtual Machines

```bashvagrant up

# View backend logs

kubectl logs -n names-app deployment/backend --tail=100 -f# 2. Initialize Swarm Cluster

./ops/init-swarm.sh

# View specific pod logs

kubectl logs -n names-app <pod-name> --tail=100 -f# Expected output:

# - Swarm initialized on manager

# View database logs# - Worker joined to Swarm

kubectl logs -n names-app postgres-0 --tail=100 -f# - Worker labeled with role=db

# - Overlay network 'appnet' created

# View frontend logs# - Storage directory created on worker

kubectl logs -n names-app deployment/frontend --tail=100 -f

# 3. Deploy Application

# View logs from all backend pods./ops/deploy.sh

kubectl logs -n names-app -l app=backend --tail=50

```# Expected output:

# - Images built (backend + frontend)

### Executing Commands in Pods# - Images transferred to manager

# - Stack deployed

```bash# - Services: api (2/2), db (1/1), web (1/1)

# Connect to database

kubectl exec -it -n names-app postgres-0 -- psql -U namesuser -d namesdb# 4. Verify Deployment

./ops/verify.sh

# Execute SQL query

kubectl exec -it -n names-app postgres-0 -- psql -U namesuser -d namesdb -c "SELECT * FROM names;"# Expected output:

# - All 10 checks passed

# Shell access to backend pod# - Application accessible at http://localhost:8081

kubectl exec -it -n names-app deployment/backend -- /bin/sh```



# Shell access to frontend pod### Redeployment (Update Existing)

kubectl exec -it -n names-app deployment/frontend -- /bin/sh

``````bash

# Redeploy with latest code changes

### Resource Usage./ops/deploy.sh



```bash# This will:

# View node resource usage# - Rebuild images with latest code

kubectl top nodes# - Transfer new images to manager

# - Update services (rolling update)

# View pod resource usage# - Maintain data persistence

kubectl top pods -n names-app```



# View resource limits and requests---

kubectl describe pod <pod-name> -n names-app | grep -A 5 "Limits\|Requests"

```## Service Management



---### View Service Status



## Deployment Procedures```bash

# List all services

### Initial Deploymentvagrant ssh manager -c "docker stack services names"



```bash# View specific service details

# 1. Create namespace and configurationvagrant ssh manager -c "docker service ps names_api"

kubectl apply -f k8s/namespace.yamlvagrant ssh manager -c "docker service ps names_db"

kubectl apply -f k8s/configmap.yamlvagrant ssh manager -c "docker service ps names_web"

kubectl apply -f k8s/secret.yaml

# Inspect service configuration

# 2. Deploy databasevagrant ssh manager -c "docker service inspect names_api"

kubectl apply -f k8s/database-pvc.yaml```

kubectl apply -f k8s/database-statefulset.yaml

kubectl apply -f k8s/database-service.yaml### Service Logs



# Wait for database to be ready```bash

kubectl wait --for=condition=ready pod/postgres-0 -n names-app --timeout=300s# View logs for a service

vagrant ssh manager -c "docker service logs names_api"

# 3. Deploy backendvagrant ssh manager -c "docker service logs names_db"

kubectl apply -f k8s/backend-deployment.yamlvagrant ssh manager -c "docker service logs names_web"

kubectl apply -f k8s/backend-service.yaml

# Follow logs in real-time

# Wait for backend to be readyvagrant ssh manager -c "docker service logs -f names_api"

kubectl wait --for=condition=available deployment/backend -n names-app --timeout=300s

# View last N lines

# 4. Deploy frontendvagrant ssh manager -c "docker service logs --tail 50 names_api"

kubectl apply -f k8s/frontend-deployment.yaml

kubectl apply -f k8s/frontend-service.yaml# View logs since timestamp

vagrant ssh manager -c "docker service logs --since 10m names_api"

# Wait for frontend to be ready```

kubectl wait --for=condition=available deployment/frontend -n names-app --timeout=300s

### Restart Services

# 5. Deploy HPA (optional)

kubectl apply -f k8s/backend-hpa.yaml```bash

# Force restart a service (refreshes containers)

# 6. Verify deploymentvagrant ssh manager -c "docker service update --force names_api"

kubectl get all -n names-appvagrant ssh manager -c "docker service update --force names_db"

```vagrant ssh manager -c "docker service update --force names_web"



### Updating Application# Note: Use --force when database connections are stale

```

```bash

# Update backend image---

kubectl set image deployment/backend backend=localhost/names-backend:latest -n names-app

## Monitoring & Health Checks

# Update frontend image

kubectl set image deployment/frontend frontend=localhost/names-frontend:latest -n names-app### Application Health Checks



# Monitor rollout status```bash

kubectl rollout status deployment/backend -n names-app# Basic API health

kubectl rollout status deployment/frontend -n names-appcurl http://localhost:8081/api/health

# Expected: {"status":"ok"}

# Rollback if needed

kubectl rollout undo deployment/backend -n names-app# Database connectivity health

kubectl rollout history deployment/backend -n names-appcurl http://localhost:8081/api/health/db

```# Expected: {"status":"healthy", "database":"connected", ...}



### Restarting Services# Test data operations

curl http://localhost:8081/api/names

```bash# Expected: {"names":[...]}

# Restart backend deployment```

kubectl rollout restart deployment/backend -n names-app

### Service Health Status

# Restart frontend deployment

kubectl rollout restart deployment/frontend -n names-app```bash

# Check if all services are running

# Restart database (careful - may cause brief downtime)vagrant ssh manager -c "docker stack ps names --filter 'desired-state=running'"

kubectl delete pod postgres-0 -n names-app

# StatefulSet will automatically recreate it# Check for failed services

```vagrant ssh manager -c "docker stack ps names --filter 'desired-state=shutdown'"



---# View service events

vagrant ssh manager -c "docker service ps names_api --no-trunc"

## Monitoring & Health Checks```



### Health Endpoints### Database Health



```bash```bash

# Check backend health# PostgreSQL health check

curl http://localhost:30080/api/healthvagrant ssh worker -c "docker exec \$(docker ps -q -f name=names_db) pg_isready -U names_user -d namesdb"

# Expected: /var/run/postgresql:5432 - accepting connections

# Check database connectivity

curl http://localhost:30080/api/health/db# Check database connections

vagrant ssh worker -c "docker exec \$(docker ps -q -f name=names_db) psql -U names_user -d namesdb -c 'SELECT count(*) FROM names;'"

# Check liveness probe```

kubectl exec -n names-app deployment/backend -- curl -f http://localhost:8000/healthz

### Network Connectivity

# Check readiness probe

kubectl exec -n names-app deployment/backend -- curl -f http://localhost:8000/api/health/db```bash

```# Test DNS resolution

vagrant ssh manager -c "docker exec \$(docker ps -q -f name=names_api | head -1) python -c 'import socket; print(socket.gethostbyname(\"names_db\"))'"

### Pod Status

# Test cross-VM connectivity

```bashvagrant ssh manager -c "docker exec \$(docker ps -q -f name=names_api | head -1) python -c 'import psycopg2; conn = psycopg2.connect(\"postgresql://names_user:names_pass@db:5432/namesdb\"); print(\"Connected!\")'"

# Check pod status```

kubectl get pods -n names-app

### Resource Usage

# Describe pod for events

kubectl describe pod <pod-name> -n names-app```bash

# Check node resources

# Check pod eventsvagrant ssh manager -c "docker node ls"

kubectl get events -n names-app --sort-by='.lastTimestamp'vagrant ssh manager -c "docker node inspect swarm-manager --format '{{.Status}}'"



# Check container restart count# Check service resource usage (requires metrics)

kubectl get pods -n names-app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'vagrant ssh manager -c "docker stats --no-stream"

``````



### Service Connectivity---



```bash## Scaling Operations

# Test service connectivity from within cluster

kubectl run test-pod --rm -it --image=busybox -n names-app -- sh### Scale Services

# Inside pod:

# wget -O- http://api-service:5000/api/health```bash

# wget -O- http://db-service:5432# Scale API service to 3 replicas

vagrant ssh manager -c "docker service scale names_api=3"

# Check service endpoints

kubectl get endpoints -n names-app# Scale down to 1 replica

```vagrant ssh manager -c "docker service scale names_api=1"



---# Note: Database should remain at 1 replica (stateful service)



## Scaling Operations# Verify scaling

vagrant ssh manager -c "docker service ps names_api"

### Manual Scaling```



```bash### Auto-Scaling Considerations

# Scale backend deployment

kubectl scale deployment/backend --replicas=3 -n names-appThe current setup does not include auto-scaling. For production:

- Consider Docker Swarm mode's `--replicas-max-per-node`

# Scale frontend deployment- Implement external monitoring (Prometheus + Grafana)

kubectl scale deployment/frontend --replicas=2 -n names-app- Use horizontal pod autoscaling based on CPU/memory



# Verify scaling---

kubectl get pods -n names-app -l app=backend

```## Rolling Updates



### Horizontal Pod Autoscaler (HPA)### Update Application Code



```bash```bash

# View HPA status# 1. Make code changes in src/backend/ or src/frontend/

kubectl get hpa -n names-app

# 2. Deploy with rolling update (default behavior)

# Describe HPA./ops/deploy.sh

kubectl describe hpa backend-hpa -n names-app

# Rolling update configuration in stack.yaml:

# Watch autoscaling in real-time# - parallelism: 1 (update one replica at a time)

kubectl get hpa -n names-app --watch# - delay: 10s (wait between updates)

# - failure_action: rollback (automatic rollback on failure)

# Edit HPA configuration```

kubectl edit hpa backend-hpa -n names-app

### Update Configuration

# Delete HPA

kubectl delete hpa backend-hpa -n names-app```bash

```# Update environment variables

vagrant ssh manager -c "docker service update --env-add NEW_VAR=value names_api"

---

# Update image version

## Backup & Restorevagrant ssh manager -c "docker service update --image localhost/names-backend:v2 names_api"

```

### Database Backup

### Monitor Update Progress

```bash

# Create database backup```bash

kubectl exec -n names-app postgres-0 -- pg_dump -U namesuser namesdb > backup-$(date +%Y%m%d-%H%M%S).sql# Watch update progress

vagrant ssh manager -c "watch docker service ps names_api"

# Backup to file inside pod then copy out

kubectl exec -n names-app postgres-0 -- pg_dump -U namesuser namesdb > /tmp/backup.sql# Check update status

kubectl cp names-app/postgres-0:/tmp/backup.sql ./backup.sqlvagrant ssh manager -c "docker service inspect names_api --format '{{.UpdateStatus}}'"

```

# View backup

head -20 backup.sql---

```

## Rollback Procedures

### Database Restore

### Automatic Rollback

```bash

# Copy backup file to podThe stack is configured with automatic rollback on failure:

kubectl cp ./backup.sql names-app/postgres-0:/tmp/backup.sql```yaml

rollback_config:

# Restore database  parallelism: 1

kubectl exec -it -n names-app postgres-0 -- psql -U namesuser -d namesdb -f /tmp/backup.sql  delay: 10s

```

# Or pipe directly

cat backup.sql | kubectl exec -i -n names-app postgres-0 -- psql -U namesuser -d namesdb### Manual Rollback

```

```bash

### Configuration Backup# Rollback to previous version

vagrant ssh manager -c "docker service rollback names_api"

```bash

# Backup all k8s manifests# Check rollback status

kubectl get all -n names-app -o yaml > names-app-backup.yamlvagrant ssh manager -c "docker service ps names_api"



# Backup specific resources# View service history

kubectl get configmap names-app-config -n names-app -o yaml > configmap-backup.yamlvagrant ssh manager -c "docker service ps names_api --no-trunc"

kubectl get secret db-credentials -n names-app -o yaml > secret-backup.yaml```

kubectl get pvc postgres-pvc -n names-app -o yaml > pvc-backup.yaml

```### Complete Stack Rollback



### Persistent Volume Backup```bash

# 1. Remove current stack

```bash./ops/cleanup.sh

# SSH to k3s-server

vagrant ssh k3s-server# 2. Restore previous stack.yaml version

git checkout HEAD~1 swarm/stack.yaml

# Locate PV data

sudo ls -la /var/lib/rancher/k3s/storage/# 3. Redeploy

./ops/deploy.sh

# Backup PV data (requires root)

sudo tar czf /vagrant/pv-backup-$(date +%Y%m%d).tar.gz /var/lib/rancher/k3s/storage/pvc-*# 4. Restore to latest

```git checkout swarm/stack.yaml

```

---

---

## Troubleshooting

## Backup & Restore

### Pod Not Starting

### Database Backup

```bash

# Check pod status and events```bash

kubectl describe pod <pod-name> -n names-app# Create backup

vagrant ssh worker -c "docker exec \$(docker ps -q -f name=names_db) pg_dump -U names_user namesdb > /home/vagrant/backup_\$(date +%Y%m%d_%H%M%S).sql"

# Common issues:

# 1. Image pull errors# Copy backup to host

kubectl get pods -n names-appvagrant scp worker:/home/vagrant/backup_*.sql ./backups/

# Look for ImagePullBackOff or ErrImagePull

# Backup data directory

# 2. Resource constraintsvagrant ssh worker -c "sudo tar czf /home/vagrant/postgres-data-backup.tar.gz /var/lib/postgres-data"

kubectl describe nodes```

# Check for resource pressure

### Database Restore

# 3. Volume mount issues

kubectl get pvc -n names-app```bash

kubectl describe pvc postgres-pvc -n names-app# Copy backup to worker

```vagrant scp ./backups/backup_20251030.sql worker:/home/vagrant/



### Database Connection Issues# Restore database

vagrant ssh worker -c "cat backup_20251030.sql | docker exec -i \$(docker ps -q -f name=names_db) psql -U names_user -d namesdb"

```bash

# Check database pod is running# Verify restore

kubectl get pod postgres-0 -n names-appcurl http://localhost:8081/api/names

```

# Check database service

kubectl get svc db-service -n names-app### Complete System Backup



# Test database connectivity from backend pod```bash

kubectl exec -it -n names-app deployment/backend -- sh# Backup includes:

# nc -zv db-service 5432# 1. Stack configuration

# orcp swarm/stack.yaml backups/stack.yaml.$(date +%Y%m%d)

# wget -O- http://db-service:5432 || echo "Connection works"

# 2. Database data

# Check database logsvagrant ssh worker -c "sudo tar czf /home/vagrant/postgres-backup.tar.gz /var/lib/postgres-data"

kubectl logs -n names-app postgres-0 --tail=50vagrant scp worker:/home/vagrant/postgres-backup.tar.gz ./backups/



# Verify credentials# 3. Docker images (optional)

kubectl get secret db-credentials -n names-app -o jsonpath='{.data.POSTGRES_USER}' | base64 -ddocker save localhost/names-backend:latest | gzip > backups/backend.tar.gz

kubectl get secret db-credentials -n names-app -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -ddocker save localhost/names-frontend:latest | gzip > backups/frontend.tar.gz

``````



### Backend API Not Responding---



```bash## Troubleshooting

# Check backend pod status

kubectl get pods -n names-app -l app=backend### Services Not Starting



# Check backend logs**Symptoms**: Service replicas showing 0/N

kubectl logs -n names-app deployment/backend --tail=100

```bash

# Check backend service# 1. Check service logs

kubectl get svc api-service -n names-appvagrant ssh manager -c "docker service logs names_api"

kubectl describe svc api-service -n names-app

# 2. Check for errors

# Test backend healthvagrant ssh manager -c "docker service ps names_api --no-trunc"

kubectl exec -n names-app deployment/backend -- curl -f http://localhost:8000/healthz

kubectl exec -n names-app deployment/backend -- curl -f http://localhost:8000/api/health/db# 3. Verify image exists

vagrant ssh manager -c "docker images | grep names"

# Check environment variables

kubectl exec -n names-app deployment/backend -- env | grep DB_# 4. Check node availability

```vagrant ssh manager -c "docker node ls"



### Frontend Not Loading# Common fixes:

# - Restart service: docker service update --force names_api

```bash# - Rebuild and redeploy: ./ops/deploy.sh

# Check frontend pod status```

kubectl get pods -n names-app -l app=frontend

### Database Connection Errors

# Check frontend logs

kubectl logs -n names-app deployment/frontend --tail=50**Symptoms**: API shows "server closed the connection unexpectedly"



# Check NodePort service```bash

kubectl get svc frontend-service -n names-app# 1. Check database health

# Verify NodePort is 30080vagrant ssh worker -c "docker exec \$(docker ps -q -f name=names_db) pg_isready -U names_user -d namesdb"



# Test from host# 2. Restart API to refresh connections

curl -I http://localhost:30080vagrant ssh manager -c "docker service update --force names_api"



# Check nginx configuration# 3. Check database logs

kubectl exec -n names-app deployment/frontend -- cat /etc/nginx/conf.d/default.confvagrant ssh manager -c "docker service logs names_db"

```

# 4. Verify DNS resolution

### Resource Exhaustionvagrant ssh manager -c "docker exec \$(docker ps -q -f name=names_api | head -1) nslookup names_db"

```

```bash

# Check node resources### Network Issues

kubectl top nodes

kubectl describe nodes**Symptoms**: Services can't communicate



# Check pod resources```bash

kubectl top pods -n names-app# 1. Verify overlay network

vagrant ssh manager -c "docker network ls | grep appnet"

# Check for evicted podsvagrant ssh manager -c "docker network inspect appnet"

kubectl get pods -n names-app | grep Evicted

# 2. Check service network connectivity

# Clean up evicted podsvagrant ssh manager -c "docker exec \$(docker ps -q -f name=names_api | head -1) ping -c 3 names_db"

kubectl delete pod --field-selector=status.phase=Failed -n names-app

```# 3. Recreate network if needed

vagrant ssh manager -c "docker network rm appnet"

### Network Issues./ops/init-swarm.sh

```

```bash

# Check network policies### Port Conflicts

kubectl get networkpolicies -n names-app

**Symptoms**: "port is already allocated"

# Test pod-to-pod communication

kubectl run test-pod --rm -it --image=busybox -n names-app -- sh```bash

# wget -O- http://api-service:5000/api/health# 1. Check what's using the port

# wget -O- http://db-service:5432vagrant ssh manager -c "sudo lsof -i :80"



# Check CoreDNS# 2. Stop conflicting service

kubectl get pods -n kube-system -l k8s-app=kube-dnsvagrant ssh manager -c "docker service rm <conflicting-service>"



# Test DNS resolution# 3. Redeploy

kubectl exec -n names-app deployment/backend -- nslookup db-service./ops/deploy.sh

kubectl exec -n names-app deployment/backend -- nslookup api-service```

```

### Storage Issues

---

**Symptoms**: Database fails to start, permission errors

## Emergency Procedures

```bash

### Complete Application Restart# 1. Check storage directory

vagrant ssh worker -c "sudo ls -ld /var/lib/postgres-data"

```bash

# 1. Scale down deployments# 2. Check permissions (should be 700, 999:999)

kubectl scale deployment/backend --replicas=0 -n names-appvagrant ssh worker -c "sudo stat -c '%a %u %g' /var/lib/postgres-data"

kubectl scale deployment/frontend --replicas=0 -n names-app

# 3. Fix permissions

# 2. Wait for pods to terminatevagrant ssh worker -c "sudo chmod 700 /var/lib/postgres-data"

kubectl get pods -n names-app --watchvagrant ssh worker -c "sudo chown 999:999 /var/lib/postgres-data"



# 3. Restart database if needed# 4. Restart database

kubectl delete pod postgres-0 -n names-appvagrant ssh manager -c "docker service update --force names_db"

kubectl wait --for=condition=ready pod/postgres-0 -n names-app --timeout=300s```



# 4. Scale up deployments---

kubectl scale deployment/backend --replicas=2 -n names-app

kubectl scale deployment/frontend --replicas=1 -n names-app## Common Issues & Solutions



# 5. Verify### Issue: "Swarm not initialized"

kubectl get all -n names-app

```**Solution**:

```bash

### Complete Cleanup & Redeploy./ops/init-swarm.sh

```

```bash

# 1. Delete all application resources### Issue: "Images not found on manager"

kubectl delete namespace names-app

**Solution**:

# 2. Wait for namespace deletion```bash

kubectl get namespaces --watch# Rebuild and transfer images

./ops/deploy.sh

# 3. Redeploy from scratch```

kubectl apply -f k8s/namespace.yaml

kubectl apply -f k8s/configmap.yaml### Issue: "Worker not joining swarm"

kubectl apply -f k8s/secret.yaml

kubectl apply -f k8s/database-pvc.yaml**Solution**:

kubectl apply -f k8s/database-statefulset.yaml```bash

kubectl apply -f k8s/database-service.yaml# Leave and rejoin

kubectl wait --for=condition=ready pod/postgres-0 -n names-app --timeout=300svagrant ssh worker -c "docker swarm leave"

kubectl apply -f k8s/backend-deployment.yaml./ops/init-swarm.sh

kubectl apply -f k8s/backend-service.yaml```

kubectl apply -f k8s/frontend-deployment.yaml

kubectl apply -f k8s/frontend-service.yaml### Issue: "Data lost after stack removal"

kubectl apply -f k8s/backend-hpa.yaml

```**Explanation**: By design, `./ops/cleanup.sh` preserves data in `/var/lib/postgres-data`



### Database Recovery**Verification**:

```bash

```bashvagrant ssh worker -c "sudo ls -lh /var/lib/postgres-data"

# If database is corrupted or not starting:```



# 1. Backup current state (if possible)### Issue: "Port 8081 not accessible"

kubectl exec -n names-app postgres-0 -- pg_dump -U namesuser namesdb > emergency-backup.sql 2>/dev/null || true

**Solution**:

# 2. Delete database pod and PVC```bash

kubectl delete pod postgres-0 -n names-app# 1. Verify Vagrant port forwarding

kubectl delete pvc postgres-pvc -n names-appvagrant port manager



# 3. Recreate PVC and StatefulSet# 2. Check service is running

kubectl apply -f k8s/database-pvc.yamlvagrant ssh manager -c "curl localhost/api/health"

kubectl apply -f k8s/database-statefulset.yaml

# 3. Restart Vagrant networking

# 4. Wait for pod to be readyvagrant reload

kubectl wait --for=condition=ready pod/postgres-0 -n names-app --timeout=300s```



# 5. Restore from backup if available### Issue: "Services on wrong nodes"

cat emergency-backup.sql | kubectl exec -i -n names-app postgres-0 -- psql -U namesuser -d namesdb

```**Solution**:

```bash

### Node Failure Recovery# 1. Verify node labels

vagrant ssh manager -c "docker node inspect swarm-worker --format '{{.Spec.Labels}}'"

```bash

# Check node status# 2. Re-label if needed

kubectl get nodesvagrant ssh manager -c "docker node update --label-add role=db swarm-worker"



# If k3s-server is down:# 3. Force service update

vagrant ssh k3s-servervagrant ssh manager -c "docker service update --force names_db"

sudo systemctl status k3s```

sudo systemctl restart k3s

exit### Issue: "Stack deployment fails"



# If k3s-agent is down:**Solution**:

vagrant ssh k3s-agent```bash

sudo systemctl status k3s-agent# 1. Check stack file syntax

sudo systemctl restart k3s-agentvagrant ssh manager -c "docker stack config -c /vagrant/swarm/stack.yaml"

exit

# 2. Verify network exists

# Check pod status after node recoveryvagrant ssh manager -c "docker network ls | grep appnet"

kubectl get pods -n names-app -o wide

# 3. Check for conflicting stacks

# Pods should automatically reschedule if nodes come backvagrant ssh manager -c "docker stack ls"

```

# 4. Remove and redeploy

---./ops/cleanup.sh

./ops/deploy.sh

## Quick Reference```



### Key Commands---



```bash## Quick Reference

# View everything

kubectl get all -n names-app### Essential Commands



# Application URL```bash

http://localhost:30080# Deployment

./ops/init-swarm.sh    # Initialize cluster (first time)

# View logs (all backends)./ops/deploy.sh        # Deploy/update application

kubectl logs -n names-app -l app=backend --tail=50./ops/verify.sh        # Verify deployment

./ops/cleanup.sh       # Remove stack

# Database access

kubectl exec -it -n names-app postgres-0 -- psql -U namesuser -d namesdb# Monitoring

curl http://localhost:8081/api/health

# Restart backendvagrant ssh manager -c "docker stack services names"

kubectl rollout restart deployment/backend -n names-appvagrant ssh manager -c "docker service logs names_api"



# Backup database# Troubleshooting

kubectl exec -n names-app postgres-0 -- pg_dump -U namesuser namesdb > backup.sqlvagrant ssh manager -c "docker service ps names_api --no-trunc"

vagrant ssh manager -c "docker node ls"

# Check healthvagrant ssh worker -c "docker ps"

curl http://localhost:30080/api/health/db

```# Cleanup

./ops/cleanup.sh                                    # Remove stack only

### Useful Aliasesvagrant ssh worker -c "sudo rm -rf /var/lib/postgres-data"  # Remove data

vagrant destroy -f                                  # Destroy VMs

Add these to your `~/.zshrc` or `~/.bashrc`:```



```bash---

# kubectl shortcuts

alias k='kubectl'## Support & Additional Resources

alias kn='kubectl config set-context --current --namespace'

alias kga='kubectl get all'- **Project README**: `README.md`

alias kgp='kubectl get pods'- **Task Specifications**: `spec/40-tasks.md`

alias kgs='kubectl get svc'- **Operations Scripts**: `ops/` directory

alias kdp='kubectl describe pod'- **Stack Configuration**: `swarm/stack.yaml`

alias kl='kubectl logs'- **Compose File**: `src/docker-compose.yml`



# names-app specificFor issues not covered in this guide, check service logs and the troubleshooting section above.

alias knames='kubectl get all -n names-app'
alias knames-logs='kubectl logs -n names-app -l app=backend --tail=100 -f'
alias knames-db='kubectl exec -it -n names-app postgres-0 -- psql -U namesuser -d namesdb'
```

---

## Support & Maintenance

### Regular Maintenance Tasks

1. **Weekly**:
   - Review pod logs for errors
   - Check resource usage trends
   - Verify backup procedures

2. **Monthly**:
   - Review and update resource limits
   - Check for k3s updates
   - Test disaster recovery procedures

3. **Quarterly**:
   - Review and update documentation
   - Security audit
   - Performance optimization review

### Monitoring Checklist

- [ ] All pods running and ready
- [ ] No excessive restarts
- [ ] Resource usage within limits
- [ ] Disk space adequate
- [ ] Health endpoints responding
- [ ] HPA functioning correctly
- [ ] Logs show no persistent errors

---

**Last Updated**: 2025-11-05  
**k3s Version**: v1.33.5+k3s1  
**Application**: Names Manager v1.0
