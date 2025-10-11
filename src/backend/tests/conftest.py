import pytest
import tempfile
import os
import sys

# Mock the missing modules for testing without PostgreSQL
class MockModule:
    pass

sys.modules['psycopg2'] = MockModule()

from sqlalchemy import create_engine, text


@pytest.fixture
def app():
    """Create a test Flask application."""
    # Import here to avoid circular imports and ensure mocking works
    from main import app, metadata
    
    # Configure app for testing
    app.config['TESTING'] = True
    app.config['DATABASE_URL'] = 'sqlite:///:memory:'
    
    return app


@pytest.fixture
def client(app):
    """Create a test client for the Flask application."""
    return app.test_client()


@pytest.fixture
def sample_names():
    """Sample data for testing."""
    return [
        {"name": "John Doe"},
        {"name": "Jane Smith"},
        {"name": "Bob Johnson"}
    ]