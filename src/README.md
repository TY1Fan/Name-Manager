# Developer Guide

This directory contains the complete source code and deployment configuration for the Names Manager application.

## Directory Structure

```
src/
├── docker-compose.yml          # Container orchestration
├── .env.example               # Environment configuration template
├── backend/                   # Flask API server
│   ├── main.py               # Main application file
│   ├── requirements.txt      # Python dependencies
│   ├── requirements-dev.txt  # Development dependencies  
│   ├── Dockerfile           # Backend container config
│   ├── tests/               # Unit tests
│   ├── HEALTH_ENDPOINTS.md  # Health monitoring docs
│   ├── SANITIZATION.md      # Security implementation docs
│   └── README.md            # Backend testing guide
├── frontend/                 # Static web interface
│   ├── index.html           # Main HTML page
│   ├── app.js               # Frontend JavaScript
│   ├── nginx.conf           # Nginx configuration
│   └── Dockerfile           # Frontend container config
└── db/
    └── init.sql             # Database initialization
```

## Development Setup

### Prerequisites
- Docker Desktop or Docker Engine + Docker Compose
- Git
- Text editor or IDE
- Web browser for testing

### Quick Development Start

1. **Copy environment configuration**:
   ```bash
   cp .env.example .env
   ```

2. **Start development environment**:
   ```bash
   docker compose up -d
   ```

3. **Verify everything is running**:
   ```bash
   docker compose ps
   # All services should show "Up" status
   ```

4. **Access the application**:
   - Frontend: http://localhost:8080
   - API: http://localhost:8080/api/health
   - Backend directly: http://localhost:8000 (if needed)

### Development Workflow

#### Making Backend Changes
```bash
# Edit files in backend/
# Restart backend to apply changes
docker compose restart backend

# View logs
docker compose logs -f backend

# Run tests
docker compose exec backend python -m pytest
```

#### Making Frontend Changes
```bash
# Edit files in frontend/
# Restart frontend to apply changes  
docker compose restart frontend

# View logs
docker compose logs -f frontend
```

#### Database Changes
```bash
# View database logs
docker compose logs db

# Connect to database directly (if needed)
docker compose exec db psql -U names_user -d namesdb

# Reset database (removes all data!)
docker compose down -v
docker compose up -d
```

## Testing

### Automated Testing

#### Backend Unit Tests
```bash
# Run all tests
docker compose exec backend python -m pytest

# Run with coverage report
docker compose exec backend python -m pytest --cov

# Run specific test file
docker compose exec backend python -m pytest tests/test_validation.py -v

# Run tests in watch mode (if pytest-watch installed)
docker compose exec backend ptw
```

#### Test Configuration
- Tests are located in `backend/tests/`
- Configuration in `pytest.ini` and `backend/requirements-dev.txt`
- Coverage reports generated in `backend/htmlcov/`

### Manual Testing
- Follow the comprehensive manual testing checklist in [`../TESTING.md`](../TESTING.md)
- Test all user workflows, security features, and error conditions
- Verify cross-browser compatibility

### API Testing with curl

```bash
# Health checks
curl http://localhost:8080/api/health
curl http://localhost:8080/api/health/db

# List names
curl http://localhost:8080/api/names

# Add name
curl -X POST http://localhost:8080/api/names \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User"}'

# Delete name (replace {id} with actual ID)
curl -X DELETE http://localhost:8080/api/names/{id}
```

## Configuration

### Environment Variables

The application uses environment variables for configuration. Copy `.env.example` to `.env` and modify as needed.

#### Core Configuration
```bash
# Database settings
POSTGRES_USER=names_user
POSTGRES_PASSWORD=names_pass  # Change for production!
POSTGRES_DB=namesdb

# Application settings
MAX_NAME_LENGTH=50           # Maximum name length
LOG_LEVEL=INFO              # DEBUG, INFO, WARN, ERROR
DB_ECHO=false               # Enable SQL query logging

# Server settings
SERVER_HOST=0.0.0.0         # Backend bind address
SERVER_PORT=8000            # Backend port
FRONTEND_PORT=8080          # External web port
```

#### Advanced Configuration
See [DOCKER_ENV_SETUP.md](DOCKER_ENV_SETUP.md) for complete environment variable documentation.

### Docker Compose Configuration

The `docker-compose.yml` file defines three services:

- **frontend**: Nginx serving static files and proxying API calls
- **backend**: Flask application with Python API server
- **db**: PostgreSQL database with persistent storage

#### Key Configuration Points
```yaml
# Frontend exposed on host port (configurable)
frontend:
  ports:
    - "${FRONTEND_PORT:-8080}:80"

# Backend internal networking
backend:
  environment:
    - LOG_LEVEL=${LOG_LEVEL:-INFO}
    - MAX_NAME_LENGTH=${MAX_NAME_LENGTH:-50}

# Database with persistent volume
db:
  volumes:
    - names_data:/var/lib/postgresql/data
```

## Deployment

### Development Deployment
```bash
# Start all services in background
docker compose up -d

# View all logs
docker compose logs -f

# Stop services
docker compose down

# Stop and remove volumes (deletes data!)
docker compose down -v
```

### Production Considerations

#### Security
1. **Change default passwords** in `.env`
2. **Use HTTPS** with proper SSL certificates
3. **Configure firewall** to restrict database access
4. **Monitor logs** for security events
5. **Regular updates** of base images

#### Performance
1. **Resource limits** in docker-compose.yml
2. **Connection pooling** for database
3. **CDN** for static assets
4. **Load balancing** for multiple instances

#### Monitoring
- Health endpoints: `/api/health` and `/api/health/db`
- Container logs: `docker compose logs`
- Resource usage: `docker stats`
- Database monitoring via PostgreSQL tools

### Example Production Setup
```bash
# Production environment file
cat > .env << EOF
POSTGRES_PASSWORD=secure_random_password_here
LOG_LEVEL=WARN
FRONTEND_PORT=80
DB_ECHO=false
EOF

# Start with resource limits
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## troubleshooting

### Development Issues

#### Container Build Problems
```bash
# Force rebuild all images
docker compose build --no-cache

# Pull latest base images
docker compose pull
```

#### Port Conflicts
```bash
# Check port usage
lsof -i :8080
netstat -tulpn | grep 8080

# Change port in .env
echo "FRONTEND_PORT=3000" >> .env
docker compose down && docker compose up -d
```

#### Database Connection Issues
```bash
# Check database container
docker compose logs db
docker compose exec db pg_isready -U names_user

# Test database connectivity
curl http://localhost:8080/api/health/db
```

#### Permission Issues (Linux/macOS)
```bash
# Fix volume permissions
docker compose down
sudo chown -R $USER:$USER .
docker compose up -d
```

### Performance Issues

#### Slow Container Startup
```bash
# Check resource usage
docker stats
# Allocate more resources in Docker Desktop settings
```

#### Database Performance
```bash
# Enable query logging temporarily
echo "DB_ECHO=true" >> .env
docker compose restart backend

# Monitor database performance
docker compose exec db pg_stat_activity
```

### Getting Help

1. **Check service status**: `docker compose ps`
2. **View logs**: `docker compose logs [service-name]`
3. **Test health endpoints**: http://localhost:8080/api/health
4. **Verify configuration**: `docker compose config`
5. **Review manual tests**: [`../TESTING.md`](../TESTING.md)

For specific service issues:
- **Backend issues**: Check `backend/README.md` for testing procedures
- **Security concerns**: Review `backend/SANITIZATION.md`
- **Health monitoring**: See `backend/HEALTH_ENDPOINTS.md`
- **Environment setup**: Reference `DOCKER_ENV_SETUP.md`

## Code Quality

### Code Style
- Python: Follow PEP 8 guidelines
- JavaScript: Use modern ES6+ features
- HTML: Semantic, accessible markup
- CSS: Organized, maintainable styles

### Security Guidelines
- All user input must be validated and sanitized
- Use HTML escaping to prevent XSS attacks
- Log security events for monitoring
- Follow OWASP security best practices

### Testing Standards
- Unit tests for all business logic
- Integration tests for API endpoints
- Manual testing for user workflows
- Security testing for XSS prevention

See [`../TESTING.md`](src/backend/tests/TESTING.md) for comprehensive testing procedures.