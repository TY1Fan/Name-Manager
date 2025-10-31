# Names Manager - Current State Specification

## Executive Summary

**Status**: 🔴 **NON-FUNCTIONAL** - Critical integration bugs prevent core features from working

The Names Manager is a 3-tier web application designed to manage a simple list of names through a web interface. While the individual components are implemented with good practices (logging, error handling, input sanitization), **the application is currently non-functional due to three critical integration mismatches** between the frontend and backend:

1. **GET /api/names response format mismatch** - Names list never displays
2. **DELETE endpoint parameter type mismatch** - Deletion functionality broken  
3. **Frontend display logic incorrect** - Would display `[object Object]` even if API fixed

**Assessment**: Each tier is well-implemented in isolation, but the system requires integration fixes before it can function as intended.

## System Overview

The Names Manager consists of a PostgreSQL database, Flask REST API backend, and a static HTML/JavaScript frontend served by Nginx. The application uses Docker Compose for orchestration with proper health checks, environment-based configuration, and comprehensive logging.

## Architecture

### System Components
- **Database**: PostgreSQL 15 container
- **Backend**: Flask REST API with SQLAlchemy ORM
- **Frontend**: Static HTML/CSS/JavaScript served by Nginx
- **Orchestration**: Docker Compose for container management

### Network Architecture
- **External Access**: Port 8080 (Nginx frontend)
- **Internal Network**: `appnet` Docker network
- **Service Communication**: HTTP between frontend/backend, PostgreSQL protocol for database

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
[
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
```

**Response Details:**
- Returns array of all names ordered by `id` ascending
- `created_at` is ISO 8601 formatted timestamp
- Empty array returned if no names exist

**Error Response:**
- `500 Internal Server Error`: Database connection or query failures

**⚠️ Known Issue:**
- Frontend code expects response format `{"names": [...]}` but backend returns plain array `[...]`
- This mismatch causes the names list to display "No names found" even when names exist
- Affects frontend display functionality

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

**⚠️ Known Issue:**
- Frontend sends DELETE request with name (string) as path parameter: `/api/names/{name}`
- Backend expects integer ID in path: `/api/names/{id}`
- This type mismatch causes deletion functionality to fail
- Backend route requires `<int:name_id>` but receives string from frontend

#### GET /api/health
**Purpose**: Basic health check for the API service

**Request:** No body required

**Success Response (200 OK):**
```json
{
  "status": "healthy",
  "service": "Names Manager API",
  "version": "1.0.0",
  "timestamp": "2025-10-30T12:34:56.789000+00:00"
}
```

**Response Details:**
- Returns application status and metadata
- Timestamp in ISO 8601 format with UTC timezone

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
  - Name text (bold, 16px font)
  - Delete button (red background) on the right
  - Box shadow for depth
  - White background cards with rounded corners
  - 10px margin between items
- **Error State**: "Error loading names" message when API call fails

#### Delete Functionality
- **Confirmation**: JavaScript `confirm()` dialog before deletion
- **Button**: Individual delete button per name
  - Red background (#e53935)
  - Darker red on hover (#ab2822)
  - 14px font size
- **Feedback**: 
  - Success message displayed after deletion
  - List automatically refreshes to reflect changes
  - Error handling if deletion fails or name not found

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
- `DB_URL`: PostgreSQL connection string (default: `postgresql+psycopg2://names_user:names_pass@db:5432/namesdb`)

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
- **API Proxy** (`/api/*`): Proxies to `http://backend:8000`
- **Proxy Headers**: 
  - Host: Forwarded from original request
  - X-Real-IP: Client's IP address
  - X-Forwarded-For: Full forwarding chain
- **Port**: Listens on port 80

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

## Critical Issues

### Frontend-Backend Integration Mismatches

#### Issue 1: GET /api/names Response Format Mismatch
**Severity**: HIGH - Breaks core functionality

**Problem:**
- **Backend** (`main.py` line 156): Returns plain JSON array
  ```python
  return jsonify(results)  # Returns: [{id: 1, name: "John"}, ...]
  ```
- **Frontend** (`app.js` line 126): Expects nested object
  ```javascript
  if (data.names && data.names.length > 0)  // Expects: {names: [...]}
  ```

**Impact:**
- Names list always displays "No names found" even when database contains names
- Add name functionality appears to work but results not visible
- Application appears non-functional to users

**Resolution Required:**
- Option A: Change backend to return `{"names": results}`
- Option B: Change frontend to handle plain array `if (Array.isArray(data) && data.length > 0)`

#### Issue 2: DELETE Endpoint Parameter Type Mismatch
**Severity**: HIGH - Breaks deletion functionality

**Problem:**
- **Backend** (`main.py` line 163): Expects integer ID parameter
  ```python
  @app.route("/api/names/<int:name_id>", methods=["DELETE"])
  ```
- **Frontend** (`app.js` line 209): Sends name string
  ```javascript
  const res = await apiRequest(`/names/${encodeURIComponent(nameToDelete)}`, {method: "DELETE"})
  ```

**Impact:**
- DELETE requests fail with 404 (route not matched due to string parameter)
- Users cannot delete names
- Data accumulates without ability to remove entries

**Resolution Required:**
- Option A: Change frontend to pass ID instead of name (requires storing ID in DOM)
- Option B: Change backend to accept name string and delete by name match
- Option C: Add second delete endpoint that accepts name string

#### Issue 3: Frontend Display Format
**Severity**: MEDIUM - Inconsistent with backend data model

**Problem:**
- **Backend**: Provides full object with `id`, `name`, and `created_at`
- **Frontend** (`app.js` line 128-131): Only displays name string, ignores ID and timestamp
  ```javascript
  data.names.forEach((name) => {
    li.innerHTML = `<span>${escapeHtml(name)}</span>`  // Treats object as string
  })
  ```

**Impact:**
- If Issue 1 is resolved, this code would attempt to display `[object Object]` instead of names
- Timestamps not shown to user despite being available
- ID not tracked for proper deletion

**Resolution Required:**
- Update frontend to properly destructure and display object properties
- Store ID as data attribute for deletion functionality

## Current Limitations

### Security
- No authentication or authorization
- No CSRF protection
- No rate limiting
- Database credentials in environment variables (should use secrets management)
- No HTTPS/TLS encryption
- No SQL injection protection beyond ORM (using parameterized queries)

### Scalability
- Single database instance (no replication)
- No horizontal scaling for backend (fixed 4 workers)
- No load balancing
- No caching layer
- No connection pooling configuration
- No session management for multi-server deployments

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
- **Docker Compose 3.8**: Container orchestration
- **Nginx Alpine**: Lightweight web server for static files and reverse proxy
- **Docker Networks**: Isolated internal network for service communication
- **Docker Volumes**: Persistent storage for database data

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

This specification documents the current implementation as of October 30, 2025, and serves as the baseline for future refactoring and improvements.