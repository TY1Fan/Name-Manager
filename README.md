# Names Manager

A secure, containerized 3-tier web application for managing personal contact names with comprehensive input validation and XSS protection.

## Features

- ✅ **Add, List, and Delete Names**: Simple interface for managing personal contacts
- 🔒 **Security First**: XSS prevention with HTML sanitization and input validation  
- 🏥 **Health Monitoring**: Built-in health check endpoints for application monitoring
- 🐳 **Containerized**: Fully containerized with Docker for easy deployment
- 📊 **Logging & Monitoring**: Comprehensive logging and audit trails
- 🧪 **Well Tested**: Unit tests and comprehensive manual testing procedures

## User Guide

### Prerequisites
- **Docker** (version 20.0+ recommended)
- **Docker Compose** (version 2.0+ recommended)  
- **Web Browser** (Chrome, Firefox, Safari, or Edge)
- **4GB RAM** minimum for containers

### Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/TY1Fan/Name-Manager.git
   cd Name-Manager
   ```

2. **Set up environment** (optional - defaults work for development):
   ```bash
   cd src
   cp .env.example .env
   # Edit .env if you need custom configuration
   ```

3. **Start the application**:
   ```bash
   docker compose up -d
   ```

4. **Access the application**:
   - **Web Interface**: http://localhost:8080
   - **API Health Check**: http://localhost:8080/api/health
   - **Database Health**: http://localhost:8080/api/health/db

### Quick Verification
- Add a test name in the web interface
- Verify it appears in the names list
- Test the delete functionality

## How it works

### System Overview
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Frontend      │    │     Backend      │    │   Database      │
│   (Nginx)       │    │    (Flask)       │    │  (PostgreSQL)   │
│   Port 8080     │◄──►│   Port 8000      │◄──►│   Port 5432     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

- **Frontend**: Nginx-served static HTML/JS/CSS with API proxying
- **Backend**: Flask REST API with input validation and sanitization
- **Database**: PostgreSQL with persistent Docker volume storage
- **Security**: XSS prevention, input validation, health monitoring

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
1. **Basic Functionality**: Add "John Doe", verify it appears, then delete it
2. **Input Validation**: Try empty name, long name (>50 chars), whitespace only
3. **Security Test**: Try `<script>alert('test')</script>` - should be safely escaped
4. **Health Check**: Visit http://localhost:8080/api/health

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for development guidelines and contribution process.

## License

See [`LICENSE`](LICENSE) for license information.