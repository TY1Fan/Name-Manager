# Names Manager

A secure, containerized 3-tier web application for managing personal contact names with comprehensive input validation and XSS protection.

## Features

- ✅ **Add, List, and Delete Names**: Simple interface for managing personal contacts
- 🔒 **Security First**: XSS prevention with HTML sanitization and input validation  
- 🏥 **Health Monitoring**: Built-in health check endpoints for application monitoring
- 🐳 **Containerized**: Fully containerized with Docker for easy deployment
- 📊 **Logging & Monitoring**: Comprehensive logging and audit trails
- 🧪 **Well Tested**: Unit tests and comprehensive manual testing procedures

## Architecture

This application supports two deployment modes:

- **Development (Single-Host)**: Uses `src/docker-compose.yml` for local development with Docker Compose
- **Production (Multi-Host)**: Uses `swarm/stack.yaml` for distributed deployment with Docker Swarm
  - **Manager VM** (192.168.56.10): Runs web and API services
  - **Worker VM** (192.168.56.11): Runs database service with persistent storage

## Prerequisites

### For Local Development
- **Docker Desktop** (version 20.0+ recommended)
- **Docker Compose** (version 2.0+ recommended)  
- **Web Browser** (Chrome, Firefox, Safari, or Edge)
- **4GB RAM** minimum for containers

### For Production Deployment
- **Vagrant** (version 2.2+ recommended)
- **VirtualBox** (version 6.1+ recommended)
- **8GB RAM** minimum for VMs
- **20GB disk space** for VM images

## Local Development (Single-Host)

### Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/TY1Fan/Name-Manager.git
cd Name-Manager

# 2. Set up environment (optional - defaults work)
cd src
cp .env.example .env
# Edit .env if needed

# 3. Start the application
docker compose up -d

# 4. Access the application
open http://localhost:8080

# 5. Stop when done
docker compose down
```

**Access Points:**
- **Web Interface**: http://localhost:8080
- **API Health**: http://localhost:8080/api/health
- **Database Health**: http://localhost:8080/api/health/db

**Quick Test:** Add "John Doe", verify it appears, then delete it

## How it works

### System Architecture

**Development (Single-Host):**
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Frontend      │    │     Backend      │    │   Database      │
│   (Nginx)       │    │    (FastAPI)     │    │  (PostgreSQL)   │
│   Port 8080     │◄──►│   Port 8000      │◄──►│   Port 5432     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         Single Docker Host (Docker Compose)
```

**Production (Multi-Host):**
```
┌──────────────────────────────────────────────────────────────┐
│                     Docker Swarm Cluster                     │
├──────────────────────────────┬───────────────────────────────┤
│     Manager Node             │      Worker Node              │
│   (192.168.56.10)            │    (192.168.56.11)            │
│                              │                               │
│  ┌────────────┐              │   ┌─────────────────┐        │
│  │  Frontend  │              │   │    Database     │        │
│  │  (Nginx)   │              │   │  (PostgreSQL)   │        │
│  │  1 replica │              │   │   1 replica     │        │
│  └────────────┘              │   └─────────────────┘        │
│       ▲                      │          ▲                    │
│       │                      │          │                    │
│  ┌────┴───────┐              │          │                    │
│  │    API     │              │          │                    │
│  │ (FastAPI)  │◄─────────────┼──────────┘                    │
│  │ 2 replicas │   Overlay    │   /var/lib/postgres-data     │
│  └────────────┘   Network    │   (Persistent Storage)        │
└──────────────────────────────┴───────────────────────────────┘
```

### Components

- **Frontend**: Nginx-served static HTML/JS/CSS with API proxying
- **Backend**: FastAPI REST API with input validation and sanitization
- **Database**: PostgreSQL 15 with persistent storage
- **Security**: XSS prevention, input validation, health monitoring, Docker secrets

### API Endpoints
- `GET /api/names` - List all names
- `POST /api/names` - Add a new name
- `DELETE /api/names/{id}` - Delete a name by ID
- `GET /api/health` - Application health check
- `GET /api/health/db` - Database connectivity check

## Testing

### Automated Testing
```bash
# Run backend unit tests
cd src
docker compose exec backend python -m pytest

# Run tests with coverage
docker compose exec backend python -m pytest --cov
```

### Manual Testing  
Comprehensive manual testing procedures are available in [`TESTING.md`](src/backend/tests/TESTING.md), including:
- Functional testing (add/delete/list operations)
- Security testing (XSS prevention validation)  
- Error handling and edge cases
- Cross-browser compatibility
- Performance and load testing

### Quick Manual Test

**For Local Development (port 8080):**
```bash
curl http://localhost:8080/api/health
curl http://localhost:8080/api/names
```

**For Production Swarm (port 8081):**
```bash
./ops/verify.sh  # Automated verification
curl http://localhost:8081/api/health
curl http://localhost:8081/api/names
```

**Test Checklist:**
1. **Basic Functionality**: Add "John Doe", verify it appears, then delete it
2. **Input Validation**: Try empty name, long name (>50 chars), whitespace only
3. **Security Test**: Try `<script>alert('test')</script>` - should be safely escaped
4. **Health Check**: Verify both `/api/health` and `/api/health/db` return healthy status

## Production Deployment (Docker Swarm)

For production deployment on a distributed multi-node Docker Swarm cluster:

### Complete Deployment Workflow

```bash
# 1. Start VMs (manager + worker)
vagrant up

# 2. Initialize Swarm cluster (first time only)
./ops/init-swarm.sh

# 3. Build and deploy application
./ops/deploy.sh

# 4. Verify deployment health
./ops/verify.sh

# 5. Access application
open http://localhost:8081

# 6. Clean up (when done - preserves data)
./ops/cleanup.sh
```

**Access Points:**
- **Web Interface**: http://localhost:8081
- **API Health**: http://localhost:8081/api/health
- **Database Health**: http://localhost:8081/api/health/db

### Operations Scripts

All operational scripts are in the `ops/` directory:

| Script | Purpose | Usage |
|--------|---------|-------|
| **init-swarm.sh** | Initialize Docker Swarm cluster with node labels and network | Run once after `vagrant up` |
| **deploy.sh** | Build images, transfer to manager, deploy stack | Run to deploy/update app |
| **verify.sh** | Verify deployment health, placement, and connectivity | Run after deployment |
| **cleanup.sh** | Remove stack safely (preserves persistent data) | Run to clean up |

See [`ops/README.md`](ops/README.md) for detailed documentation.

### Service Placement

- **Manager Node** (192.168.56.10):
  - Web service (1 replica) - Port 80
  - API service (2 replicas) - Port 8000
  
- **Worker Node** (192.168.56.11):
  - Database service (1 replica) - PostgreSQL 15
  - Persistent storage: `/var/lib/postgres-data`

### Troubleshooting

View service logs:
```bash
vagrant ssh manager -c "docker service logs names_<service>"
```

Check service status:
```bash
vagrant ssh manager -c "docker service ps names_<service>"
```

List all services:
```bash
vagrant ssh manager -c "docker stack services names"
```

Restart a service:
```bash
vagrant ssh manager -c "docker service update --force names_<service>"
```

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for development guidelines and contribution process.

## License

See [`LICENSE`](LICENSE) for license information.