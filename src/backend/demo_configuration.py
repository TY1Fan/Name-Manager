#!/usr/bin/env python3
"""
Configuration demo script for the Names Manager application.

This script demonstrates how environment variables control application behavior.
"""

import os
import subprocess
import sys

def demo_configuration():
    """Demonstrate configuration options."""
    print("=== Names Manager Configuration Demo ===\n")
    
    print("1. DEFAULT CONFIGURATION:")
    print("   MAX_NAME_LENGTH: 50 (default)")
    print("   LOG_LEVEL: INFO (default)")
    print("   SERVER_HOST: 0.0.0.0 (default)")
    print("   SERVER_PORT: 8000 (default)")
    print("   DB_ECHO: false (default)")
    print()
    
    print("2. CUSTOM CONFIGURATION EXAMPLE:")
    print("   Setting environment variables:")
    print("   export MAX_NAME_LENGTH=100")
    print("   export LOG_LEVEL=DEBUG")
    print("   export SERVER_HOST=127.0.0.1")
    print("   export SERVER_PORT=9000")
    print("   export DB_ECHO=true")
    print()
    
    print("3. CONFIGURATION SOURCES (in order of priority):")
    print("   1. Environment variables")
    print("   2. Default values in code")
    print()
    
    print("4. DOCKER COMPOSE CONFIGURATION:")
    print("   The docker-compose.yml file sets environment variables for the backend service:")
    print("   - DB_URL: Connection to PostgreSQL database")
    print("   - MAX_NAME_LENGTH: 50")
    print("   - LOG_LEVEL: INFO")
    print("   - DB_ECHO: false")
    print()
    
    print("5. EXAMPLE .ENV FILE:")
    print("   Copy .env.example to .env and modify values:")
    env_example_path = '/Users/tohyifan/HW_3/.env.example'
    if os.path.exists(env_example_path):
        with open(env_example_path, 'r') as f:
            lines = f.readlines()[:10]  # Show first 10 lines
            for line in lines:
                print(f"   {line.rstrip()}")
        print("   ... (see .env.example for complete configuration)")
    else:
        print("   .env.example file not found!")
    print()
    
    print("6. TESTING CONFIGURATION:")
    print("   To test with custom MAX_NAME_LENGTH:")
    print("   MAX_NAME_LENGTH=25 python -m pytest tests/test_configuration.py -v")
    print()
    
    print("=== End Configuration Demo ===")

def test_current_config():
    """Show current configuration values."""
    print("\n=== CURRENT CONFIGURATION VALUES ===")
    
    # Import main to get current config
    sys.path.append('/Users/tohyifan/HW_3/src/backend')
    import main
    
    print(f"MAX_NAME_LENGTH: {main.MAX_NAME_LENGTH}")
    print(f"LOG_LEVEL: {main.LOG_LEVEL}")
    print(f"SERVER_HOST: {main.SERVER_HOST}")
    print(f"SERVER_PORT: {main.SERVER_PORT}")
    print(f"DB_ECHO: {main.DB_ECHO}")
    print(f"DB_URL: {main.DB_URL}")
    print("=====================================\n")

if __name__ == "__main__":
    demo_configuration()
    test_current_config()