# Names Manager - Current State Specification

## System Overview

The Names Manager is a 3-tier web application that allows users to manage a simple list of names through a web interface. The system consists of a PostgreSQL database, Flask REST API backend, and a static HTML/JavaScript frontend served by Nginx.

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
- `name` must not exceed 50 characters

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

**Behavior:**
- Returns 404 if ID doesn't exist
- Returns 200 with deleted ID if successful
- No cascading deletes (single table)

## User Interface Specification

### Main Interface
**URL**: `http://localhost:8080/`

### UI Components

#### Add Name Form
- **Input Field**: Text input with placeholder "Enter a name"
  - `maxlength="50"` HTML attribute
  - `required` attribute for basic validation
  - `autocomplete="off"` to prevent browser autocomplete
- **Submit Button**: "Add" button to submit the form
- **Validation**: Client-side validation prevents submission of empty or >50 character names

#### Names List Display
- **Header**: "Recorded names"
- **Empty State**: "Add names to view now." when no names exist
- **List Items**: Each name displayed with:
  - Name text (bold, 16px font)
  - Creation timestamp in localized format
  - Delete button (red background)

#### Delete Functionality
- **Confirmation**: JavaScript `confirm()` dialog before deletion
- **Button**: Individual delete button per name
- **Feedback**: List automatically refreshes after successful deletion

### User Experience Flow

#### Adding a Name
1. User types name in input field
2. Client-side validation checks length and emptiness
3. Form submission triggers AJAX POST request
4. Success: Input clears, list refreshes automatically
5. Error: Alert dialog shows error message

#### Viewing Names
1. Page loads and automatically fetches all names
2. Names displayed in chronological order by ID
3. Timestamps shown in user's local timezone format

#### Deleting a Name
1. User clicks delete button for specific name
2. Confirmation dialog appears
3. If confirmed, AJAX DELETE request sent
4. Success: List refreshes automatically
5. Error: Alert dialog shows error message

## System Behavior

### Application Startup Sequence
1. **Database Container**: PostgreSQL starts, runs init.sql to create schema
2. **Backend Container**: Waits for database health check, then starts Flask app with Gunicorn
3. **Frontend Container**: Nginx starts and serves static files immediately
4. **Health Checks**: Database responds to `pg_isready` before backend starts

### Error Handling

#### Backend Error Handling
- **Database Connection Errors**: Not explicitly handled, would result in 500 errors
- **Validation Errors**: Return 400 with descriptive error messages
- **Not Found Errors**: Return 404 with error message
- **JSON Parsing Errors**: Return 400 "Invalid JSON body"

#### Frontend Error Handling
- **Network Errors**: Alert dialog with error message
- **API Errors**: Parse error message from response and show in alert
- **Form Validation**: Alert for client-side validation failures

### Data Persistence
- **Database**: All data persisted in PostgreSQL with Docker volume `db_data`
- **Session State**: No session management, stateless application
- **Client State**: No local storage, all data fetched fresh on page load

## Configuration

### Environment Variables
- `DB_URL`: PostgreSQL connection string (default: `postgresql+psycopg2://names_user:names_pass@db:5432/namesdb`)

### Docker Configuration
- **Database**: postgres:15 image with persistent volume
- **Backend**: Custom Python image with Gunicorn (4 workers)
- **Frontend**: nginx:alpine with custom configuration
- **Networking**: Internal `appnet` network for service communication

### Nginx Configuration
- **Static Files**: Served from `/usr/share/nginx/html`
- **API Proxy**: `/api/*` requests proxied to `backend:8000`
- **Port**: Exposed on port 80, mapped to host port 8080

## Current Limitations

### Security
- No authentication or authorization
- No CSRF protection
- No rate limiting
- Database credentials in docker-compose.yml

### Scalability
- Single database instance (no replication)
- No load balancing
- No caching layer
- Fixed number of backend workers (4)

### Monitoring
- No application logging
- No health check endpoints (except database)
- No metrics collection
- No error tracking

### Data Management
- No data validation beyond length limits
- No backup/restore mechanisms
- No data migration capabilities
- No soft deletes (permanent deletion only)

### Browser Compatibility
- Uses modern JavaScript (fetch API, async/await)
- No polyfills for older browsers
- No progressive enhancement fallbacks

## Performance Characteristics

### Current Performance Profile
- **Startup Time**: ~10-15 seconds for full stack
- **Response Times**: Typically <100ms for API calls on local development
- **Memory Usage**: 
  - Database: ~50MB base + data
  - Backend: ~30MB per worker
  - Frontend: ~10MB (nginx)
- **Concurrent Users**: Limited by Gunicorn worker count (4)

This specification documents the current implementation as of October 10, 2025, and serves as the baseline for future refactoring and improvements.