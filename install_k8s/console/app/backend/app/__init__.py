from flask import Flask
from .config import Config
from .auth.middleware import auth_middleware, register_error_handlers
from .routes.user import user_ns
from flask_restx import Api

def create_app():
    app = Flask(
        __name__,
        static_folder="static",      # Path to your React build/static files
        static_url_path=""           # Serve static files at root
    )
    app.config.from_object(Config)

    # Register Middleware
    app.before_request(auth_middleware)

    # Setup Flask-RESTX API
    api = Api(app, doc="/docs", title="User API", version="1.0")
    api.add_namespace(user_ns, path="/api/v1/users")

    # Register error handlers
    register_error_handlers(app)

    # Serve React index.html at root
    from flask import send_from_directory

    @app.route("/")
    def index():
        return send_from_directory(app.static_folder, "index.html")

    return app