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

## Next Steps

1. Add validation function tests (`test_validation.py`)
2. Add API endpoint tests (`test_main.py`)
3. Increase test coverage to meet 60% target