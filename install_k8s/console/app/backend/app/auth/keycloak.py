from keycloak import KeycloakOpenID
from flask import current_app

def get_keycloak_openid():
    return KeycloakOpenID(
        server_url=current_app.config["KEYCLOAK_SERVER_URL"],
        client_id=current_app.config["KEYCLOAK_CLIENT_ID"],
        realm_name=current_app.config["KEYCLOAK_REALM"],
        client_secret_key=current_app.config["KEYCLOAK_CLIENT_SECRET"]
    )