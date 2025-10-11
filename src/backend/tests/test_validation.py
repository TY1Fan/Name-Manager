"""
Test cases for the validation function in main.py

This module tests the name validation logic with various inputs
including valid names, invalid names, and edge cases.
"""
import pytest
import sys
import os

# Mock psycopg2 and its related modules before importing main
class MockPsycopg2:
    paramstyle = 'pyformat'
    
    class extensions:
        ISOLATION_LEVEL_AUTOCOMMIT = 0
    
    def connect(self, *args, **kwargs):
        pass

sys.modules['psycopg2'] = MockPsycopg2()
sys.modules['psycopg2.extensions'] = MockPsycopg2.extensions

# Mock the database URL to use SQLite for testing
os.environ['DB_URL'] = 'sqlite:///:memory:'

from main import validation


class TestValidation:
    """Test class for the validation function."""

    def test_valid_names(self):
        """Test validation with valid name inputs."""
        # Normal names should pass
        valid, result = validation("John Doe")
        assert valid is True
        assert result == "John Doe"
        
        # Single names should pass
        valid, result = validation("Alice")
        assert valid is True
        assert result == "Alice"
        
        # Names with hyphens should pass
        valid, result = validation("Mary-Jane")
        assert valid is True
        assert result == "Mary-Jane"
        
        # Names with apostrophes should pass
        valid, result = validation("O'Connor")
        assert valid is True
        assert result == "O'Connor"

    def test_whitespace_handling(self):
        """Test validation handles whitespace correctly."""
        # Leading whitespace should be stripped
        valid, result = validation("  John")
        assert valid is True
        assert result == "John"
        
        # Trailing whitespace should be stripped
        valid, result = validation("John  ")
        assert valid is True
        assert result == "John"
        
        # Both leading and trailing whitespace
        valid, result = validation("  John Doe  ")
        assert valid is True
        assert result == "John Doe"
        
        # Multiple spaces between words should be preserved
        valid, result = validation("John  Doe")
        assert valid is True
        assert result == "John  Doe"

    def test_empty_names(self):
        """Test validation rejects empty names."""
        # Empty string should fail
        valid, message = validation("")
        assert valid is False
        assert message == "Name cannot be empty."
        
        # Whitespace-only should fail
        valid, message = validation("   ")
        assert valid is False
        assert message == "Name cannot be empty."
        
        # Tabs and newlines should fail
        valid, message = validation("\t\n  ")
        assert valid is False
        assert message == "Name cannot be empty."

    def test_length_limits(self):
        """Test validation enforces length limits."""
        # Exactly 50 characters should pass
        name_50_chars = "a" * 50
        valid, result = validation(name_50_chars)
        assert valid is True
        assert result == name_50_chars
        assert len(result) == 50
        
        # 51 characters should fail
        name_51_chars = "a" * 51
        valid, message = validation(name_51_chars)
        assert valid is False
        assert message == "Max length is 50 characters."
        
        # Much longer name should fail
        name_100_chars = "a" * 100
        valid, message = validation(name_100_chars)
        assert valid is False
        assert message == "Max length is 50 characters."

    def test_edge_cases(self):
        """Test validation with edge cases."""
        # Single character should pass
        valid, result = validation("A")
        assert valid is True
        assert result == "A"
        
        # Numbers in names should pass
        valid, result = validation("John2")
        assert valid is True
        assert result == "John2"
        
        # Special characters should pass
        valid, result = validation("José María")
        assert valid is True
        assert result == "José María"

    def test_boundary_conditions(self):
        """Test validation at exact boundary conditions."""
        # Test exactly at the 50 character limit with whitespace
        # 48 chars + 2 spaces = 50 after stripping should pass
        name_with_spaces = "  " + "a" * 48
        valid, result = validation(name_with_spaces)
        assert valid is True
        assert result == "a" * 48
        assert len(result) == 48
        
        # 49 chars + leading space = 49 after stripping should pass
        name_49_with_space = " " + "a" * 49
        valid, result = validation(name_49_with_space)
        assert valid is True
        assert result == "a" * 49
        assert len(result) == 49

    def test_none_input(self):
        """Test validation handles None input gracefully."""
        # This should raise an AttributeError since None.strip() fails
        # This tests the current behavior - we might want to improve this later
        with pytest.raises(AttributeError):
            validation(None)

    def test_non_string_input(self):
        """Test validation with non-string inputs."""
        # Integer input should raise AttributeError
        with pytest.raises(AttributeError):
            validation(123)
        
        # List input should raise AttributeError  
        with pytest.raises(AttributeError):
            validation(["John", "Doe"])


# Additional function-based tests for specific scenarios
def test_validation_return_format():
    """Test that validation always returns a tuple."""
    # Valid input returns (True, str)
    result = validation("John")
    assert isinstance(result, tuple)
    assert len(result) == 2
    assert isinstance(result[0], bool)
    assert isinstance(result[1], str)
    
    # Invalid input returns (False, str)
    result = validation("")
    assert isinstance(result, tuple)
    assert len(result) == 2
    assert isinstance(result[0], bool)
    assert isinstance(result[1], str)


def test_validation_preserves_case():
    """Test that validation preserves the original case."""
    valid, result = validation("jOhN dOe")
    assert valid is True
    assert result == "jOhN dOe"  # Case should be preserved


def test_validation_error_messages():
    """Test that error messages are consistent and helpful."""
    # Empty name error message
    _, message = validation("")
    assert "empty" in message.lower()
    
    # Length error message
    _, message = validation("a" * 51)
    assert "50" in message
    assert "length" in message.lower()


def test_validation_with_unicode():
    """Test validation with unicode characters."""
    # Unicode characters should be handled correctly
    valid, result = validation("José")
    assert valid is True
    assert result == "José"
    
    # Emoji (if supported)
    valid, result = validation("John 👍")
    assert valid is True
    assert result == "John 👍"
    
    # Unicode length counting should be correct
    # Note: This tests if length is counted correctly for unicode
    unicode_name = "é" * 50  # 50 unicode characters
    valid, result = validation(unicode_name)
    assert valid is True
    assert len(result) == 50