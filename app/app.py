from flask import Flask, jsonify, request
import os
import logging

# Configuration du logging sécurisé (pas de données sensibles)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Version de l'application
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
APP_ENV = os.getenv("APP_ENV", "production")

@app.route("/", methods=["GET"])
def home():
    logger.info("Requête reçue sur /")
    return jsonify({
        "message": "🚀 CI/CD Pipeline - Application opérationnelle",
        "version": APP_VERSION,
        "environment": APP_ENV,
        "status": "healthy"
    })

@app.route("/health", methods=["GET"])
def health():
    """Endpoint utilisé par Kubernetes pour les liveness/readiness probes"""
    return jsonify({"status": "ok"}), 200

@app.route("/ready", methods=["GET"])
def ready():
    """Readiness probe Kubernetes"""
    return jsonify({"status": "ready"}), 200

@app.route("/api/items", methods=["GET"])
def get_items():
    items = [
        {"id": 1, "name": "Item Alpha", "status": "actif"},
        {"id": 2, "name": "Item Beta", "status": "actif"},
        {"id": 3, "name": "Item Gamma", "status": "inactif"},
    ]
    return jsonify({"items": items, "total": len(items)})

@app.route("/api/items/<int:item_id>", methods=["GET"])
def get_item(item_id):
    if item_id not in [1, 2, 3]:
        return jsonify({"error": "Item non trouvé"}), 404
    return jsonify({"id": item_id, "name": f"Item {item_id}"})

if __name__ == "__main__":
    # Ne jamais exposer le debug en production
    debug_mode = APP_ENV == "development"
    app.run(host="0.0.0.0", port=5000, debug=debug_mode)
