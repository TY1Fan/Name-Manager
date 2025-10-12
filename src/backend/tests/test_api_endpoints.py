"""
Tests for the API endpoints in main.py

This module tests all three API endpoints with various scenarios
including success cases, error cases, and edge conditions.
"""
import pytest
import json
import os

# Use SQLite for testing
os.environ['DB_URL'] = 'sqlite:///:memory:'

from main import engine, metadata


@pytest.fixture
def fresh_db():
    """Create a fresh database for each test."""
    # Create tables for each test
    metadata.create_all(engine)
    
    yield
    
    # Clean up after each test
    metadata.drop_all(engine)


class TestPostNamesEndpoint:
    """Test the POST /api/names endpoint."""
    
    def test_add_valid_name(self, client, fresh_db):
        """Test adding a valid name."""
        response = client.post('/api/names', 
                             json={'name': 'John Doe'},
                             content_type='application/json')
        
        assert response.status_code == 201
        data = response.get_json()
        assert data['name'] == 'John Doe'
        assert 'id' in data
        assert isinstance(data['id'], int)
    
    def test_add_empty_name(self, client, fresh_db):
        """Test adding an empty name."""
        response = client.post('/api/names',
                             json={'name': ''},
                             content_type='application/json')
        
        assert response.status_code == 400
        data = response.get_json()
        assert 'error' in data
    
    def test_add_whitespace_only_name(self, client, fresh_db):
        """Test adding a name with only whitespace."""
        response = client.post('/api/names',
                             json={'name': '   '},
                             content_type='application/json')
        
        assert response.status_code == 400
        data = response.get_json()
        assert 'error' in data
    
    def test_add_name_too_long(self, client, fresh_db):
        """Test adding a name that's too long."""
        long_name = 'a' * 51  # 51 characters
        response = client.post('/api/names',
                             json={'name': long_name},
                             content_type='application/json')
        
        assert response.status_code == 400
        data = response.get_json()
        assert 'error' in data
    
    def test_add_name_invalid_json(self, client, fresh_db):
        """Test adding a name with invalid JSON."""
        response = client.post('/api/names',
                             data='invalid json',
                             content_type='application/json')
        
        assert response.status_code == 400


class TestGetNamesEndpoint:
    """Test the GET /api/names endpoint."""
    
    def test_get_empty_list(self, client, fresh_db):
        """Test getting names when database is empty."""
        response = client.get('/api/names')
        
        assert response.status_code == 200
        data = response.get_json()
        assert isinstance(data, list)
        assert len(data) == 0
    
    def test_get_names_after_adding_one(self, client, fresh_db):
        """Test getting names after adding one name."""
        # Add a name first
        client.post('/api/names', 
                   json={'name': 'John Doe'},
                   content_type='application/json')
        
        # Get all names
        response = client.get('/api/names')
        
        assert response.status_code == 200
        data = response.get_json()
        assert isinstance(data, list)
        assert len(data) == 1
        assert data[0]['name'] == 'John Doe'
        assert 'id' in data[0]
        assert 'created_at' in data[0]
    
    def test_get_names_after_adding_multiple(self, client, fresh_db):
        """Test getting names after adding multiple names."""
        names = ['John Doe', 'Jane Smith', 'Bob Johnson']
        
        # Add multiple names
        for name in names:
            client.post('/api/names', 
                       json={'name': name},
                       content_type='application/json')
        
        # Get all names
        response = client.get('/api/names')
        
        assert response.status_code == 200
        data = response.get_json()
        assert isinstance(data, list)
        assert len(data) == 3
        
        # Check all names are present
        returned_names = [item['name'] for item in data]
        for name in names:
            assert name in returned_names


class TestDeleteNamesEndpoint:
    """Test the DELETE /api/names/<id> endpoint."""
    
    def test_delete_existing_name(self, client, fresh_db):
        """Test deleting an existing name."""
        # Add a name first
        add_response = client.post('/api/names', 
                                 json={'name': 'John Doe'},
                                 content_type='application/json')
        
        name_id = add_response.get_json()['id']
        
        # Delete the name
        response = client.delete(f'/api/names/{name_id}')
        
        assert response.status_code == 200
        data = response.get_json()
        assert data['deleted'] == name_id
    
    def test_delete_nonexistent_name(self, client, fresh_db):
        """Test deleting a name that doesn't exist."""
        response = client.delete('/api/names/999')
        
        assert response.status_code == 404
        data = response.get_json()
        assert 'error' in data
    
    def test_delete_name_removes_from_list(self, client, fresh_db):
        """Test that deleted name is removed from the list."""
        # Add two names
        add_response1 = client.post('/api/names', 
                                  json={'name': 'John Doe'},
                                  content_type='application/json')
        client.post('/api/names', 
                   json={'name': 'Jane Smith'},
                   content_type='application/json')
        
        name_id = add_response1.get_json()['id']
        
        # Verify both names exist
        response = client.get('/api/names')
        assert len(response.get_json()) == 2
        
        # Delete one name
        client.delete(f'/api/names/{name_id}')
        
        # Verify only one name remains
        response = client.get('/api/names')
        data = response.get_json()
        assert len(data) == 1
        assert data[0]['name'] == 'Jane Smith'


class TestAPIIntegration:
    """Test full workflow integration."""
    
    def test_full_crud_workflow(self, client, fresh_db):
        """Test complete Create, Read, Update, Delete workflow."""
        # Create
        add_response = client.post('/api/names', 
                                 json={'name': 'Test User'},
                                 content_type='application/json')
        assert add_response.status_code == 201
        name_id = add_response.get_json()['id']
        
        # Read (single item in list)
        get_response = client.get('/api/names')
        assert get_response.status_code == 200
        data = get_response.get_json()
        assert len(data) == 1
        assert data[0]['name'] == 'Test User'
        
        # Delete
        delete_response = client.delete(f'/api/names/{name_id}')
        assert delete_response.status_code == 200
        
        # Read (empty list)
        get_response = client.get('/api/names')
        assert get_response.status_code == 200
        assert len(get_response.get_json()) == 0


def test_invalid_endpoints(client, fresh_db):
    """Test invalid endpoint calls."""
    # Test unsupported HTTP methods
    response = client.put('/api/names')
    assert response.status_code == 405
    
    response = client.patch('/api/names/1')
    assert response.status_code == 405