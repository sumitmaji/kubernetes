#!/usr/bin/python3
from os import environ as env
from dotenv import load_dotenv, find_dotenv
from os.path import expanduser

import getpass
import requests
import json
import sys

ENV_FILE = find_dotenv()
if ENV_FILE:
  load_dotenv(ENV_FILE)

HOME = expanduser("~")
KEYCLOAK_ROOT = env.get('KEYCLOAK_ROOT')
keycloak_admin = "admin"
keycloak_admin_password = "admin"

def accessToken():
  resp = requests.post(
f"{KEYCLOAK_ROOT}/realms/master/protocol/openid-connect/token",
    data={
      "client_id": "admin-cli",
      "username": keycloak_admin,
      "password": keycloak_admin_password,
      "grant_type": "password"
    }
  )
  resp.raise_for_status()
  data = resp.json()
  access_token = data["access_token"]
  print(f"{access_token[:20]}...{access_token[-20:]}")
  print(f"Expires in {data['expires_in']}s")

  # Predefine authorization headers for later use.
  auth_headers = {
    "Authorization": f"Bearer {access_token}",
  }

