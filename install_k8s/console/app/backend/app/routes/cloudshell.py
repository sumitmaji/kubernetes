from .service_routes import create_service_blueprint

cloudshell_commands = {
    "status": ["cloudshell status"],
    "pods": ["kubectl get pods -n cloudshell"],
    "install": ["sleep 2 && gok install cloudshell"]
}

cloudshell_bp = create_service_blueprint("cloudshell", cloudshell_commands)