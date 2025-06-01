from flask import request, jsonify, g, current_app, send_from_directory
from functools import wraps
from app.config import Config
from app.schemas.user_schema import UserSchema
import os
import json
from jose import jwt
import requests

# Mock permissions map (should be externalized)
PERMISSIONS = {
    'administrators': ['GET', 'POST', 'PUT', 'DELETE'],
    'developers': ['GET']
}


def get_jwks():
    try:
        oidc_conf = requests.get(f"{Config.OAUTH_ISSUER}/.well-known/openid-configuration", verify=True).json()
        jwks_uri = oidc_conf["jwks_uri"]
        return requests.get(jwks_uri, verify=True).json()
    except Exception as e:
        return {"keys": []}

JWKS = get_jwks()

def verify_id_token(token):
    try:
        unverified_header = jwt.get_unverified_header(token)
        key = next(k for k in JWKS["keys"] if k["kid"] == unverified_header["kid"])
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
            if "at_hash" in str(e):
                # Ignore at_hash error if you don't have access_token
                payload = jwt.get_unverified_claims(token)
                return payload
            else:
                raise
    except Exception as e:
        return None

def verify_token(token):
    try:
        if current_app.debug:
            # Dev mode: use local secret and HS256
            payload = jwt.decode(token, "dev_secret", algorithms=['HS256'])
        else:
            payload = verify_id_token(token)
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
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
        elif current_app.debug:
            # In dev mode, inject demo token if not provided
            token = get_dev_token()
            if token:
                request.headers.environ['HTTP_AUTHORIZATION'] = f'Bearer {token}'

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
        token = None

        if auth_header.startswith('Bearer '):
            token = auth_header.split()[1]
        elif current_app.debug:
            token = get_dev_token()
            if token:
                request.headers.environ['HTTP_AUTHORIZATION'] = f'Bearer {token}'

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
        return send_from_directory(app.static_folder, "index.html")

    @app.errorhandler(500)
    def internal_error(e):
        return jsonify({"error": "Internal Server Error"}), 500