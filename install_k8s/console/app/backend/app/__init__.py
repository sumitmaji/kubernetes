from flask import Flask
from .config import Config
from .auth.middleware import auth_middleware, register_error_handlers
from .routes.user import user_ns
from flask_restx import Api
import os

def create_app():
    static_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "static"))
    app = Flask(
        __name__,
        static_folder=static_dir,
        static_url_path=""
    )
    print("STATIC FOLDER:", app.static_folder)
    app.config.from_object(Config)

    # Register Middleware
    app.before_request(auth_middleware)

    # Setup Flask-RESTX API
    api = Api(app, doc="/docs", title="User API", version="1.0")
    api.add_namespace(user_ns, path="/api/v1/users")

    # Register error handlers
    register_error_handlers(app)

    from .routes.command import command_bp
    app.register_blueprint(command_bp, url_prefix="/api/v1/command")

    # Serve React index.html at root
    from flask import send_from_directory

    @app.route("/")
    def index():
        return send_from_directory(app.static_folder, "index.html")

    return app