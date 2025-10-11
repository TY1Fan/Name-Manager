#!/usr/bin/env python3
"""
Demo script to show logging functionality in the Names Manager API.

This script makes some API calls to demonstrate the logging output.
"""

import requests
import time
import json

# Note: This would normally connect to a running server
# For demo purposes, we'll just show what the requests would look like

def demo_logging():
    """Demonstrate what the logging would look like."""
    print("=== Names Manager API Logging Demo ===\n")
    
    print("When the server starts, you would see:")
    print("2025-10-11 12:30:00 - main - INFO - Names Manager API starting up on host=0.0.0.0, port=8000")
    print()
    
    print("When making a POST request with valid data:")
    print("Request: POST /api/names with {'name': 'John Doe'}")
    print("Logs would show:")
    print("2025-10-11 12:30:01 - main - INFO - POST /api/names - Request received")
    print("2025-10-11 12:30:01 - main - INFO - POST /api/names - Successfully added name 'John Doe' with ID 1")
    print()
    
    print("When making a POST request with invalid data:")
    print("Request: POST /api/names with {'name': ''}")
    print("Logs would show:")
    print("2025-10-11 12:30:02 - main - INFO - POST /api/names - Request received")
    print("2025-10-11 12:30:02 - main - WARNING - POST /api/names - Validation failed: Name cannot be empty.")
    print()
    
    print("When making a GET request:")
    print("Request: GET /api/names")
    print("Logs would show:")
    print("2025-10-11 12:30:03 - main - INFO - GET /api/names - Request received")
    print("2025-10-11 12:30:03 - main - INFO - GET /api/names - Successfully retrieved 1 names")
    print()
    
    print("When making a DELETE request for existing name:")
    print("Request: DELETE /api/names/1")
    print("Logs would show:")
    print("2025-10-11 12:30:04 - main - INFO - DELETE /api/names/1 - Request received")
    print("2025-10-11 12:30:04 - main - INFO - DELETE /api/names/1 - Successfully deleted name")
    print()
    
    print("When making a DELETE request for non-existent name:")
    print("Request: DELETE /api/names/999")
    print("Logs would show:")
    print("2025-10-11 12:30:05 - main - INFO - DELETE /api/names/999 - Request received")
    print("2025-10-11 12:30:05 - main - WARNING - DELETE /api/names/999 - Name not found")
    print()
    
    print("=== End Demo ===")

if __name__ == "__main__":
    demo_logging()