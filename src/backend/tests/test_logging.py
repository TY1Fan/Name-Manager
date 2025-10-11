"""
Tests for logging functionality in the Names Manager application.

This module tests that logging is working correctly for various scenarios.
"""
import pytest
import json
import logging
from unittest.mock import patch
import os

# Use SQLite for testing
os.environ['DB_URL'] = 'sqlite:///:memory:'

from main import engine, metadata


@pytest.fixture
def fresh_db():
    """Create a fresh database for each test."""
    metadata.create_all(engine)
    yield
    metadata.drop_all(engine)


class TestLogging:
    """Test logging functionality."""
    
    def test_post_endpoint_logging(self, client, fresh_db, caplog):
        """Test that POST endpoint logs correctly."""
        with caplog.at_level(logging.INFO):
            response = client.post('/api/names', 
                                 json={'name': 'Test User'},
                                 content_type='application/json')
        
        assert response.status_code == 201
        
        # Check log messages
        log_messages = caplog.text
        assert "POST /api/names - Request received" in log_messages
        assert "Successfully added name 'Test User'" in log_messages
    
    def test_post_validation_error_logging(self, client, fresh_db, caplog):
        """Test that validation errors are logged."""
        with caplog.at_level(logging.WARNING):
            response = client.post('/api/names',
                                 json={'name': ''},
                                 content_type='application/json')
        
        assert response.status_code == 400
        
        # Check warning log
        log_messages = caplog.text
        assert "Validation failed" in log_messages
    
    def test_post_invalid_json_logging(self, client, fresh_db, caplog):
        """Test that invalid JSON is logged."""
        with caplog.at_level(logging.WARNING):
            response = client.post('/api/names',
                                 data='invalid json',
                                 content_type='application/json')
        
        assert response.status_code == 400
        
        # Check warning log
        log_messages = caplog.text
        assert "Invalid JSON body received" in log_messages
    
    def test_get_endpoint_logging(self, client, fresh_db, caplog):
        """Test that GET endpoint logs correctly."""
        # Add a name first
        client.post('/api/names', 
                   json={'name': 'Test User'},
                   content_type='application/json')
        
        with caplog.at_level(logging.INFO):
            response = client.get('/api/names')
        
        assert response.status_code == 200
        
        # Check log messages
        log_messages = caplog.text
        assert "GET /api/names - Request received" in log_messages
        assert "Successfully retrieved 1 names" in log_messages
    
    def test_delete_endpoint_logging(self, client, fresh_db, caplog):
        """Test that DELETE endpoint logs correctly."""
        # Add a name first
        add_response = client.post('/api/names', 
                                 json={'name': 'Test User'},
                                 content_type='application/json')
        name_id = add_response.get_json()['id']
        
        with caplog.at_level(logging.INFO):
            response = client.delete(f'/api/names/{name_id}')
        
        assert response.status_code == 200
        
        # Check log messages
        log_messages = caplog.text
        assert f"DELETE /api/names/{name_id} - Request received" in log_messages
        assert f"Successfully deleted name" in log_messages
    
    def test_delete_not_found_logging(self, client, fresh_db, caplog):
        """Test that DELETE not found is logged."""
        with caplog.at_level(logging.WARNING):
            response = client.delete('/api/names/999')
        
        assert response.status_code == 404
        
        # Check warning log
        log_messages = caplog.text
        assert "DELETE /api/names/999 - Name not found" in log_messages


def test_logging_configuration():
    """Test that logging is configured correctly."""
    # Import logger from main module
    from main import logger
    
    # Check logger exists and has correct name
    assert logger.name == 'main'
    
    # Check that logging is configured (level should be reasonable)
    # Note: During testing, the level might be different due to test environment
    assert logger.getEffectiveLevel() in [logging.DEBUG, logging.INFO, logging.WARNING, logging.ERROR]