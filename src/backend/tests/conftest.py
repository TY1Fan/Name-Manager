import pytest
import tempfile
import os
import sys

# Mock the missing modules for testing without PostgreSQL
class MockPsycopg2:
    paramstyle = 'pyformat'
    
    class extensions:
        ISOLATION_LEVEL_AUTOCOMMIT = 0
    
    class extras:
        pass
    
    def connect(self, *args, **kwargs):
        pass

sys.modules['psycopg2'] = MockPsycopg2()
sys.modules['psycopg2.extensions'] = MockPsycopg2.extensions
sys.modules['psycopg2.extras'] = MockPsycopg2.extras

# Fix werkzeug version issue in Flask test client
import werkzeug
if not hasattr(werkzeug, '__version__'):
    werkzeug.__version__ = '2.3.6'

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