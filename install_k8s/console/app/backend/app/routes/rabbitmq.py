from .service_routes import create_service_blueprint

rabbitmq_commands = {
    "logs": ["kubectl logs -n rabbitmq -l app.kubernetes.io/name=rabbitmq"],
    "pods": ["kubectl get pods -n rabbitmq"]
}

rabbitmq_bp = create_service_blueprint("rabbitmq", rabbitmq_commands)