from flask_restx import Namespace, Resource
from flask import g

user_ns = Namespace("users", description="User operations")

# Dummy data for demonstration
USERS = [
    {'id': 1, 'username': 'Alice', 'email': 'alice@example.com'},
    {'id': 2, 'username': 'Bob', 'email': 'bob@example.com'}
]

@user_ns.route("/userinfo")
class UserMeResource(Resource):
    def get(self):
        return g.user_schema

@user_ns.route("/idtoken")
class UserIdTokenResource(Resource):
    def get(self):
        # Assuming the id token is stored in g.user_schema['id_token']
        id_token = g.user_schema.get('token') if hasattr(g, 'user_schema') else None
        if not id_token:
            return {"message": "ID token not found"}, 404
        return {"id_token": id_token}        


@user_ns.route("/<int:user_id>")
class UserResource(Resource):
    def get(self, user_id):
        user = next((u for u in USERS if u['id'] == user_id), None)
        if not user:
            return {"message": "User not found"}, 404
        return user