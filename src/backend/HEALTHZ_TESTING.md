# Backend Health Endpoint Testing

This document describes how to test the `/healthz` endpoint added in Task 3.2.

## Endpoint Specification

**Path**: `/healthz`  
**Method**: `GET`  
**Purpose**: Docker Swarm health check endpoint

### Success Response (200 OK)
```json
{
  "status": "ok"
}
```

### Failure Response (503 Service Unavailable)
```json
{
  "status": "unhealthy",
  "reason": "Database connection failed"
}
```

## Testing Locally with Docker Compose

### 1. Start the Application
```bash
cd src
docker-compose up -d
```

### 2. Wait for Services to Start
```bash
# Check service status
docker-compose ps

# Wait for backend to be healthy
docker-compose logs backend
```

### 3. Test the Endpoint

**Healthy State (Database Running)**
```bash
# Test with curl
curl -i http://localhost:8000/healthz

# Expected output:
# HTTP/1.1 200 OK
# Content-Type: application/json
# {"status":"ok"}

# Test with HTTPie (if installed)
http localhost:8000/healthz

# Test with Python
python3 -c "import requests; r = requests.get('http://localhost:8000/healthz'); print(f'{r.status_code}: {r.json()}')"
```

**Unhealthy State (Database Stopped)**
```bash
# Stop the database
docker-compose stop db

# Test the endpoint
curl -i http://localhost:8000/healthz

# Expected output:
# HTTP/1.1 503 SERVICE UNAVAILABLE
# Content-Type: application/json
# {"status":"unhealthy","reason":"Database connection failed"}

# Restart database
docker-compose start db
```

### 4. Verify Health Check in Docker Compose
```bash
# Check health status
docker-compose ps

# Backend should show as "healthy" after a few seconds
# Look for "Up X seconds (healthy)" status
```

## Testing with Docker Swarm

### 1. Deploy the Stack
```bash
cd src
docker stack deploy -c swarm/stack.yaml names-app
```

### 2. Monitor Service Health
```bash
# Check service status
docker service ls

# Check backend service details
docker service ps names-app_backend

# View service logs
docker service logs names-app_backend
```

### 3. Test the Endpoint via Ingress
```bash
# Access through frontend (proxied)
curl -i http://localhost/api/healthz

# Direct access to backend (if exposed)
curl -i http://localhost:8000/healthz
```

### 4. Verify Docker Swarm Health Checks
```bash
# Check if service is healthy
docker service inspect names-app_backend --format '{{.UpdateStatus.State}}'

# Check health check configuration
docker service inspect names-app_backend --format '{{json .Spec.TaskTemplate.ContainerSpec.Healthcheck}}' | jq
```

## Performance Testing

The `/healthz` endpoint should be fast since it only performs a lightweight database check.

### Response Time Test
```bash
# Test response time
time curl -s http://localhost:8000/healthz

# Should complete in < 100ms typically
```

### Load Test (Optional)
```bash
# Using Apache Bench (if installed)
ab -n 1000 -c 10 http://localhost:8000/healthz

# Using curl in a loop
for i in {1..100}; do
  curl -s http://localhost:8000/healthz > /dev/null
  echo "Request $i completed"
done
```

## Logging Behavior

The `/healthz` endpoint uses DEBUG level logging to avoid cluttering logs:

```bash
# With LOG_LEVEL=INFO, you won't see health check logs
docker-compose logs backend | grep healthz
# (Should show nothing)

# With LOG_LEVEL=DEBUG, you will see health check logs
docker-compose exec backend sh -c 'export LOG_LEVEL=DEBUG; echo "Set to DEBUG"'
docker-compose logs backend | grep healthz
# (Should show debug messages)
```

## Comparison with Existing Endpoints

| Endpoint | Purpose | Response | Logging Level |
|----------|---------|----------|---------------|
| `/api/health` | Application health info | Detailed status | INFO |
| `/api/health/db` | Database health info | Detailed DB status | INFO |
| `/healthz` | Docker health check | Minimal status | DEBUG |

### Test All Health Endpoints
```bash
# Application health
curl http://localhost:8000/api/health | jq

# Database health
curl http://localhost:8000/api/health/db | jq

# Swarm health check
curl http://localhost:8000/healthz | jq
```

## Troubleshooting

### Endpoint Returns 404
- Check that the backend container is running
- Verify you're using the correct port (8000 for backend)
- Check the backend logs for errors

### Endpoint Always Returns 503
- Verify database is running: `docker-compose ps db`
- Check database connection string in `.env`
- Look at backend logs: `docker-compose logs backend`
- Test database directly: `docker-compose exec db pg_isready`

### Health Check Failing in Swarm
- Check if curl is installed in container: `docker exec <container> which curl`
- Verify port in health check matches SERVER_PORT
- Check service logs: `docker service logs names-app_backend`
- Inspect health check config: `docker service inspect names-app_backend`

## Acceptance Criteria Verification

✅ **GET `/healthz` returns 200 with `{"status": "ok"}` when database is reachable**
```bash
curl http://localhost:8000/healthz
# Should return: {"status":"ok"}
```

✅ **GET `/healthz` returns 503 with error details when database is unreachable**
```bash
docker-compose stop db
curl http://localhost:8000/healthz
# Should return: {"status":"unhealthy","reason":"Database connection failed"}
```

✅ **Endpoint doesn't require authentication**
```bash
curl http://localhost:8000/healthz
# Works without any authentication headers
```

✅ **Health check doesn't perform heavy operations**
- Uses `SELECT 1` - simplest possible query
- No table scans or complex joins
- Response time < 100ms

✅ **Endpoint is logged at DEBUG level**
```bash
# With LOG_LEVEL=INFO (default), no spam in logs
docker-compose logs backend | grep healthz | wc -l
# Should be 0 or very few error entries
```

## Integration with Docker Swarm

The `/healthz` endpoint is used by Docker Swarm to monitor service health:

```yaml
# From swarm/stack.yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/healthz"]
  interval: 10s
  timeout: 5s
  retries: 3
  start_period: 40s
```

This means:
- Swarm checks health every 10 seconds
- If check fails 3 times, container is marked unhealthy
- Unhealthy containers are automatically restarted
- New containers get 40 seconds to start before health checks begin
