import os
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

def validation(name: str):
    name = name.strip()
    if name == "":
        return False, "Name cannot be empty."
    if len(name) > 50:
        return False, "Max length is 50 characters."
    return True, name

@app.route("/api/names", methods=["POST"])
def add_name():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Invalid JSON body."}), 400

    raw_name = data.get("name")
    status, name = validation(raw_name)
    if not status:
        return jsonify({"error": name}), 400

    with engine.connect() as conn:
        insert = table.insert().values(name=name)
        result = conn.execute(insert)
        conn.commit() 
        if result.inserted_primary_key:
            new_id = result.inserted_primary_key[0]
        else:
            new_id = None

    return jsonify({"id": new_id, "name": name}), 201

@app.route("/api/names", methods=["GET"])
def list_names():
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

    return jsonify(results)

@app.route("/api/names/<int:name_id>", methods=["DELETE"])
def delete_name(name_id):
    with engine.connect() as conn:
        stmt = table.delete().where(table.c.id == name_id)
        result = conn.execute(stmt)
        conn.commit()
        if result.rowcount == 0:
            return jsonify({"error": "Name not found"}), 404
        
    return jsonify({"deleted": name_id}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
