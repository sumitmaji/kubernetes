import os

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY', 'dev_secret')
    KEYCLOAK_SERVER_URL = os.environ.get('KEYCLOAK_SERVER_URL')
    KEYCLOAK_REALM = os.environ.get('KEYCLOAK_REALM')
    KEYCLOAK_CLIENT_ID = os.environ.get('KEYCLOAK_CLIENT_ID')
    KEYCLOAK_PUBLIC_KEY = os.environ.get('KEYCLOAK_PUBLIC_KEY')  # PEM or base64 format
    OAUTH_ISSUER = os.environ.get('OAUTH_ISSUER', 'https://keycloak.gokcloud.com/realms/GokDevelopers')
    OAUTH_CLIENT_ID = os.environ.get('OAUTH_CLIENT_ID', 'gok-developers-client')