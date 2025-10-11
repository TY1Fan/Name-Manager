import os
import logging
from flask import Flask, request, jsonify
from sqlalchemy import create_engine, Table, Column, Integer, Text, TIMESTAMP, MetaData, select, func

DB_URL = os.environ.get(
    "DB_URL",
    "postgresql+psycopg2://names_user:names_pass@db:5432/namesdb"
)

engine = create_engine(DB_URL, echo=False, future=True)
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
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

logger = logging.getLogger(__name__)

def validation(name: str):
    name = name.strip()
    if name == "":
        return False, "Name cannot be empty."
    if len(name) > 50:
        return False, "Max length is 50 characters."
    return True, name

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
        return jsonify(results)
    
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

if __name__ == "__main__":
    logger.info("Names Manager API starting up on host=0.0.0.0, port=8000")
    app.run(host="0.0.0.0", port=8000)
