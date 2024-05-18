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
LOG_LEVEL = logging.DEBUG
LOG_FORMATTER = logging.Formatter("[%(asctime)s] [%(levelname)-8s] [LINE:%(lineno)4d] %(message)-2s")
logger = logging.getLogger("default")

ENV_FILE = find_dotenv()
if ENV_FILE:
  load_dotenv(ENV_FILE)

HOME = expanduser("~")
KEYCLOAK_ROOT = env.get('KEYCLOAK_ROOT')
REALM = env.get('REALM')
KEYCLOAK_CLIENT_ID = env.get('KEYCLOAK_CLIENT_ID')
LOG_FILE_PATH=HOME + '/.keycloak'

def get_console_handler():
  console_handler = logging.StreamHandler(sys.stdout)
  console_handler.setFormatter(LOG_FORMATTER)
  return console_handler;

def get_file_handler(log_file_name):
  if not os.path.exists(LOG_FILE_PATH):
    os.mkdirs(LOG_FILE_PATH)
  file_handler = logging.FileHandler(LOG_FILE_PATH + os.path.sep + log_file_name)
  return file_handler

def get_logger(lgo_file_name):
  global logger
  logger = logging.getLogger(lgo_file_name)
  logger.setLevel(LOG_LEVEL)
  logger.addHandler(get_console_handler())
  logger.addHandler(get_file_handler())
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
  resp = requests.post(
    f"https://{KEYCLOAK_ROOT}/realms/{REALM}/protocol/openid-connect/token",
    data={
      "client_id": env.get("KEYCLOAK_CLIENT_ID"),
      "username": login,
      "password": password,
      "grant_type": "password",
    }
  )
  resp.raise_for_status()
  print(resp.json()["access_token"])

# Create scope
def scope():
  logger.info("Creating scope")
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
  logger.info("Scope created")

  # Make scope type default
  id = getId('groups', 'client-scopes', 'name')
  logger.info("Id fetched")
  resp = requests.put(
    f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/default-default-client-scopes/{id}",
    headers=authHeader()
  )
  resp.raise_for_status()
  logger.info("Scope type is made default")

  # Add group-mapper to the scope
  model_settings = {"protocol": "openid-connect", "protocolMapper": "oidc-group-membership-mapper",
                    "name": "User Groups",
                    "config": {"claim.name": "group", "full.path": "true", "id.token.claim": "true",
                               "access.token.claim": "true", "lightweight.claim": "false",
                               "userinfo.token.claim": "true", "introspection.token.claim": "true"}}
  resp = requests.post(
    f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/client-scopes/{id}/protocol-mappers/models",
    json=model_settings,
    headers=authHeader()
  )
  resp.raise_for_status()
  logger.info("Added group mapper to scope")

  # Add scope to client as default scope
  clientId = getId(KEYCLOAK_CLIENT_ID, 'clients', 'clientId')
  resp = requests.put(
    f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/clients/{clientId}/default-client-scopes/{id}",
    headers=authHeader()
  )
  resp.raise_for_status()
  logger.info("Added the scope to client")

def list():
  resp = requests.get(
    f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/client-scopes",
    headers=authHeader()
  ).json()
  print(resp)


# Create client
def client():
  client_settings = {
    "protocol": "openid-connect",
    "clientId": env.get('KEYCLOAK_CLIENT_ID'),
    "enabled": True,
    # Public: no client secret. Non-public: "confidential" client with secret.
    "publicClient": True,
    # Authorization Code Flow
    "standardFlowEnabled": True,
    # Service accounts: Client Credentials Grant
    "serviceAccountsEnabled": False,
    # Direct Access: Resource Owner Password Credentials Grant
    "directAccessGrantsEnabled": True,
    "attributes": {
      # Device authorization grant
      "oauth2.device.authorization.grant.enabled": True,
    }
  }

  resp = requests.post(
    f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/clients",
    json=client_settings,
    headers=authHeader(),
  )
  resp.raise_for_status()
  location = resp.headers["Location"]
  print(location)

  resp = requests.get(
    location,
    headers=authHeader(),
  ).json()

  print(resp)


def group():
  group_settings = {
    "name": "admins"
  }

  resp = requests.post(
    f"https://{KEYCLOAK_ROOT}/admin/realms/{REALM}/groups",
    json=group_settings,
    headers=authHeader(),
  )
  resp.raise_for_status()


def user():
  user_settings = {
    "username": env.get('USER_NAME'),
    "enabled": True,
    "groups": ["admins"],
    "credentials": [{
      "type": "password",
      "value": env.get('PASSWORD'),
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
  print(location)

  resp = requests.get(
    location,
    headers=authHeader(),
  ).json()

  id = resp['id']
  print(id)

  # Add to admins groups
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
    elif command == 'user':
      user()
    elif command == 'group':
      group()
    elif command == 'scope':
      scope()
    elif command == 'list':
      list()
    elif command == 'token':
      tokens()
  except OSError as e:
    auth()


if __name__ == '__main__':
  main()
