from flask import Flask
from .config import Config
from .auth.middleware import auth_middleware, register_error_handlers
from .routes.user import user_ns
from flask_restx import Api
import os
from flask_socketio import SocketIO
from app.socketio_handlers import register_socketio_handlers

def create_app():
    debug_mode = os.environ.get("FLASK_DEBUG", "0") == "1" or os.environ.get("FLASK_ENV") == "development"
    print(f"Debug mode: {debug_mode}")
    if not debug_mode:
        static_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "static"))
        app = Flask(
            __name__,
            static_folder=static_dir,
            static_url_path=""
        )
    else:
        app = Flask(__name__)

    print("STATIC FOLDER:", app.static_folder)
    app.config.from_object(Config)

    socketio = SocketIO(app, cors_allowed_origins="*")
    app.extensions["socketio"] = socketio

    # Register Middleware
    app.before_request(auth_middleware)

    # Setup Flask-RESTX API
    api = Api(app, doc="/docs", title="User API", version="1.0")
    api.add_namespace(user_ns, path="/api/v1/users")

    # Register error handlers
    register_error_handlers(app)

    # Initialize SocketIO handlers
    register_socketio_handlers(app)

    from .routes.command import command_bp
    app.register_blueprint(command_bp, url_prefix="/api/v1/command")

    from .routes.rabbitmq import rabbitmq_bp
    app.register_blueprint(rabbitmq_bp, url_prefix="/api/v1/command/rabbitmq")

    # Serve React index.html at root only if not in debug mode
    if not debug_mode:
        from flask import send_from_directory

        @app.route("/")
        def index():
            return send_from_directory(app.static_folder, "index.html")
    else:
        @app.route("/")
        def index():
            return "Welcome to the User API! Please use /docs for API documentation."

    return app