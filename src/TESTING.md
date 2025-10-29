# End-to-End Integration Testing

This document describes the complete end-to-end integration testing procedures for the Docker Swarm deployment of the Names Manager application, along with test results and findings.

## Document Status

- **Created**: October 29, 2025
- **Last Updated**: October 29, 2025
- **Test Status**: Ready for Execution
- **Tester**: _To be filled_
- **Test Environment**: macOS with Docker Desktop, Vagrant, VirtualBox

## Test Objectives

Validate the complete Docker Swarm deployment workflow from initialization through cleanup, ensuring:
1. All automation scripts work correctly
2. Application functions properly in Swarm mode
3. Data persistence works across service restarts
4. High availability features function as expected
5. Cleanup procedures work safely

## Prerequisites

Before starting tests, ensure:
- [ ] Docker Desktop installed and running
- [ ] Vagrant installed (version 2.0+)
- [ ] VirtualBox installed (version 6.0+)
- [ ] Git repository cloned
- [ ] No existing Swarm cluster running
- [ ] Vagrant VM not running
- [ ] Port 80 available on host

## Test Environment Setup

### Initial State Verification

```bash
# Verify Docker is running
docker info

# Verify Vagrant is installed
vagrant --version

# Verify VirtualBox is installed
VBoxManage --version

# Verify no Swarm cluster exists
docker info | grep "Swarm:"
# Expected: "Swarm: inactive"

# Verify no Vagrant VM running
cd vagrant
vagrant status
# Expected: "not created" or "poweroff"
cd ..

# Verify port 80 is available
lsof -i :80
# Expected: (empty output)
```

---

## Test Suite

### Test 1: Fresh Swarm Initialization

**Objective**: Verify `ops/init-swarm.sh` completes successfully from clean state

**Acceptance Criteria**:
- [ ] Script runs without errors
- [ ] Vagrant VM starts successfully
- [ ] Swarm cluster initialized on manager node
- [ ] Worker node joins cluster
- [ ] Persistent storage directory created
- [ ] Exit code is 0

**Test Procedure**:
```bash
# Start from clean state
./ops/cleanup.sh --full --yes  # If already running

# Run initialization
./ops/init-swarm.sh

# Expected output should show:
# ✅ Vagrant prerequisites check passed
# ✅ VirtualBox prerequisites check passed
# ✅ Docker prerequisites check passed
# ✅ Vagrant VM is running
# ✅ Docker Swarm initialized
# ✅ Worker node joined Swarm
# ✅ Persistent storage created
# ✅ Swarm cluster is ready
```

**Verification Commands**:
```bash
# Check Swarm status
docker info | grep "Swarm:"
# Expected: "Swarm: active"

# Check nodes
docker node ls
# Expected: 2 nodes (1 manager, 1 worker)

# Check worker node storage
cd vagrant
vagrant ssh -c "ls -la /var/lib/postgres-data"
# Expected: Directory exists with correct permissions
cd ..
```

**Test Results**:
- [ ] ✅ PASS
- [ ] ❌ FAIL - _Reason:_
- **Duration**: ___ minutes
- **Notes**:

---

### Test 2: Stack Deployment

**Objective**: Verify `ops/deploy.sh` deploys stack without errors

**Acceptance Criteria**:
- [ ] Script validates environment
- [ ] Stack deploys successfully
- [ ] All services start within timeout
- [ ] Services achieve ready state (1/1)
- [ ] Exit code is 0

**Test Procedure**:
```bash
# Ensure .env file is configured
cd src
cp .env.example .env
# Edit .env with appropriate values
cd ..

# Deploy stack
./ops/deploy.sh

# Expected output should show:
# ✅ Docker Swarm is active with 2 nodes
# ✅ Stack file found
# ✅ .env file found
# ✅ All required environment variables are set
# ✅ Required Docker images are available
# ✅ Stack deployment command executed successfully
# ✅ All services are ready!
# 🎉 Deployment Complete!
```

**Verification Commands**:
```bash
# Check stack
docker stack ls
# Expected: names-app with 3 services

# Check services
docker stack services names-app
# Expected: All services show 1/1 replicas

# Check service placement
docker stack ps names-app
# Expected: db on worker, frontend/backend on manager
```

**Test Results**:
- [ ] ✅ PASS
- [ ] ❌ FAIL - _Reason:_
- **Duration**: ___ minutes
- **Notes**:

---

### Test 3: Deployment Verification

**Objective**: Verify `ops/verify.sh` passes all checks

**Acceptance Criteria**:
- [ ] All 9 verification checks pass
- [ ] Docker Swarm is active
- [ ] Stack exists with 3 services
- [ ] Service replicas are ready
- [ ] Service placement is correct
- [ ] Database health check passes
- [ ] Backend health endpoint responds
- [ ] Frontend is accessible
- [ ] Service discovery works
- [ ] Exit code is 0

**Test Procedure**:
```bash
# Run verification
./ops/verify.sh

# Expected output should show:
# ✅ PASS: Docker daemon is running
# ✅ PASS: Docker Swarm is active with 2 nodes
# ✅ PASS: Stack 'names-app' exists with 3 services
# ✅ PASS: All services have ready replicas
# ✅ PASS: All services are placed on correct nodes
# ✅ PASS: Database is accepting connections
# ✅ PASS: Backend health endpoint returns healthy status
# ✅ PASS: Frontend is accessible and returns HTTP 200
# ✅ PASS: Backend can reach database via service discovery
# 
# Total Checks: 9
# Passed: 9
# Failed: 0
# 
# 🎉 All checks passed!
```

**Verification Commands**:
```bash
# Manual verification
curl -I http://localhost
# Expected: HTTP/1.1 200 OK

curl http://localhost/api/health | jq
# Expected: JSON with status information

curl http://localhost/healthz | jq
# Expected: {"status":"ok"}
```

**Test Results**:
- [ ] ✅ PASS
- [ ] ❌ FAIL - _Reason:_
- **Duration**: ___ seconds
- **Notes**:

---

### Test 4: Web UI Functionality

**Objective**: Verify application functionality through web interface

**Acceptance Criteria**:
- [ ] Can access frontend on http://localhost
- [ ] Can add new names
- [ ] Names appear in list
- [ ] Can delete names
- [ ] Changes persist immediately

**Test Procedure**:
```bash
# Open browser
open http://localhost

# Or use curl to test API directly
# Add a name
curl -X POST http://localhost/api/names \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User 1"}'
# Expected: {"id":1,"name":"Test User 1"}

# Add another name
curl -X POST http://localhost/api/names \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User 2"}'

# List all names
curl http://localhost/api/names | jq
# Expected: Array with 2 names

# Delete a name
curl -X DELETE http://localhost/api/names/1

# Verify deletion
curl http://localhost/api/names | jq
# Expected: Array with 1 name (Test User 2)
```

**Manual Testing Steps**:
1. Open http://localhost in browser
2. Verify page loads and shows "Names Manager"
3. Add a name using the form
4. Verify name appears in the list
5. Add 2-3 more names
6. Delete one name
7. Verify name is removed from list
8. Refresh page and verify names persist

**Test Results**:
- [ ] ✅ PASS
- [ ] ❌ FAIL - _Reason:_
- **Duration**: ___ minutes
- **Screenshots**: _Attach if available_
- **Notes**:

---

### Test 5: Data Persistence - Service Restart

**Objective**: Verify data persists when services restart

**Acceptance Criteria**:
- [ ] Names added before restart are present after
- [ ] Service restarts successfully
- [ ] No data loss occurs
- [ ] Application remains functional

**Test Procedure**:
```bash
# Add test data
curl -X POST http://localhost/api/names \
  -H "Content-Type: application/json" \
  -d '{"name":"Persistence Test 1"}'

curl -X POST http://localhost/api/names \
  -H "Content-Type: application/json" \
  -d '{"name":"Persistence Test 2"}'

# Verify data exists
curl http://localhost/api/names | jq
# Note the IDs and names

# Restart backend service
docker service update --force names-app_backend

# Wait for service to restart
sleep 10

# Verify data still exists
curl http://localhost/api/names | jq
# Expected: Same names with same IDs

# Restart database service
docker service update --force names-app_db

# Wait for service to restart (longer for database)
sleep 20

# Verify data still exists
curl http://localhost/api/names | jq
# Expected: Same names with same IDs
```

**Verification Commands**:
```bash
# Check service logs for restart
docker service logs names-app_backend --tail 20
docker service logs names-app_db --tail 20

# Verify service is healthy
./ops/verify.sh --quick
```

**Test Results**:
- [ ] ✅ PASS
- [ ] ❌ FAIL - _Reason:_
- **Duration**: ___ minutes
- **Notes**:

---

### Test 6: Data Persistence - Stack Redeploy

**Objective**: Verify data persists across full stack redeployment

**Acceptance Criteria**:
- [ ] Names added before redeploy are present after
- [ ] Stack redeploys successfully
- [ ] No data loss occurs
- [ ] Application remains functional

**Test Procedure**:
```bash
# Add test data
curl -X POST http://localhost/api/names \
  -H "Content-Type: application/json" \
  -d '{"name":"Redeploy Test 1"}'

curl -X POST http://localhost/api/names \
  -H "Content-Type: application/json" \
  -d '{"name":"Redeploy Test 2"}'

# Count names before redeploy
BEFORE_COUNT=$(curl -s http://localhost/api/names | jq '. | length')
echo "Names before redeploy: $BEFORE_COUNT"

# Remove stack (but keep volumes)
./ops/cleanup.sh --yes

# Redeploy stack
./ops/deploy.sh

# Wait for services to be ready
sleep 30

# Verify deployment
./ops/verify.sh

# Count names after redeploy
AFTER_COUNT=$(curl -s http://localhost/api/names | jq '. | length')
echo "Names after redeploy: $AFTER_COUNT"

# Compare counts
if [ "$BEFORE_COUNT" -eq "$AFTER_COUNT" ]; then
    echo "✅ Data persisted correctly"
else
    echo "❌ Data loss detected: $BEFORE_COUNT -> $AFTER_COUNT"
fi
```

**Verification Commands**:
```bash
# List all names and verify they match pre-redeploy
curl http://localhost/api/names | jq

# Check volume still exists
docker volume ls | grep names-app
```

**Test Results**:
- [ ] ✅ PASS
- [ ] ❌ FAIL - _Reason:_
- **Duration**: ___ minutes
- **Notes**:

---

### Test 7: Database Volume on Worker Node

**Objective**: Verify database volume is created on worker node

**Acceptance Criteria**:
- [ ] Volume exists at /var/lib/postgres-data on worker
- [ ] Volume has correct permissions
- [ ] Database is writing to this volume
- [ ] Data files are visible in volume

**Test Procedure**:
```bash
# Check volume location on worker
cd vagrant
vagrant ssh -c "ls -la /var/lib/postgres-data"
# Expected: Directory with PostgreSQL data files

# Check disk usage
vagrant ssh -c "du -sh /var/lib/postgres-data"
# Expected: Several MB of data

# Check file ownership
vagrant ssh -c "ls -ln /var/lib/postgres-data" | head -5
# Expected: Files owned by postgres user (typically UID 999 or 70)

# Verify database is using this location
docker service logs names-app_db --tail 50 | grep "database system is ready"

cd ..
```

**Verification Commands**:
```bash
# Check service placement
docker service ps names-app_db --format "{{.Node}}: {{.CurrentState}}"
# Expected: worker node

# Inspect service mounts
docker service inspect names-app_db --format '{{json .Spec.TaskTemplate.ContainerSpec.Mounts}}' | jq
# Expected: Mount showing /var/lib/postgres-data
```

**Test Results**:
- [ ] ✅ PASS
- [ ] ❌ FAIL - _Reason:_
- **Duration**: ___ minutes
- **Notes**:

---

### Test 8: Automatic Container Restart

**Objective**: Verify Swarm restarts failed containers automatically

**Acceptance Criteria**:
- [ ] Container stops when killed
- [ ] Swarm detects failure within seconds
- [ ] New container starts automatically
- [ ] Service recovers without intervention
- [ ] Application remains accessible

**Test Procedure**:
```bash
# Get current backend container
BACKEND_CONTAINER=$(docker ps --filter "name=names-app_backend" --format "{{.ID}}")
echo "Backend container: $BACKEND_CONTAINER"

# Kill the container
docker kill $BACKEND_CONTAINER

# Watch service status
watch -n 1 'docker service ps names-app_backend --no-trunc'
# Expected: See old container as "Failed", new container "Running"

# Wait for recovery (press Ctrl+C to exit watch)
sleep 10

# Verify service is healthy
curl http://localhost/healthz | jq
# Expected: {"status":"ok"}

# Check service recovered
docker service ps names-app_backend
# Expected: 1 Running task, 1 Failed task (old one)
```

**Additional Tests**:
```bash
# Test frontend recovery
FRONTEND_CONTAINER=$(docker ps --filter "name=names-app_frontend" --format "{{.ID}}")
docker kill $FRONTEND_CONTAINER
sleep 10
curl -I http://localhost
# Expected: HTTP/1.1 200 OK

# Test database recovery (takes longer)
DB_CONTAINER=$(docker ps --filter "name=names-app_db" --format "{{.ID}}")
docker kill $DB_CONTAINER
sleep 30  # Database takes longer to restart
curl http://localhost/api/health/db | jq
# Expected: {"status":"ok"}
```

**Test Results**:
- [ ] ✅ PASS
- [ ] ❌ FAIL - _Reason:_
- **Duration**: ___ minutes
- **Notes**:

---

### Test 9: Frontend Accessibility

**Objective**: Verify frontend is accessible on port 80

**Acceptance Criteria**:
- [ ] Frontend responds on http://localhost
- [ ] Frontend responds on http://192.168.56.1
- [ ] Returns HTTP 200 status code
- [ ] Serves HTML content
- [ ] Static assets load correctly

**Test Procedure**:
```bash
# Test localhost access
curl -I http://localhost
# Expected: HTTP/1.1 200 OK

# Test manager IP access
curl -I http://192.168.56.1
# Expected: HTTP/1.1 200 OK

# Verify HTML content
curl -s http://localhost | head -20
# Expected: HTML with <title>Names Manager</title>

# Test API through frontend proxy
curl http://localhost/api/health | jq
# Expected: JSON response with health info

# Check response time
time curl -s http://localhost > /dev/null
# Expected: < 1 second
```

**Browser Testing**:
1. Open http://localhost
2. Verify page renders correctly
3. Check browser console for errors
4. Test navigation and functionality
5. Verify CSS and JavaScript load

**Test Results**:
- [ ] ✅ PASS
- [ ] ❌ FAIL - _Reason:_
- **Duration**: ___ minutes
- **Notes**:

---

### Test 10: Cleanup Script

**Objective**: Verify `ops/cleanup.sh` successfully removes deployment

**Acceptance Criteria**:
- [ ] Script removes stack successfully
- [ ] Services stop completely
- [ ] Can optionally remove volumes
- [ ] Can optionally leave Swarm
- [ ] Summary shows correct state
- [ ] Exit code is 0

**Test Procedure - Level 1 (Stack Only)**:
```bash
# Remove stack only (preserve data and cluster)
./ops/cleanup.sh --yes

# Verify stack is removed
docker stack ls
# Expected: names-app not listed

# Verify volumes still exist
docker volume ls | grep names-app
# Expected: Volume still present

# Verify Swarm still active
docker info | grep "Swarm:"
# Expected: "Swarm: active"
```

**Test Procedure - Level 2 (Stack + Volumes)**:
```bash
# First redeploy to test volume removal
./ops/deploy.sh

# Remove stack and volumes
./ops/cleanup.sh --remove-volumes --yes

# Verify stack is removed
docker stack ls
# Expected: names-app not listed

# Verify volumes are removed
docker volume ls | grep names-app
# Expected: (empty)

# Verify Swarm still active
docker info | grep "Swarm:"
# Expected: "Swarm: active"
```

**Test Procedure - Level 3 (Full Cleanup)**:
```bash
# First redeploy
./ops/deploy.sh

# Full cleanup
./ops/cleanup.sh --full --yes

# Verify stack is removed
docker stack ls
# Expected: names-app not listed

# Verify volumes are removed
docker volume ls | grep names-app
# Expected: (empty)

# Verify Swarm is inactive
docker info | grep "Swarm:"
# Expected: "Swarm: inactive"

# Verify VM is stopped
cd vagrant
vagrant status
# Expected: "poweroff"
cd ..
```

**Test Results**:
- [ ] ✅ PASS - Level 1 (Stack Only)
- [ ] ✅ PASS - Level 2 (Stack + Volumes)
- [ ] ✅ PASS - Level 3 (Full Cleanup)
- [ ] ❌ FAIL - _Reason:_
- **Duration**: ___ minutes
- **Notes**:

---

## Complete Workflow Test

**Objective**: Execute complete workflow from start to finish

**Test Procedure**:
```bash
# Step 1: Clean state
./ops/cleanup.sh --full --yes 2>/dev/null || true

# Step 2: Initialize Swarm
echo "=== Step 1: Initialize Swarm ==="
time ./ops/init-swarm.sh
if [ $? -eq 0 ]; then echo "✅ Init passed"; else echo "❌ Init failed"; exit 1; fi

# Step 3: Deploy stack
echo "=== Step 2: Deploy Stack ==="
cd src && cp .env.example .env && cd ..
time ./ops/deploy.sh
if [ $? -eq 0 ]; then echo "✅ Deploy passed"; else echo "❌ Deploy failed"; exit 1; fi

# Step 4: Verify deployment
echo "=== Step 3: Verify Deployment ==="
time ./ops/verify.sh
if [ $? -eq 0 ]; then echo "✅ Verify passed"; else echo "❌ Verify failed"; exit 1; fi

# Step 5: Test application
echo "=== Step 4: Test Application ==="
curl -X POST http://localhost/api/names -H "Content-Type: application/json" -d '{"name":"Workflow Test"}'
curl http://localhost/api/names | jq
if [ $? -eq 0 ]; then echo "✅ App test passed"; else echo "❌ App test failed"; exit 1; fi

# Step 6: Test persistence
echo "=== Step 5: Test Persistence ==="
./ops/cleanup.sh --yes
./ops/deploy.sh
sleep 30
curl http://localhost/api/names | jq
if [ $? -eq 0 ]; then echo "✅ Persistence passed"; else echo "❌ Persistence failed"; exit 1; fi

# Step 7: Test recovery
echo "=== Step 6: Test Recovery ==="
docker kill $(docker ps --filter "name=names-app_backend" --format "{{.ID}}")
sleep 10
curl http://localhost/healthz | jq
if [ $? -eq 0 ]; then echo "✅ Recovery passed"; else echo "❌ Recovery failed"; exit 1; fi

# Step 8: Cleanup
echo "=== Step 7: Cleanup ==="
time ./ops/cleanup.sh --full --yes
if [ $? -eq 0 ]; then echo "✅ Cleanup passed"; else echo "❌ Cleanup failed"; exit 1; fi

echo ""
echo "🎉 Complete workflow test PASSED!"
```

**Test Results**:
- [ ] ✅ PASS
- [ ] ❌ FAIL - _Reason:_
- **Total Duration**: ___ minutes
- **Notes**:

---

## Issues and Solutions

### Issue 1: _To be filled during testing_

**Description**:

**Impact**:

**Solution**:

**Status**: ⏳ Open / ✅ Resolved

---

### Issue 2: _To be filled during testing_

**Description**:

**Impact**:

**Solution**:

**Status**: ⏳ Open / ✅ Resolved

---

## Test Summary

### Overview

| Test | Status | Duration | Notes |
|------|--------|----------|-------|
| 1. Fresh Init | ⏳ Not Run | - | |
| 2. Stack Deploy | ⏳ Not Run | - | |
| 3. Verification | ⏳ Not Run | - | |
| 4. Web UI | ⏳ Not Run | - | |
| 5. Service Restart Persistence | ⏳ Not Run | - | |
| 6. Stack Redeploy Persistence | ⏳ Not Run | - | |
| 7. Volume on Worker | ⏳ Not Run | - | |
| 8. Auto Restart | ⏳ Not Run | - | |
| 9. Frontend Access | ⏳ Not Run | - | |
| 10. Cleanup | ⏳ Not Run | - | |
| **Complete Workflow** | ⏳ Not Run | - | |

### Acceptance Criteria Status

- [ ] Fresh init-swarm completes successfully
- [ ] Stack deploys without errors
- [ ] All verification checks pass
- [ ] Can add names through web UI
- [ ] Names persist after service restart
- [ ] Names persist after stack redeploy
- [ ] Database volume is on worker node
- [ ] Swarm restarts failed containers automatically
- [ ] Frontend accessible on port 80
- [ ] Cleanup script successfully removes deployment

### Overall Result

- [ ] ✅ ALL TESTS PASSED
- [ ] ⚠️ SOME TESTS FAILED (see issues above)
- [ ] ❌ MAJOR FAILURES (deployment not functional)

**Total Test Duration**: ___ minutes

**Tester Sign-off**: ___________________  
**Date**: ___________________

---

## Repeatability

This test suite can be repeated by:

1. Ensuring all prerequisites are met
2. Starting from a clean state (`./ops/cleanup.sh --full --yes`)
3. Following each test procedure in order
4. Recording results in this document
5. Documenting any issues encountered

The test procedures are designed to be:
- **Deterministic**: Same input produces same output
- **Independent**: Each test can run standalone
- **Automated**: Most tests use curl/scripts
- **Verifiable**: Clear pass/fail criteria

---

## Screenshots

_Attach screenshots of:_
- [ ] Successful Swarm initialization
- [ ] Successful stack deployment
- [ ] All verification checks passing
- [ ] Web UI showing names
- [ ] Service recovery in action
- [ ] Successful cleanup

Save screenshots in: `screenshots/testing/`

---

## Logs

_Attach relevant logs if issues occur:_

```bash
# Save script outputs
./ops/init-swarm.sh > logs/init-swarm.log 2>&1
./ops/deploy.sh > logs/deploy.log 2>&1
./ops/verify.sh > logs/verify.log 2>&1
./ops/cleanup.sh --full --yes > logs/cleanup.log 2>&1

# Save service logs
docker service logs names-app_backend > logs/backend.log 2>&1
docker service logs names-app_frontend > logs/frontend.log 2>&1
docker service logs names-app_db > logs/db.log 2>&1
```

---

## Conclusion

_To be filled after testing completes_

**Summary**: 

**Recommendations**:

**Next Steps**:
