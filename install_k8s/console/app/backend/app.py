from flask import Flask, send_from_directory, jsonify
import os

app = Flask(
    __name__,
    static_folder="static",  # This is where your React build is copied
    static_url_path=""       # Serve static files at root
)

@app.route("/api/v1/userinfo")
def userinfo():
    # Example static user info; replace with real user data as needed
    user = {
        "username": "johndoe",
        "email": "johndoe@example.com"
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