# Health Check Endpoints Documentation

The Names Manager API provides health check endpoints to monitor application and database status.

## Endpoints

### Basic Health Check
**GET** `/api/health`

Returns basic application health status.

**Response (200 OK):**
```json
{
  "status": "healthy",
  "service": "Names Manager API",
  "version": "1.0.0",
  "timestamp": "2025-10-11T07:45:17.933580+00:00"
}
```

### Database Health Check
**GET** `/api/health/db`

Returns database connectivity status and connection information.

**Response when healthy (200 OK):**
```json
{
  "status": "healthy",
  "service": "Names Manager API - Database",
  "database": "connected",
  "db_time": "2025-10-11 07:45:41.093980+00:00",
  "connection_url": "db:5432/namesdb"
}
```

**Response when unhealthy (503 Service Unavailable):**
```json
{
  "status": "unhealthy",
  "service": "Names Manager API - Database",
  "database": "disconnected",
  "error": "Database connection failed",
  "details": "Connection error details..."
}
```

## Usage Examples

### Using curl

```bash
# Check application health
curl http://localhost:8080/api/health

# Check database health
curl http://localhost:8080/api/health/db

# Check database health with status code
curl -w "HTTP Status: %{http_code}\n" http://localhost:8080/api/health/db
```

### Integration with Monitoring Tools

These endpoints can be used with:
- Docker health checks
- Kubernetes liveness/readiness probes
- Load balancer health checks
- Monitoring systems (Prometheus, Nagios, etc.)

## Security Notes

- Health check endpoints do not expose sensitive information
- Database credentials are filtered from responses
- Only connection status and sanitized connection details are shown
- No authentication required for health checks (by design)

## Performance

- Basic health check: < 10ms response time
- Database health check: < 100ms response time (depends on database latency)
- Endpoints are designed to be lightweight and safe to call frequently