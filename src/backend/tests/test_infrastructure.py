"""
Basic test to verify testing infrastructure is working.
"""
import pytest


def test_infrastructure_setup():
    """Test that the testing infrastructure is properly configured."""
    assert True, "Testing infrastructure is working"


def test_basic_python_features():
    """Test basic Python functionality to ensure environment is correct."""
    # Test basic data types
    assert isinstance("hello", str)
    assert isinstance(42, int)
    assert isinstance([1, 2, 3], list)
    
    # Test basic operations
    assert 2 + 2 == 4
    assert "hello".upper() == "HELLO"


class TestInfrastructure:
    """Test class to verify class-based testing works."""
    
    def test_class_based_test(self):
        """Test that class-based tests work."""
        assert 1 + 1 == 2
    
    def test_with_fixtures(self, sample_names):
        """Test that fixtures are working."""
        assert len(sample_names) == 3
        assert sample_names[0]["name"] == "John Doe"