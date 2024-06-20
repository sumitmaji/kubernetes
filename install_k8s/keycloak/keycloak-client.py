#!/usr/bin/python3
from os import environ as env
from dotenv import load_dotenv, find_dotenv
from os.path import expanduser
import logging
import os
import getpass
import requests
import json
import sys
from requests.packages.urllib3.exceptions import InsecureRequestWarning

command = sys.argv[1]

DEBUG_MODE = False
LOG_LEVEL = logging.INFO
LOG_FORMATTER = logging.Formatter("[%(asctime)s] [%(levelname)-8s] [LINE:%(lineno)4d] %(message)-2s")
logger = logging.getLogger("default")

MOUNT_PATH = os.environ['MOUNT_PATH']
os.system(f"envsubst < {MOUNT_PATH}/kubernetes/install_k8s/keycloak/config > {MOUNT_PATH}/kubernetes/install_k8s/keycloak/.env")

ENV_FILE = find_dotenv()
if ENV_FILE:
  load_dotenv(ENV_FILE)

HOME = expanduser("~")
KEYCLOAK_ROOT = env.get('KEYCLOAK_ROOT')
REALM = env.get('REALM')
KEYCLOAK_CLIENT_ID = env.get('KEYCLOAK_CLIENT_ID')
LOG_FILE_PATH = HOME + '/.keycloak'
CALLBACK_URL=env.get('CALLBACK_URL')

def get_console_handler():
  console_handler = logging.StreamHandler(sys.stdout)
  console_handler.setFormatter(LOG_FORMATTER)
  return console_handler;


def get_file_handler(log_file_name):
  if not os.path.exists(LOG_FILE_PATH):
    os.mkdir(LOG_FILE_PATH)
  file_handler = logging.FileHandler(LOG_FILE_PATH + os.path.sep + log_file_name)
  return file_handler


def get_logger(log_file_name):
  global logger
  logger = logging.getLogger(log_file_name)
  logger.setLevel(LOG_LEVEL)
  logger.addHandler(get_console_handler())
  logger.addHandler(get_file_handler(log_file_name))
  logger.propagate = False
  return logger


logger = get_logger('output.log')


def auth():
  sys.stderr.write("Login: ")
  login = input()
  password = getpass.getpass()
  requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

  r = requests.post(
    f"https://{KEYCLOAK_ROOT}/realms/master/protocol/openid-connect/token",
    data={
      "client_id": "admin-cli",
      "username": login,
      "password": password,
      "grant_type": "password"
    },
    verify=False
  )

  resp = json.loads(r.text)

  if not os.path.exists(HOME + '/.keycloak'):
    os.mkdir(HOME + '/.keycloak')

  if 'error' in resp:

    print("There was an auth0 error: " + resp['error'] + ": " + resp['error_description'])

  else:

    access_token = resp['access_token']
    print(f"Expires in {resp['expires_in']}s")
    with open(HOME + '/.keycloak/access_token', 'w') as f:
      f.write(access_token)


def authHeader():
  with open(HOME + '/.keycloak/access_token', 'r') as content_file: access_token = content_file.read()
  auth_headers = {
    "Authorization": f"Bearer {access_token}",
  }
  return auth_headers


# Get object id type (clients, client-scopes)
def getId(name, type, key):
  resp = requests.get(
    f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/{type}",
    headers=authHeader()
  )
  resp.raise_for_status()
  id = [dic for dic in resp.json() if dic[key] == name][0]['id']
  return id


def tokens():
  sys.stderr.write("Login: ")
  login = input()
  password = getpass.getpass()
  secret = getpass.getpass("Client Secret: ")
  resp = requests.post(
    f"https://{KEYCLOAK_ROOT}/realms/{REALM}/protocol/openid-connect/token",
    data={
      "client_id": env.get("KEYCLOAK_CLIENT_ID"),
      "client_secret": secret,
      "username": login,
      "password": password,
      "grant_type": "password",
    }
  )
  resp.raise_for_status()
  logger.info(resp.json()["access_token"])


# Create scope
def scope():
  logger.debug("Creating scope")
  group_settings = {
    "protocol": "openid-connect",
    "attributes": {
      "display.on.consent.screen": "true",
      "include.in.token.scope": "true",
      "gui.order": "1"
    },
    "name": "groups",
    "description": "User Groups",
    "type": "default",
  }

  resp = requests.post(
    f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/client-scopes",
    json=group_settings,
    headers=authHeader(),
  )
  resp.raise_for_status()
  logger.debug("Scope created")

  # Make scope type default
  id = getId('groups', 'client-scopes', 'name')
  logger.debug("Id fetched")
  resp = requests.put(
    f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/default-default-client-scopes/{id}",
    headers=authHeader()
  )
  resp.raise_for_status()
  logger.debug("Scope type is made default")

  # Add group-mapper to the scope
  model_settings = {"protocol": "openid-connect", "protocolMapper": "oidc-group-membership-mapper",
                    "name": "User Groups",
                    "config": {"claim.name": "groups", "full.path": "false", "id.token.claim": "true",
                               "access.token.claim": "true", "lightweight.claim": "false",
                               "userinfo.token.claim": "true", "introspection.token.claim": "true"}}
  resp = requests.post(
    f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/client-scopes/{id}/protocol-mappers/models",
    json=model_settings,
    headers=authHeader()
  )
  resp.raise_for_status()
  logger.debug("Added group mapper to scope")

  # Add scope to client as default scope
  clientId = getId(KEYCLOAK_CLIENT_ID, 'clients', 'clientId')
  resp = requests.put(
    f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/clients/{clientId}/default-client-scopes/{id}",
    headers=authHeader()
  )
  resp.raise_for_status()
  logger.debug("Added the scope to client")


def list():
  resp = requests.get(
    f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/client-scopes",
    headers=authHeader()
  ).json()
  print(resp)


# Create client
def client():
  # Split the string based on comma
  parts = CALLBACK_URL.split(',')

  client_settings = {"protocol": "openid-connect", "clientId": env.get('KEYCLOAK_CLIENT_ID'), "name": "Automation Client",
                       "description": "Client for Automation",
                       # Public: no client secret. Non-public: "confidential" client with secret.
                       "publicClient": False,
                       "authorizationServicesEnabled": False,
                       # Service accounts: Client Credentials Grant
                       "serviceAccountsEnabled": True,
                       "implicitFlowEnabled": True,
                       # Direct Access: Resource Owner Password Credentials Grant
                       "directAccessGrantsEnabled": True,
                       # Authorization Code Flow
                       "standardFlowEnabled": True,
                       "frontchannelLogout": True, "attributes": {"saml_idp_initiated_sso_url_name": "",
                                                                  # Device authorization grant
                                                                  "oauth2.device.authorization.grant.enabled": True,
                                                                  "oidc.ciba.grant.enabled": True},
                       "alwaysDisplayInConsole": True, "rootUrl": "", "baseUrl": "",
                       "redirectUris": parts}

  resp = requests.post(
    f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/clients",
    json=client_settings,
    headers=authHeader(),
  )
  resp.raise_for_status()
  location = resp.headers["Location"]
  logger.debug(location)

  resp = requests.get(
    location,
    headers=authHeader(),
  ).json()

  logger.debug(resp)

# Create group
def group():
  groups = ["administrators", "developers"]
  for group in groups:

    group_settings = {
      "name": group
    }
    resp = requests.post(
      f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/groups",
      json=group_settings,
      headers=authHeader(),
    )
    resp.raise_for_status()


# Create user and assign admin and dev group
def user():
  password = getpass.getpass('Password for Sample User: ')
  user_settings = {
    "username": env.get('USER_NAME'),
    "enabled": True,
    "groups": ["administrators", "developers"],
    "credentials": [{
      "type": "password",
      "value": password,
      "temporary": False,
    }]
  }

  resp = requests.post(
    f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/users",
    json=user_settings,
    headers=authHeader(),
  )
  resp.raise_for_status()

  location = resp.headers["Location"]
  logger.debug(location)

  resp = requests.get(
    location,
    headers=authHeader(),
  ).json()

  id = resp['id']
  logger.debug(id)

  # Update user details
  update_settings = {
    "firstName": "Sumit",
    "email": "skmaji1@outlook.com",
    "lastName": "Maji",
    "emailVerified": True
  }
  resp = requests.put(
    f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/users/{id}",
    json=update_settings,
    headers=authHeader(),
  )
  resp.raise_for_status()


# Create realm
def realm():
  resp = requests.post(
    f"https://{KEYCLOAK_ROOT}/admin/realms",
    headers=authHeader(),
    json={
      "realm": REALM,
      "enabled": True
    }
  )
  resp.raise_for_status()
  resp = requests.get(
    f"https://{KEYCLOAK_ROOT}/admin/realms",
    headers=authHeader(),
  )
  [print(r["realm"]) for r in resp.json()]


def main():
  try:
    if command == 'token':
      tokens()
    else:
      resp = requests.get(
        f"https://{KEYCLOAK_ROOT}/admin/realms",
        headers=authHeader(),
      )
      resp.raise_for_status()
      # [print(r["realm"]) for r in resp.json()]
      if command == 'realm':
        realm()
      elif command == 'client':
        client()
      elif command == 'scope':
        scope()
      elif command == 'group':
        group()
      elif command == 'user':
        user()
      elif command == 'list':
        list()
  except OSError as e:
    auth()


if __name__ == '__main__':
  # main()
  auth()
  logger.info("Creating realm")
  realm()
  logger.info("Creating client")
  client()
  logger.info("Creating scope")
  scope()
  logger.info("Creating group")
  group()
  logger.info("Creating user %s", env.get('USER_NAME'))
  user()
  logger.info("Validating user, put the toke in jwk.io to validate")
  tokens()
