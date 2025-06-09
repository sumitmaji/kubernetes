from flask import request, jsonify, g, current_app, send_from_directory
from functools import wraps
from app.config import Config
from app.schemas.user_schema import UserSchema
import os
import json
from jose import jwt, exceptions as jose_exceptions
import requests
import traceback

# Mock permissions map (should be externalized)
PERMISSIONS = {
    'administrators': ['GET', 'POST', 'PUT', 'DELETE'],
    'developers': ['GET']
}


def get_jwks():
    try:
        # Disable SSL verification in debug mode
        debug_mode = os.environ.get("FLASK_DEBUG", "0") == "1" or os.environ.get("FLASK_ENV") == "development"
        verify_ssl = not debug_mode

        oidc_conf = requests.get(f"{Config.OAUTH_ISSUER}/.well-known/openid-configuration", verify=verify_ssl).json()
        jwks_uri = oidc_conf["jwks_uri"]
        return requests.get(jwks_uri, verify=verify_ssl).json()
    except Exception as e:
        print(f"Error fetching JWKS: {e}")
        traceback.print_exc()
        return {"keys": []}

JWKS = get_jwks()

def verify_id_token(token):
    try:
        unverified_header = jwt.get_unverified_header(token)
        try:
            key = next(k for k in JWKS["keys"] if k["kid"] == unverified_header.get("kid"))
        except StopIteration:
            print("No matching 'kid' found in JWKS for token header.")
            traceback.print_exc()
            return None
        try:
            payload = jwt.decode(
                token,
                key,
                algorithms=["RS256"],
                audience=Config.OAUTH_CLIENT_ID,
                issuer=Config.OAUTH_ISSUER,
            )
            return payload
        except jwt.JWTError as e:
            print(f"JWT Error: {e}")
            if "at_hash" in str(e):
                # Ignore at_hash error if you don't have access_token
                payload = jwt.get_unverified_claims(token)
                return payload
            else:
                raise
    except Exception as e:
        print(f"Error verifying ID token: {e}")
        traceback.print_exc()
        return None

def verify_token(token):
    try:
        payload = verify_id_token(token)
        return payload
    except jose_exceptions.JWTError as e:
        traceback.print_exc()
        return None
    except Exception as e:
        print(f"Unexpected error during token verification: {e}")
        traceback.print_exc()
        return None


def get_dev_token():
    """Generate a dev token from demo_user.json if in debug mode and no token is provided."""
    demo_user_path = os.path.join(os.path.dirname(__file__), "../data/demo_user.json")
    if os.path.exists(demo_user_path):
        with open(demo_user_path) as f:
            payload = json.load(f)
        return jwt.encode(payload, "dev_secret", algorithm="HS256")
    return None

def auth_middleware():
    if request.path.startswith('/api/'):
        auth_header = request.headers.get('Authorization', '')
        token = None

        if auth_header.startswith('Bearer '):
            token = auth_header.split()[1]

        if not token:
            return jsonify({'message': 'Unauthorized'}), 401

        payload = verify_token(token)

        if not payload:
            return jsonify({'message': 'Invalid or expired token'}), 401

        # Save user info in Flask global context
        g.user = payload
        g.groups = payload.get('groups', [])

        # Serialize user info for this request
        user_data = {
            "sub": payload.get("sub"),
            "username": payload.get("preferred_username"),
            "email": payload.get("email"),
            "name": payload.get("name"),
            "groups": payload.get("groups", []),
            "roles": payload.get("roles", []),
            "token": token,
        }
        g.user_schema = UserSchema().dump(user_data)

        # Check authorization
        method = request.method
        if not any(method in PERMISSIONS.get(group, []) for group in g.groups):
            return jsonify({'message': 'Forbidden: insufficient permissions'}), 403

def keycloak_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        print(f"Keycloak Auth header: {auth_header}")
        token = None

        if auth_header.startswith('Bearer '):
            token = auth_header.split()[1]

        if not token:
            return jsonify({'message': 'Unauthorized'}), 401

        payload = verify_token(token)

        if not payload:
            return jsonify({'message': 'Invalid or expired token'}), 401

        g.user = payload
        g.groups = payload.get('groups', [])

        user_data = {
            "sub": payload.get("sub"),
            "username": payload.get("preferred_username"),
            "email": payload.get("email"),
            "name": payload.get("name"),
            "groups": payload.get("groups", []),
            "roles": payload.get("roles", []),
        }
        g.user_schema = UserSchema().dump(user_data)

        method = request.method
        if not any(method in PERMISSIONS.get(group, []) for group in g.groups):
            return jsonify({'message': 'Forbidden: insufficient permissions'}), 403

        return f(*args, **kwargs)
    return decorated

def register_error_handlers(app):
    @app.errorhandler(401)
    def unauthorized(e):
        return jsonify({"error": "Unauthorized"}), 401

    @app.errorhandler(403)
    def forbidden(e):
        return jsonify({"error": "Forbidden"}), 403

    @app.errorhandler(404)
    def not_found(e):
        # Serve React index.html for unknown routes (SPA support)
        if current_app.debug:
            return "404 Not Found", 404
        return send_from_directory(app.static_folder, "index.html")

    @app.errorhandler(500)
    def internal_error(e):
        return jsonify({"error": "Internal Server Error"}), 500