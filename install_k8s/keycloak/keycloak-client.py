#!/usr/bin/python3
from os import environ as env
from dotenv import load_dotenv, find_dotenv
from os.path import expanduser

import os
import getpass
import requests
import json
import sys
from requests.packages.urllib3.exceptions import InsecureRequestWarning

ENV_FILE = find_dotenv()
if ENV_FILE:
  load_dotenv(ENV_FILE)

HOME = expanduser("~")
KEYCLOAK_ROOT = env.get('KEYCLOAK_ROOT')

def accessToken():
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

  if not os.path.exists(HOME+'/.keycloak'):
    os.mkdir(HOME+'/.keycloak')


  if 'error' in resp:

    print("There was an auth0 error: "+resp['error']+": "+resp['error_description'])

  else:

    access_token = resp['access_token']
    print(access_token)
    print(f"Expires in {resp['expires_in']}s")
    with open(HOME+'/.keycloak/access_token', 'w') as f: f.write (access_token)

def main():
  try:
    with open(HOME+'/.keycloak/access_token', 'r') as content_file: access_token = content_file.read()
    # Predefine authorization headers for later use.
    auth_headers = {
      "Authorization": f"Bearer {access_token}",
    }

    resp = requests.get(
      f"https://{KEYCLOAK_ROOT}/admin/realms",
      headers=auth_headers,
    )

    print(resp)
    resp.raise_for_status()
    [r["realm"] for r in resp.json()]

  except OSError as e:
    accessToken()

if __name__ == '__main__':
  main()