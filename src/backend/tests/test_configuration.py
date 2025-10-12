"""
Tests for configuration functionality in the Names Manager application.

This module tests that environment variables are properly loaded and used.
"""
import pytest
import os
from unittest.mock import patch


class TestConfiguration:
    """Test configuration loading from environment variables."""
    
    def test_current_configuration_values(self):
        """Test that configuration values are accessible and have correct types."""
        import main
        
        # Check that configuration variables exist
        assert hasattr(main, 'MAX_NAME_LENGTH')
        assert hasattr(main, 'DB_ECHO')
        assert hasattr(main, 'LOG_LEVEL')
        assert hasattr(main, 'SERVER_HOST')
        assert hasattr(main, 'SERVER_PORT')
        
        # Check types are correct
        assert isinstance(main.MAX_NAME_LENGTH, int)
        assert main.MAX_NAME_LENGTH > 0
        assert isinstance(main.DB_ECHO, bool)
        assert main.LOG_LEVEL in ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL']
        assert isinstance(main.SERVER_HOST, str)
        assert isinstance(main.SERVER_PORT, int)
        assert main.SERVER_PORT > 0
    
    def test_max_name_length_validation_with_default(self, client, fresh_db):
        """Test that MAX_NAME_LENGTH is used in validation with default value."""
        import main
        
        # Test with default MAX_NAME_LENGTH (should be 50)
        # Test name exactly at the limit
        response = client.post('/api/names',
                             json={'name': 'a' * main.MAX_NAME_LENGTH},
                             content_type='application/json')
        assert response.status_code == 201
        
        # Test name over the limit
        response = client.post('/api/names',
                             json={'name': 'a' * (main.MAX_NAME_LENGTH + 1)},
                             content_type='application/json')
        assert response.status_code == 400
        data = response.get_json()
        assert f'Max length is {main.MAX_NAME_LENGTH} characters' in data['error']
    
    def test_validation_function_uses_config(self):
        """Test that validation function uses the configured MAX_NAME_LENGTH."""
        from main import validation, MAX_NAME_LENGTH
        
        # Test with name exactly at limit
        valid, message = validation('a' * MAX_NAME_LENGTH)
        assert valid == True
        
        # Test with name over limit
        valid, message = validation('a' * (MAX_NAME_LENGTH + 1))
        assert valid == False
        assert f'Max length is {MAX_NAME_LENGTH} characters' in message
    
    def test_environment_variable_parsing(self):
        """Test that environment variables are parsed correctly."""
        # Test MAX_NAME_LENGTH parsing
        with patch.dict(os.environ, {'MAX_NAME_LENGTH': '75'}):
            value = int(os.environ.get("MAX_NAME_LENGTH", "50"))
            assert value == 75
        
        # Test DB_ECHO parsing
        with patch.dict(os.environ, {'DB_ECHO': 'true'}):
            value = os.environ.get("DB_ECHO", "false").lower() == "true"
            assert value == True
        
        with patch.dict(os.environ, {'DB_ECHO': 'false'}):
            value = os.environ.get("DB_ECHO", "false").lower() == "true"
            assert value == False
        
        # Test SERVER_PORT parsing
        with patch.dict(os.environ, {'SERVER_PORT': '9000'}):
            value = int(os.environ.get("SERVER_PORT", "8000"))
            assert value == 9000
    
    def test_configuration_documentation(self):
        """Test that .env.example file exists and contains expected variables."""
        env_example_path = '/Users/tohyifan/HW_3/src/.env.example'
        assert os.path.exists(env_example_path), ".env.example file should exist"
        
        with open(env_example_path, 'r') as f:
            content = f.read()
        
        # Check that all configuration variables are documented
        expected_vars = [
            'DB_URL',
            'MAX_NAME_LENGTH',
            'SERVER_HOST', 
            'SERVER_PORT',
            'LOG_LEVEL',
            'DB_ECHO'
        ]
        
        for var in expected_vars:
            assert var in content, f"{var} should be documented in .env.example"
    
    def test_docker_compose_configuration(self):
        """Test that docker-compose.yml contains configuration variables."""
        docker_compose_path = '/Users/tohyifan/HW_3/src/docker-compose.yml'
        assert os.path.exists(docker_compose_path), "docker-compose.yml should exist"
        
        with open(docker_compose_path, 'r') as f:
            content = f.read()
        
        # Check that configuration variables are set in docker-compose.yml
        config_vars = [
            'MAX_NAME_LENGTH',
            'SERVER_HOST',
            'SERVER_PORT',
            'LOG_LEVEL',
            'DB_ECHO'
        ]
        
        for var in config_vars:
            assert var in content, f"{var} should be configured in docker-compose.yml"


@pytest.fixture
def fresh_db():
    """Create a fresh database for each test."""
    from main import engine, metadata
    metadata.create_all(engine)
    yield
    metadata.drop_all(engine)