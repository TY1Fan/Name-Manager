import os
import logging
import html
import re
from flask import Flask, request, jsonify
from sqlalchemy import create_engine, Table, Column, Integer, Text, TIMESTAMP, MetaData, select, func

# Configuration from environment variables
# Support both DATABASE_URL (Swarm/standard) and DB_URL (legacy Compose)
# DATABASE_URL takes priority for compatibility with Docker Swarm deployments
DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    os.environ.get(
        "DB_URL",
        "postgresql+psycopg2://names_user:names_pass@db:5432/namesdb"
    )
)

MAX_NAME_LENGTH = int(os.environ.get("MAX_NAME_LENGTH", "50"))
DB_ECHO = os.environ.get("DB_ECHO", "false").lower() == "true"
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()
SERVER_HOST = os.environ.get("SERVER_HOST", "0.0.0.0")
SERVER_PORT = int(os.environ.get("SERVER_PORT", "8000"))

engine = create_engine(DATABASE_URL, echo=DB_ECHO, future=True)
metadata = MetaData()

table = Table(
    "names",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("name", Text, nullable=False),
    Column("created_at", TIMESTAMP, server_default=func.now())
)

metadata.create_all(engine)

app = Flask(__name__)

# Configure logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

logger = logging.getLogger(__name__)

def sanitize_input(text: str) -> str:
    """
    Sanitize user input to prevent XSS attacks and other malicious content.
    
    Args:
        text (str): Raw user input
        
    Returns:
        str: Sanitized text safe for storage and display
    """
    if not text:
        return text
    
    # First, escape HTML entities to prevent XSS
    sanitized = html.escape(text)
    
    # Remove potentially dangerous patterns (while preserving escaped content)
    # Remove any null bytes
    sanitized = sanitized.replace('\x00', '')
    
    # Remove excessive whitespace but preserve single spaces
    sanitized = re.sub(r'\s+', ' ', sanitized)
    
    # Strip leading/trailing whitespace
    sanitized = sanitized.strip()
    
    return sanitized

def validation(name: str):
    """
    Validate and sanitize user input for names.
    
    Args:
        name (str): Raw name input from user
        
    Returns:
        tuple: (is_valid: bool, result: str) where result is either sanitized name or error message
    """
    # Handle None input
    if name is None:
        return False, "Name cannot be empty."
    
    # First sanitize the input to prevent XSS
    sanitized_name = sanitize_input(name)
    
    if sanitized_name == "":
        return False, "Name cannot be empty."
    
    if len(sanitized_name) > MAX_NAME_LENGTH:
        return False, f"Max length is {MAX_NAME_LENGTH} characters."
    
    # Log if sanitization changed the input (for security monitoring)
    if name != sanitized_name:
        logger.warning(f"Input sanitization applied: '{name}' -> '{sanitized_name}'")
    
    return True, sanitized_name

@app.route("/api/names", methods=["POST"])
def add_name():
    logger.info("POST /api/names - Request received")
    
    data = request.get_json(silent=True)
    if not data:
        logger.warning("POST /api/names - Invalid JSON body received")
        return jsonify({"error": "Invalid JSON body."}), 400

    raw_name = data.get("name")
    logger.debug(f"POST /api/names - Processing name: {raw_name}")
    
    status, name = validation(raw_name)
    if not status:
        logger.warning(f"POST /api/names - Validation failed: {name}")
        return jsonify({"error": name}), 400

    try:
        with engine.connect() as conn:
            insert = table.insert().values(name=name)
            result = conn.execute(insert)
            conn.commit() 
            if result.inserted_primary_key:
                new_id = result.inserted_primary_key[0]
            else:
                new_id = None
        
        logger.info(f"POST /api/names - Successfully added name '{name}' with ID {new_id}")
        return jsonify({"id": new_id, "name": name}), 201
    
    except Exception as e:
        logger.error(f"POST /api/names - Database error: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

@app.route("/api/names", methods=["GET"])
def list_names():
    logger.info("GET /api/names - Request received")
    
    try:
        with engine.connect() as conn:
            stmt = select(
                table.c.id,
                table.c.name,
                table.c.created_at
            ).order_by(table.c.id.asc())
            rows = conn.execute(stmt).fetchall()

        results = []
        for r in rows:
            results.append({
                "id": r.id,
                "name": r.name,
                "created_at": r.created_at.isoformat() if r.created_at else None
            })

        logger.info(f"GET /api/names - Successfully retrieved {len(results)} names")
        return jsonify({"names": results}), 200
    
    except Exception as e:
        logger.error(f"GET /api/names - Database error: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

@app.route("/api/names/<int:name_id>", methods=["DELETE"])
def delete_name(name_id):
    logger.info(f"DELETE /api/names/{name_id} - Request received")
    
    try:
        with engine.connect() as conn:
            stmt = table.delete().where(table.c.id == name_id)
            result = conn.execute(stmt)
            conn.commit()
            if result.rowcount == 0:
                logger.warning(f"DELETE /api/names/{name_id} - Name not found")
                return jsonify({"error": "Name not found"}), 404
        
        logger.info(f"DELETE /api/names/{name_id} - Successfully deleted name")
        return jsonify({"deleted": name_id}), 200
    
    except Exception as e:
        logger.error(f"DELETE /api/names/{name_id} - Database error: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

@app.route("/api/health", methods=["GET"])
@app.route("/healthz", methods=["GET"])
def health_check():
    """Basic health check endpoint."""
    logger.info("Health check requested")
    return jsonify({"status": "ok"}), 200

@app.route("/api/health/db", methods=["GET"])
def health_check_db():
    """Database health check endpoint that verifies database connectivity."""
    logger.info("GET /api/health/db - Database health check requested")
    
    try:
        # Attempt a simple database query to verify connectivity
        with engine.connect() as conn:
            # Execute a simple query that doesn't require any tables
            result = conn.execute(select(func.now()))
            db_time = result.scalar()
        
        response = {
            "status": "healthy",
            "service": "Names Manager API - Database",
            "database": "connected",
            "db_time": str(db_time),
            "connection_url": DATABASE_URL.split('@')[1] if '@' in DATABASE_URL else "configured"  # Hide credentials
        }
        
        logger.info("GET /api/health/db - Database connection successful")
        return jsonify(response), 200
        
    except Exception as e:
        response = {
            "status": "unhealthy",
            "service": "Names Manager API - Database", 
            "database": "disconnected",
            "error": "Database connection failed",
            "details": str(e)
        }
        
        logger.error(f"GET /api/health/db - Database connection failed: {str(e)}")
        return jsonify(response), 503

if __name__ == "__main__":
    logger.info(f"Names Manager API starting up on host={SERVER_HOST}, port={SERVER_PORT}")
    app.run(host=SERVER_HOST, port=SERVER_PORT)
