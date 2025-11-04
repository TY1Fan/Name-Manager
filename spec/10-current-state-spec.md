# Names Manager - Current State Specification

## Executive Summary

**Status**: � **FULLY FUNCTIONAL** - All core features working correctly

**Branch**: `k3s-orchestration` - Preparing for Kubernetes (k3s) deployment support

The Names Manager is a 3-tier web application designed to manage a simple list of names through a web interface. The application is fully operational with:

1. **Complete CRUD operations** - Create, Read, and Delete functionality working correctly
2. **Proper frontend-backend integration** - Response formats aligned and data flows correctly  
3. **Multiple deployment options** - Docker Compose and Docker Swarm currently supported
4. **Production-ready features** - Logging, health checks, input sanitization, and error handling
5. **k3s readiness** - Application architecture prepared for Kubernetes deployment

**Assessment**: The application is production-ready for basic name management with comprehensive logging, security features, and deployment flexibility. Currently supports Docker Compose and Swarm orchestration, with k3s/Kubernetes support in development.

## System Overview

The Names Manager consists of a PostgreSQL database, Flask REST API backend, and a static HTML/JavaScript frontend served by Nginx. The application supports multiple orchestration platforms:

- **Docker Compose**: Single-host development and testing
- **Docker Swarm**: Multi-host production deployment with scaling
- **k3s/Kubernetes**: (In development) Cloud-native deployment with advanced orchestration

All deployments feature proper health checks, environment-based configuration, and comprehensive logging.

## Architecture

### System Components
- **Database**: PostgreSQL 15 container with persistent volume storage
- **Backend**: Flask REST API with SQLAlchemy ORM and Gunicorn WSGI server (4 workers)
- **Frontend**: Static HTML/CSS/JavaScript served by Nginx with reverse proxy
- **Orchestration**: Multi-platform support
  - Docker Compose for single-host development/testing
  - Docker Swarm for multi-host production deployment
  - k3s/Kubernetes (in development) for cloud-native orchestration

### Network Architecture
- **External Access**: 
  - Docker Compose: Port 8080 (configurable via `FRONTEND_PORT`)
  - Docker Swarm: Port 80 on manager nodes
  - k3s: (Planned) NodePort or LoadBalancer service
- **Internal Network**: 
  - Docker Compose/Swarm: `appnet` Docker overlay network
  - k3s: (Planned) Kubernetes cluster network with service discovery
- **Service Communication**: 
  - Frontend ↔ Backend: HTTP/REST API via Nginx reverse proxy
  - Backend ↔ Database: PostgreSQL protocol (port 5432)
  - Service discovery via DNS (Docker DNS or Kubernetes CoreDNS)

## Data Model

### Database Schema

#### `names` Table
```sql
CREATE TABLE IF NOT EXISTS names (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Field Specifications:**
- `id`: Auto-incrementing primary key, used for unique identification and deletion
- `name`: Text field for storing user-provided names, maximum 50 characters (enforced at application level)
- `created_at`: Timestamp automatically set to current time on record creation

**Constraints:**
- Primary key constraint on `id`
- NOT NULL constraint on `name`
- No unique constraints (duplicate names allowed)

## API Specification

### Base URL
- Internal: `http://backend:8000/api`
- External: `http://localhost:8080/api` (proxied through Nginx)

### Endpoints

#### POST /api/names
**Purpose**: Add a new name to the database

**Request:**
```json
{
  "name": "string"
}
```

**Request Validation:**
- Content-Type must be `application/json`
- `name` field is required
- `name` must not be empty after trimming whitespace
- `name` must not exceed 50 characters (configurable via `MAX_NAME_LENGTH` environment variable)
- Input is sanitized to prevent XSS attacks (HTML entities escaped, null bytes removed, whitespace normalized)

**Success Response (201 Created):**
```json
{
  "id": 123,
  "name": "John Doe"
}
```

**Error Responses:**
- `400 Bad Request`: Invalid JSON, missing name, empty name, or name too long
  ```json
  {
    "error": "Name cannot be empty."
  }
  ```
  ```json
  {
    "error": "Max length is 50 characters."
  }
  ```
  ```json
  {
    "error": "Invalid JSON body."
  }
  ```
- `500 Internal Server Error`: Database connection or query failures
  ```json
  {
    "error": "Internal server error"
  }
  ```

**Security Features:**
- HTML entity escaping to prevent XSS
- Null byte removal
- Whitespace normalization
- Security logging for sanitized inputs

#### GET /api/names
**Purpose**: Retrieve all names from the database

**Request:** No body required

**Success Response (200 OK):**
```json
{
  "names": [
    {
      "id": 1,
      "name": "John Doe",
      "created_at": "2025-10-10T12:34:56.789000"
    },
    {
      "id": 2,
      "name": "Jane Smith",
      "created_at": "2025-10-10T13:45:22.123000"
    }
  ]
}
```

**Response Details:**
- Returns object with `names` array containing all names ordered by `id` ascending
- Each name object includes `id`, `name`, and `created_at` fields
- `created_at` is ISO 8601 formatted timestamp
- Returns `{"names": []}` (empty array) if no names exist

**Error Response:**
- `500 Internal Server Error`: Database connection or query failures

#### DELETE /api/names/{id}
**Purpose**: Delete a specific name by ID

**Request:** No body required
**Path Parameter:** `id` (integer) - ID of the name to delete

**Success Response (200 OK):**
```json
{
  "deleted": 123
}
```

**Error Response (404 Not Found):**
```json
{
  "error": "Name not found"
}
```

**Error Response (500 Internal Server Error):**
```json
{
  "error": "Internal server error"
}
```

**Behavior:**
- Returns 404 if ID doesn't exist
- Returns 200 with deleted ID if successful
- No cascading deletes (single table)
- Frontend properly passes integer ID extracted from DOM element
- Backend validates ID type through route parameter `<int:name_id>`

#### GET /api/health
#### GET /healthz
**Purpose**: Basic health check for the API service

**Request:** No body required

**Success Response (200 OK):**
```json
{
  "status": "ok"
}
```

**Response Details:**
- Returns simple status indicator for service availability
- Also available at `/healthz` endpoint for Kubernetes compatibility
- Lightweight check without database verification

#### GET /api/health/db
**Purpose**: Database connectivity health check

**Request:** No body required

**Success Response (200 OK):**
```json
{
  "status": "healthy",
  "service": "Names Manager API - Database",
  "database": "connected",
  "db_time": "2025-10-30 12:34:56.789000",
  "connection_url": "db:5432/namesdb"
}
```

**Error Response (503 Service Unavailable):**
```json
{
  "status": "unhealthy",
  "service": "Names Manager API - Database",
  "database": "disconnected",
  "error": "Database connection failed",
  "details": "connection refused"
}
```

**Behavior:**
- Executes a simple database query to verify connectivity
- Hides database credentials in response
- Returns 503 if database is unreachable

## User Interface Specification

### Main Interface
**URL**: `http://localhost:8080/`

### UI Components

#### Add Name Form
- **Input Field**: Text input with placeholder "Enter a name"
  - `maxlength="50"` HTML attribute
  - `required` attribute for basic validation
  - `autocomplete="off"` to prevent browser autocomplete
  - Real-time character count display when approaching limit (45+ characters)
  - Input error styling (red border, pink background) on validation failure
- **Submit Button**: "Add" button to submit the form
  - Shows loading spinner during submission
  - Disabled state while processing
- **Validation**: Client-side validation with inline error messages
  - Empty name validation
  - Length validation with remaining character count
  - Automatic trimming of whitespace with user notification
- **Field Error Display**: Red text below input for validation feedback

#### Messages and Notifications
- **Error Messages**: Red-themed banner for error notifications
  - Appears above the form
  - Auto-dismisses after 5 seconds
  - Network errors, validation errors, and API errors
- **Success Messages**: Green-themed banner for success notifications
  - Appears above the form
  - Auto-dismisses after 3 seconds
  - Confirmation of additions and deletions

#### Names List Display
- **Header**: "Recorded names"
- **Empty State**: "No names found" styled as list item when database is empty
- **Loading State**: List opacity reduced and interactions disabled while loading
- **List Items**: Each name displayed with:
  - Name content area showing:
    - Name text (bold, 16px font, escaped for XSS prevention)
    - Timestamp in localized format (gray text, smaller font)
  - Delete button (red background) on the right with name ID stored for deletion
  - Box shadow for depth
  - White background cards with rounded corners
  - 10px margin between items
  - Proper object destructuring to display `id`, `name`, and `created_at` fields
- **Error State**: "Error loading names" message when API call fails
- **Success Feedback**: Shows count of names loaded ("Found X names")

#### Delete Functionality
- **Confirmation**: JavaScript `confirm()` dialog before deletion showing the name to be deleted
- **Button**: Individual delete button per name with `onclick` handler
  - Red background (#e53935)
  - Darker red on hover (#ab2822)
  - 14px font size
  - Passes integer ID to delete function
- **Feedback**: 
  - Success message displayed after deletion with name confirmation
  - List automatically refreshes to reflect changes
  - Error handling if deletion fails or name not found
  - Graceful handling of "not found" errors with list refresh to maintain sync

### User Experience Flow

#### Adding a Name
1. User types name in input field
2. Real-time validation:
   - Character count shown when approaching 50 character limit
   - Field errors cleared as user types (if previously shown)
3. Form submission triggers AJAX POST request
4. Loading state:
   - Button shows spinner and "Loading..." text
   - Button disabled to prevent double-submission
5. Success: 
   - Input field clears
   - Success message displays with name confirmation
   - List refreshes automatically to show new entry
6. Error: 
   - Error banner displays with specific error message
   - Field-level error shows below input
   - Previous input retained for correction
   - List remains unchanged

#### Viewing Names
1. Page loads and automatically fetches all names via AJAX
2. Loading state displayed (reduced opacity)
3. Success:
   - Names displayed in chronological order by ID
   - Success message shows count ("Found X names")
   - Each name shown in styled card with delete button
4. Empty state: "No names found" message displayed
5. Error: Error message and "Error loading names" displayed

#### Deleting a Name
1. User clicks red delete button for specific name
2. Confirmation dialog appears with name to be deleted
3. If user cancels, no action taken
4. If confirmed:
   - AJAX DELETE request sent
   - Messages hidden during processing
5. Success: 
   - Success message displays confirmation
   - List refreshes automatically to reflect deletion
6. Error: 
   - Error banner displays specific error
   - List refreshes anyway to ensure synchronization
   - Handles "not found" errors gracefully

## System Behavior

### Application Startup Sequence
1. **Database Container**: PostgreSQL starts, runs init.sql to create schema
2. **Backend Container**: Waits for database health check, then starts Flask app with Gunicorn
3. **Frontend Container**: Nginx starts and serves static files immediately
4. **Health Checks**: Database responds to `pg_isready` before backend starts

### Error Handling

#### Backend Error Handling
- **Database Connection Errors**: Wrapped in try-catch, returns 500 "Internal server error"
- **Validation Errors**: Return 400 with descriptive error messages
- **Not Found Errors**: Return 404 with error message
- **JSON Parsing Errors**: Return 400 "Invalid JSON body"
- **Logging**: All errors logged with context (endpoint, error details, request parameters)
- **Exception Handling**: All API endpoints wrapped in try-catch blocks

#### Frontend Error Handling
- **Network Errors**: 
  - Detected via TypeError with 'fetch' in message
  - Friendly error message: "Unable to connect to server"
  - Displayed in error message banner
- **API Errors**: 
  - Parsed from JSON response
  - Specific error handling for common scenarios (empty, too long, not found, already exists)
  - Generic fallback for unexpected errors
- **Form Validation**: 
  - Field-level inline error messages
  - Visual feedback (red border, pink background)
  - Banner notifications for context
- **XSS Prevention**: All user input escaped using textContent before display
- **Loading States**: Prevent multiple simultaneous submissions

### Data Persistence
- **Database**: All data persisted in PostgreSQL with Docker volume `db_data`
- **Session State**: No session management, stateless application
- **Client State**: No local storage, all data fetched fresh on page load

## Configuration

### Environment Variables

#### Database Configuration
- `POSTGRES_USER`: PostgreSQL username for database access
- `POSTGRES_PASSWORD`: PostgreSQL password
- `POSTGRES_DB`: Database name
- `DATABASE_URL`: PostgreSQL connection string (Swarm/standard, takes priority)
- `DB_URL`: PostgreSQL connection string (Compose/legacy fallback)
- Default: `postgresql+psycopg2://names_user:names_pass@db:5432/namesdb`
- Backend supports both variables for deployment flexibility

#### Application Configuration
- `MAX_NAME_LENGTH`: Maximum allowed length for names (default: 50)
- `SERVER_HOST`: Backend server bind address (default: 0.0.0.0)
- `SERVER_PORT`: Backend server port (default: 8000)

#### Logging Configuration
- `LOG_LEVEL`: Application log level - DEBUG, INFO, WARNING, ERROR, CRITICAL (default: INFO)
- `DB_ECHO`: Enable SQLAlchemy query logging - true/false (default: false)

#### Frontend Configuration
- `FRONTEND_PORT`: Host port mapping for frontend (default: 8080)

### Docker Configuration

#### Database Service
- **Image**: postgres:15
- **Volume**: `db_data` for persistent storage
- **Init Script**: `/db/init.sql` mounted read-only to initialize schema
- **Network**: Connected to `appnet` internal network
- **Health Check**: 
  - Command: `pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}`
  - Interval: 5 seconds
  - Timeout: 5 seconds
  - Retries: 5
  - Start period: 10 seconds

#### Backend Service
- **Build Context**: `./backend`
- **Base Image**: python:3.11-slim
- **Dependencies**: Flask 2.3.2, Gunicorn 20.1.0, SQLAlchemy 2.0.19, psycopg2-binary 2.9.7
- **Command**: `gunicorn -w 4 -b 0.0.0.0:8000 main:app`
- **Workers**: 4 Gunicorn worker processes
- **Port**: 8000 (internal only)
- **Network**: Connected to `appnet` internal network
- **Dependency**: Waits for database health check before starting
- **Build Tools**: Installs build-essential, libpq-dev, postgresql-client

#### Frontend Service
- **Build Context**: `./frontend`
- **Base Image**: nginx:alpine
- **Files**: index.html, app.js, nginx.conf
- **Port**: 80 (container) mapped to ${FRONTEND_PORT} (host, default 8080)
- **Network**: Connected to `appnet` internal network
- **Dependency**: Starts after backend service

### Nginx Configuration
- **Static Files**: Served from `/usr/share/nginx/html`
- **Root Route** (`/`): Serves index.html and static assets
- **API Proxy** (`/api/*`): 
  - Docker Compose: Proxies to `http://backend:8000`
  - Docker Swarm: Proxies to `http://api:8000`
- **Proxy Headers**: 
  - Host: Forwarded from original request
  - X-Real-IP: Client's IP address
  - X-Forwarded-For: Full forwarding chain
- **Port**: Listens on port 80
- **Configuration Files**:
  - `nginx.conf`: Used in Docker Compose deployment
  - `nginx.swarm.conf`: Used in Docker Swarm deployment

## Current Capabilities

### Security Features Implemented
- **Input Sanitization**: HTML entity escaping to prevent XSS attacks
- **Null Byte Removal**: Prevents null byte injection attacks
- **Whitespace Normalization**: Prevents whitespace-based attacks
- **Security Logging**: Logs when input sanitization is applied
- **Client-side Validation**: Length and emptiness checks before submission
- **XSS Prevention**: All user content escaped using textContent before display

### Logging and Monitoring
- **Structured Logging**: Timestamp, logger name, level, and message
- **Request Logging**: All API requests logged with method and path
- **Success Logging**: Successful operations logged with details (IDs, counts)
- **Error Logging**: Failures logged with error details and stack traces
- **Configurable Log Levels**: DEBUG, INFO, WARNING, ERROR, CRITICAL
- **Database Query Logging**: Optional via DB_ECHO environment variable
- **Health Check Endpoints**: 
  - `/api/health` - Application health status
  - `/api/health/db` - Database connectivity verification

### Error Handling
- **Comprehensive Exception Handling**: All endpoints wrapped in try-catch
- **Graceful Degradation**: Frontend continues working even with partial failures
- **User-Friendly Error Messages**: Specific, actionable error messages
- **Automatic Recovery**: List refresh on errors to maintain sync

### Configuration Management
- **Environment-based Configuration**: All settings via environment variables
- **Sensible Defaults**: Application works out-of-box with default values
- **Flexible Deployment**: Easy to adjust for different environments

## Deployment Configurations

### Docker Compose Deployment
The application supports traditional Docker Compose deployment for single-host environments:

**Configuration File**: `src/docker-compose.yml`

**Key Features:**
- **Services**: `db`, `backend`, `frontend`
- **Network**: Internal `appnet` network for service communication
- **Health Checks**: Database health check before backend startup
- **Environment Variables**: Configured via `.env` file
- **Volumes**: `db_data` volume for PostgreSQL persistence
- **Port Mapping**: Frontend exposed on configurable port (default 8080)

**Environment Variables:**
- Database: `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `DB_URL`
- Application: `MAX_NAME_LENGTH`, `SERVER_HOST`, `SERVER_PORT`
- Logging: `LOG_LEVEL`, `DB_ECHO`
- Frontend: `FRONTEND_PORT`

### Docker Swarm Deployment
The application is fully compatible with Docker Swarm for production multi-host deployments:

**Configuration File**: `swarm/stack.yaml`

**Key Features:**
- **Services**: `db`, `api`, `web` (renamed for clarity)
- **Network**: External `appnet` network created before stack deployment
- **Secrets Management**: PostgreSQL credentials stored as Docker secrets
- **Placement Constraints**: 
  - Database on nodes labeled `role=db`
  - API and web on manager nodes
- **Scaling**: API service configured for 2 replicas
- **Health Checks**: Enhanced with longer intervals for distributed environment
- **Update Strategy**: Rolling updates with parallelism=1 and automatic rollback
- **Volume Management**: Persistent volume with bind mount to `/var/lib/postgres-data`

**Deployment Process:**
1. Initialize swarm cluster
2. Create external network: `docker network create --driver overlay appnet`
3. Create secrets for database credentials
4. Deploy stack: `docker stack deploy -c swarm/stack.yaml names`

**Differences from Compose:**
- Uses `DATABASE_URL` environment variable (Swarm standard) vs `DB_URL` (Compose)
- Backend supports both variables for compatibility
- Secrets management via Docker secrets instead of environment variables
- External network required for cross-stack communication
- Replica counts and placement constraints for high availability

### k3s/Kubernetes Deployment (In Development)
**Status**: Planned - Architecture prepared for Kubernetes deployment

**Planned Features:**
- Kubernetes manifests for deployments, services, and persistent volumes
- ConfigMaps for application configuration
- Secrets for database credentials
- Horizontal Pod Autoscaling for API tier
- Ingress controller for external access
- Namespace isolation
- Health checks using Kubernetes liveness and readiness probes

## Current Limitations

### Security
- No authentication or authorization (public access)
- No CSRF protection (stateless API)
- No rate limiting on API endpoints
- Credentials: Environment variables (Compose) or Docker secrets (Swarm)
- No HTTPS/TLS encryption (HTTP only)
- SQL injection protection via ORM parameterized queries
- XSS protection via HTML entity escaping on user input
- Input sanitization removes null bytes and normalizes whitespace

### Scalability
- Single database instance (no replication or read replicas)
- Backend horizontal scaling available in Swarm mode (configured for 2 replicas)
- Swarm provides built-in load balancing across API replicas
- No application-level caching layer (relies on database performance)
- No explicit connection pooling configuration (uses SQLAlchemy defaults)
- Stateless design supports multi-server deployments without session management

### Data Management
- No data validation beyond length limits
- No backup/restore mechanisms
- No data migration capabilities
- No soft deletes (permanent deletion only)
- No audit trail for changes
- No data export functionality
- Duplicate names allowed (no uniqueness constraint)

### Browser Compatibility
- Uses modern JavaScript (fetch API, async/await)
- No polyfills for older browsers (IE not supported)
- No progressive enhancement fallbacks
- Requires JavaScript enabled

### User Experience
- No pagination (all names loaded at once)
- No search/filter functionality
- No sorting options
- No bulk operations (e.g., delete multiple names)
- No undo functionality
- Confirmation dialog uses native browser confirm (not styled)

## Performance Characteristics

### Current Performance Profile
- **Startup Time**: ~10-15 seconds for full stack
  - Database initialization: ~5-8 seconds
  - Backend wait for DB health check: ~2-5 seconds
  - All services healthy: ~10-15 seconds total
- **Response Times**: Typically <100ms for API calls on local development
- **Memory Usage**: 
  - Database: ~50MB base + data
  - Backend: ~30MB per worker (120MB total for 4 workers)
  - Frontend: ~10MB (nginx)
  - Total: ~180MB + data size
- **Concurrent Users**: Limited by Gunicorn worker count (4 workers)
- **Database**: No query optimization, all queries scan entire table (acceptable for small datasets)

## Technology Stack

### Frontend
- **HTML5**: Semantic markup
- **CSS3**: Modern styling with flexbox, transitions, animations
- **JavaScript (ES6+)**: Async/await, fetch API, arrow functions
- **No frameworks**: Vanilla JavaScript for lightweight footprint

### Backend
- **Python 3.11**: Latest stable Python version
- **Flask 2.3.2**: Lightweight WSGI web framework
- **SQLAlchemy 2.0.19**: Modern SQL toolkit and ORM with future-style API
- **Gunicorn 20.1.0**: Production WSGI server with 4 worker processes
- **psycopg2-binary 2.9.7**: PostgreSQL adapter for Python

### Database
- **PostgreSQL 15**: Latest stable version
- **Schema**: Single table with auto-incrementing ID and timestamp

### Infrastructure
- **Docker Compose 3.8**: Container orchestration for single-host deployment
- **Docker Swarm**: Multi-host orchestration with service scaling and high availability
- **Nginx Alpine**: Lightweight web server for static files and reverse proxy
- **Docker Networks**: Isolated internal network for service communication
- **Docker Volumes**: Persistent storage for database data
- **Docker Secrets**: Secure credential management in Swarm mode
- **k3s/Kubernetes**: (Planned) Lightweight Kubernetes for cloud-native deployment

## Development and Build

### Backend Dockerfile
- Base: python:3.11-slim (minimal Debian-based image)
- Build tools: build-essential, libpq-dev, postgresql-client
- Python optimization: PYTHONDONTWRITEBYTECODE=1, PYTHONUNBUFFERED=1
- Dependencies: Installed via pip from requirements.txt
- Cleanup: Removes apt cache to reduce image size
- Working directory: /app
- Exposed port: 8000

### Frontend Dockerfile
- Base: nginx:alpine (minimal Alpine-based image)
- Files: nginx.conf, index.html, app.js
- Configuration: Custom nginx configuration
- Exposed port: 80

### Build Process
- Backend: Multi-stage build with dependency caching
- Frontend: Simple file copy, no build step required
- No minification or bundling (development-oriented setup)

## Operational Tooling

### Deployment Scripts (`ops/` directory)

#### init-swarm.sh
- Initializes Docker Swarm cluster on the current node
- Creates external overlay network (`appnet`)
- Sets up Docker secrets for PostgreSQL credentials
- Configures node labels for service placement
- Prepares persistent volume directory

#### deploy.sh
- Builds Docker images from source
- Tags images appropriately for Swarm deployment
- Deploys the application stack using `swarm/stack.yaml`
- Validates deployment success
- Shows service status and logs

#### validate.sh
- Performs comprehensive validation of the running application
- Tests all API endpoints (POST, GET, DELETE, health checks)
- Verifies database connectivity
- Checks service health and replica counts
- Reports success/failure for each test

#### verify.sh
- Quick verification script for deployment status
- Checks if services are running
- Displays service endpoints and access information
- Lighter weight than full validation

#### cleanup.sh
- Removes deployed stack
- Cleans up Docker resources (containers, networks, volumes)
- Optionally removes Docker secrets
- Resets environment to pre-deployment state

### Build Scripts

#### src/build-images.sh
- Builds backend and frontend Docker images
- Tags images for local registry
- Optimizes build caching
- Reports build success/failure

### Documentation
- **README.md**: Project overview and quickstart
- **QUICKSTART.md**: Step-by-step deployment guide
- **docs/OPERATIONS.md**: Detailed operational procedures
- **docs/EVIDENCE.md**: Testing evidence and validation results
- **ai-log/**: AI assistant interaction logs and development history

## Testing

### Automated Test Suite
**Location**: `src/backend/tests/`

**Test Framework**: pytest with comprehensive fixtures and configuration

#### Test Categories

**1. Infrastructure Tests** (`test_infrastructure.py`)
- Basic test infrastructure validation
- Python feature verification
- Fixture functionality testing
- Ensures test environment is properly configured

**2. API Endpoint Tests** (`test_api_endpoints.py`)
- POST /api/names: Valid names, empty names, whitespace handling, length validation
- GET /api/names: List retrieval, empty database handling, data format
- DELETE /api/names/{id}: Successful deletion, not found errors, invalid IDs
- Health endpoints: /api/health and /api/health/db functionality
- Comprehensive coverage of success and error cases

**3. Configuration Tests** (`test_configuration.py`)
- Environment variable parsing and defaults
- MAX_NAME_LENGTH validation
- Configuration documentation verification
- Docker Compose configuration validation
- Ensures proper configuration handling across deployments

**4. Logging Tests** (`test_logging.py`)
- Request logging for all endpoints
- Error logging for validation failures and exceptions
- Log level configuration
- Structured log format verification
- Security logging for input sanitization

**5. Validation Tests** (`test_validation.py`)
- Input sanitization (XSS prevention, null byte removal)
- Validation function correctness
- Edge cases and boundary conditions
- Error message accuracy

#### Test Execution
```bash
# Run all tests
cd src/backend
pytest

# Run with coverage
pytest --cov=. --cov-report=html

# Run specific test file
pytest tests/test_api_endpoints.py

# Run with verbose output
pytest -v
```

#### Test Configuration
- **pytest.ini**: Configures test discovery and output format
- **conftest.py**: Shared fixtures for database, client, and test data
- **Fresh Database Fixture**: Each test gets clean database state
- **Test Client**: Flask test client for API endpoint testing

### Manual Testing
**Documentation**: `src/backend/tests/TESTING.md`

Comprehensive manual testing checklist covering:
- Application startup and health checks
- CRUD operations with various inputs
- Error handling and edge cases
- UI interaction and user experience
- Security testing (XSS, SQL injection prevention)
- Performance and load testing guidelines

### Validation Script
**Script**: `ops/validate.sh`

End-to-end validation of deployed application:
- Service availability checks
- API endpoint functional testing
- Database connectivity verification
- Health check validation
- Integration testing across all tiers

## Performance Characteristics

### Docker Compose (Single Host)
- **Startup Time**: ~10-15 seconds for full stack
  - Database initialization: ~5-8 seconds
  - Backend wait for DB health check: ~2-5 seconds
  - All services healthy: ~10-15 seconds total
- **Response Times**: Typically <100ms for API calls on local development
- **Memory Usage**: 
  - Database: ~50MB base + data
  - Backend: ~30MB per worker (120MB total for 4 workers)
  - Frontend: ~10MB (nginx)
  - Total: ~180MB + data size
- **Concurrent Users**: Limited by Gunicorn worker count (4 workers)

### Docker Swarm (Multi-Host)
- **Startup Time**: ~20-30 seconds for full stack deployment
  - Stack deployment: ~5-10 seconds
  - Service convergence: ~10-15 seconds
  - Health checks and readiness: ~5-10 seconds
- **Response Times**: <200ms for API calls (includes overlay network latency)
- **Memory Usage**: 
  - Database: ~50MB base + data
  - API services: ~120MB per replica × 2 = ~240MB
  - Frontend: ~10MB (nginx)
  - Total: ~300MB + data size (multi-host)
- **Concurrent Users**: Improved capacity with 2 API replicas (8 workers total)
- **Load Distribution**: Swarm routing mesh balances requests across API replicas

### Database Performance
- **Query Optimization**: None (acceptable for small datasets)
- **Indexing**: Primary key index only (id column)
- **Query Pattern**: Simple SELECT, INSERT, DELETE operations
- **Connection Handling**: SQLAlchemy manages connection lifecycle
- **Scalability Limit**: Suitable for <10,000 names without optimization

This specification documents the current implementation as of November 4, 2025 on the `k3s-orchestration` branch, and serves as the baseline for k3s/Kubernetes deployment enhancements.