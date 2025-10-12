# Backend Testing Guide

## Testing Infrastructure

This backend includes a testing infrastructure using pytest for unit testing and code coverage reporting.

## Setup for Testing

### Install Development Dependencies

```bash
pip install -r requirements-dev.txt
```

### Run Tests

```bash
# Run all tests
python -m pytest

# Run tests with coverage
python -m pytest --cov

# Run tests with detailed coverage report
python -m pytest --cov --cov-report=html

# Run tests in verbose mode
python -m pytest -v
```

## Test Structure

```
backend/
├── tests/
│   ├── __init__.py              # Test package marker
│   ├── conftest.py              # Pytest fixtures and configuration
│   └── test_infrastructure.py   # Basic infrastructure tests
├── pytest.ini                  # Pytest configuration
└── requirements-dev.txt         # Development dependencies
```

## Testing Configuration

The testing setup includes:

- **pytest**: Testing framework
- **pytest-cov**: Coverage reporting
- **pytest-flask**: Flask-specific testing utilities

## Coverage Goals

- Target: 60% minimum code coverage
- Current coverage is displayed after running tests with `--cov`
- HTML coverage reports are generated in `htmlcov/` directory

## Test Database

Tests use SQLite in-memory database to avoid dependency on PostgreSQL during development.

## Writing Tests

### Basic Test Structure

```python
def test_something():
    assert True
```

### Using Fixtures

```python
def test_with_client(client):
    response = client.get('/health')
    assert response.status_code == 200
```

### Test Classes

```python
class TestAPI:
    def test_endpoint(self, client):
        response = client.post('/api/names', json={'name': 'Test'})
        assert response.status_code == 201
```

## Testing Results

### Current Status
- Infrastructure tests: ✅ Passing (4 tests)
- Validation tests: ✅ Passing (12 tests, 100% coverage of validation function)
- API endpoint tests: ✅ Passing (13 tests)

### Test Coverage Summary
- **Total Tests**: 36 tests
- **Overall Coverage**: 85% of main.py
- **Test Categories**:
  - Infrastructure: 4 tests - Basic pytest setup and fixture testing
  - Validation: 12 tests - Comprehensive validation function testing
  - API Endpoints: 13 tests - Full CRUD operations testing
  - Logging: 7 tests - Comprehensive logging functionality testing
  
### API Endpoint Test Coverage
- **POST /api/names**: 5 tests
  - Valid name addition
  - Empty name validation
  - Whitespace-only name validation
  - Name length validation (too long)
  - Invalid JSON handling
  
- **GET /api/names**: 3 tests
  - Empty list retrieval
  - Single name retrieval
  - Multiple names retrieval with ordering
  
- **DELETE /api/names/<id>**: 3 tests  
  - Existing name deletion
  - Non-existent name deletion (404 error)
  - Verification of removal from list
  
- **Integration**: 2 tests
  - Full CRUD workflow
  - Invalid HTTP methods (405 errors)

- **Logging**: 7 tests
  - Request/response logging verification
  - Error condition logging verification  
  - Configuration validation
  - Log message content verification

## Logging Features

The application now includes comprehensive logging for debugging and monitoring:

### Log Levels
- **INFO**: Request/response tracking, successful operations
- **WARNING**: Validation failures, not found errors  
- **ERROR**: Database errors, internal server errors
- **DEBUG**: Detailed processing information (when enabled)

### Log Format
```
YYYY-MM-DD HH:MM:SS - main - LEVEL - MESSAGE
```

### What Gets Logged
- **Application Startup**: Server start message with host/port
- **API Requests**: Each endpoint request with method and path
- **Successful Operations**: Database operations with details
- **Validation Errors**: Invalid input with specific error messages
- **Database Errors**: SQL operation failures with error details
- **Not Found Errors**: Attempts to access non-existent resources

### Example Log Output
```
2025-10-11 12:30:00 - main - INFO - Names Manager API starting up on host=0.0.0.0, port=8000
2025-10-11 12:30:01 - main - INFO - POST /api/names - Request received
2025-10-11 12:30:01 - main - INFO - POST /api/names - Successfully added name 'John Doe' with ID 1
2025-10-11 12:30:02 - main - WARNING - POST /api/names - Validation failed: Name cannot be empty.
```

## Configuration

The application uses environment variables for configuration, making it flexible for different deployment environments.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_URL` | `postgresql+psycopg2://names_user:names_pass@db:5432/namesdb` | Database connection URL |
| `MAX_NAME_LENGTH` | `50` | Maximum allowed length for name field |
| `SERVER_HOST` | `0.0.0.0` | Host address to bind the server |
| `SERVER_PORT` | `8000` | Port number for the server |
| `LOG_LEVEL` | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL) |
| `DB_ECHO` | `false` | Enable SQLAlchemy query logging (true/false) |

### Configuration Files

- **`.env.example`**: Template for environment configuration
- **`docker-compose.yml`**: Container environment configuration
- Copy `.env.example` to `.env` and modify values as needed

### Examples

```bash
# Development environment
export MAX_NAME_LENGTH=100
export LOG_LEVEL=DEBUG
export DB_ECHO=true

# Production environment  
export LOG_LEVEL=WARNING
export MAX_NAME_LENGTH=50
export DB_ECHO=false
```

## Tasks Completed ✅

1. ✅ **Task 1.1**: Set Up Basic Testing Infrastructure
   - Created `requirements-dev.txt` with testing dependencies
   - Configured `pytest.ini` with test settings
   - Set up `conftest.py` with fixtures and mocking
   - Created basic infrastructure tests in `test_infrastructure.py`

2. ✅ **Task 1.2**: Create Basic Validation Tests
   - Comprehensive validation function testing in `test_validation.py`
   - 12 test cases covering all validation scenarios
   - 100% coverage of the validation function

3. ✅ **Task 1.3**: Create Basic API Endpoint Tests
   - Full API endpoint testing in `test_api_endpoints.py`
   - 13 test cases covering all three REST endpoints
   - Complete CRUD workflow testing
   - Error handling and edge case testing

4. ✅ **Task 1.4**: Add Basic Logging to Backend
   - Added comprehensive logging throughout the application
   - Logging configuration with INFO level and readable format
   - Request/response logging for all API endpoints
   - Error and validation failure logging
   - Database operation logging with success/failure tracking

5. ✅ **Task 1.5**: Extract Configuration to Environment Variables
   - Externalized all hardcoded configuration values
   - Configurable MAX_NAME_LENGTH via environment variable
   - Configurable database, server, and logging settings
   - Created comprehensive .env.example documentation
   - Updated docker-compose.yml to use environment variable substitution
   - All services (database, backend, frontend) now use .env configuration