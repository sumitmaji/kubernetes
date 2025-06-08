from .service_routes import create_service_blueprint

vault_commands = {
    "status": ["vault status"],
    "pods": ["kubectl get pods -n vault"]
}

vault_bp = create_service_blueprint("vault", vault_commands)