from flask import Flask, send_from_directory, jsonify, request
import os
import jwt

app = Flask(
    __name__,
    static_folder="static",  # This is where your React build is copied
    static_url_path=""       # Serve static files at root
)

def get_user_info_from_token(token):
    payload = jwt.decode(token, options={"verify_signature": False})
    return {
        "userid": payload.get("sub"),
        "username": payload.get("preferred_username"),
        "email": payload.get("email"),
        "groups": payload.get("groups", [])
    }


@app.route("/api/v1/userinfo")
def userinfo():
    token = (
        request.headers.get("X-Auth-Request-Access-Token")
        or (
            request.headers.get("Authorization").split(" ", 1)[1]
            if request.headers.get("Authorization", "").startswith("Bearer ")
            else None
        )
    )
    # Use dummy token in debug mode if no token is provided
    if not token and app.debug:
        # Example dummy JWT payload (base64 encoded header.payload.signature)
        # You can adjust the payload as needed
        dummy_payload = {
            "sub": "1234567890",
            "preferred_username": "devuser",
            "email": "devuser@example.com",
            "groups": ["dev"]
        }
        # Encode dummy payload without signature for local dev
        token = jwt.encode(dummy_payload, key="", algorithm="none")

    if not token:
        return "Unauthorized", 401

    userinfo = get_user_info_from_token(token)

    username = userinfo["username"]
    email = userinfo["email"]

    if not username or not email:
        return "Unauthorized", 401

    user = {
        "username": username,
        "email": email
    }
    return jsonify(user)

@app.route("/")
def index():
    # Serve the React index.html
    return send_from_directory(app.static_folder, "index.html")

# Optional: API endpoint example
@app.route("/api/hello")
def hello():
    return jsonify({"message": "Hello from Flask backend!"})

# Catch-all route to serve React for client-side routing
@app.errorhandler(404)
def not_found(e):
    return send_from_directory(app.static_folder, "index.html")

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=8080)