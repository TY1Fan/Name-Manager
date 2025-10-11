## Using Environment Variables with Docker Compose

The docker-compose.yml file now uses environment variables instead of hardcoded values. This allows you to:

1. **Configure different environments** (development, staging, production)
2. **Keep sensitive data out of version control**
3. **Easily change configuration without modifying docker-compose.yml**

### Setup Instructions

1. **Copy the example environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit the .env file with your desired values:**
   ```bash
   # Example: Change database password for production
   POSTGRES_PASSWORD=your_secure_password_here
   
   # Example: Change frontend port
   FRONTEND_PORT=3000
   
   # Example: Enable debug logging
   LOG_LEVEL=DEBUG
   DB_ECHO=true
   ```

3. **Start the services:**
   ```bash
   cd src
   docker-compose up -d
   ```

### Environment Variables Used by Docker Compose

| Variable | Used By | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | db service | PostgreSQL username |
| `POSTGRES_PASSWORD` | db service | PostgreSQL password |
| `POSTGRES_DB` | db service | PostgreSQL database name |
| `DB_URL` | backend service | Full database connection URL |
| `MAX_NAME_LENGTH` | backend service | Maximum name length validation |
| `SERVER_HOST` | backend service | Backend server bind address |
| `SERVER_PORT` | backend service | Backend server port |
| `LOG_LEVEL` | backend service | Application logging level |
| `DB_ECHO` | backend service | Enable SQLAlchemy query logging |
| `FRONTEND_PORT` | frontend service | External port for web interface |

### Security Notes

- Never commit `.env` files with real passwords to version control
- Use strong passwords for production environments
- Consider using Docker secrets for sensitive data in production
- The `.env.example` file should contain safe default values only

### Example Configurations

**Development:**
```bash
POSTGRES_PASSWORD=dev_password
LOG_LEVEL=DEBUG
DB_ECHO=true
FRONTEND_PORT=3000
```

**Production:**
```bash
POSTGRES_PASSWORD=very_secure_production_password
LOG_LEVEL=WARNING
DB_ECHO=false
FRONTEND_PORT=80
MAX_NAME_LENGTH=100
```