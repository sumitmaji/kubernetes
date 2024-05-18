#!/usr/bin/python3
#Installing python3
#apt-get install python3
#pip3 insall -r requirements-cli.txt

from os import environ as env
from dotenv import load_dotenv, find_dotenv
from jose import jwt
from six.moves.urllib.request import urlopen
from os.path import expanduser

import os
import getpass
import requests
import json
import sys
from requests.packages.urllib3.exceptions import InsecureRequestWarning

MOUNT_PATH = os.environ['MOUNT_PATH']
os.system(f"envsubst < {MOUNT_PATH}/kubernetes/install_k8s/kube-login/config > {MOUNT_PATH}/kubernetes/install_k8s/kube-login/.env")

ENV_FILE = find_dotenv()
if ENV_FILE:
    load_dotenv(ENV_FILE)

AUTH0_CLIENT_ID = env.get('AUTH0_CLIENT_ID')
AUTH0_DOMAIN = env.get('AUTH0_DOMAIN')
APP_HOST = env.get('APP_HOST')
HOME = expanduser("~")
OIDC_ISSUE_URL=env.get('OIDC_ISSUE_URL')
IDENTITY_PROVIDER=env.get('IDENTITY_PROVIDER')
JWKS_URL=env.get('JWKS_URL')

def auth():
  sys.stderr.write("Login: ")
  login = input()
  password = getpass.getpass()
  requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
  r = requests.get("https://"+APP_HOST+"/kubectl?username="+login+"&password="+password,verify=False)

  resp = json.loads(r.text)

  if 'error' in resp:

    print("There was an auth0 error: "+resp['error']+": "+resp['error_description'])

  else:

    id_token = resp['id_token']
    access_token = resp['access_token']

    jwks = urlopen(JWKS_URL)

    with open(HOME+'/.kube/jwks.json', 'w') as f: f.write (jwks.read().decode('utf-8'))
    with open(HOME+'/.kube/id_token', 'w') as f: f.write (id_token)
    if IDENTITY_PROVIDER == 'keycloak':
      with open(HOME+'/.kube/access_token', 'w') as f: f.write (access_token)

    print(id_token)

def main():
  try:
    with open(HOME+'/.kube/jwks.json', 'r') as content_file: jwks = content_file.read()
    with open(HOME+'/.kube/id_token', 'r') as content_file: id_token = content_file.read()
    if IDENTITY_PROVIDER == 'keycloak':
      with open(HOME+'/.kube/access_token', 'r') as content_file: access_token = content_file.read()

    if IDENTITY_PROVIDER == 'keycloak':
      payload = jwt.decode(id_token, jwks, algorithms=['RS256'],
                       audience=AUTH0_CLIENT_ID, issuer=OIDC_ISSUE_URL,access_token=access_token)
      print(id_token)
    else:
      payload = jwt.decode(id_token, jwks, algorithms=['RS256'],
                           audience=AUTH0_CLIENT_ID, issuer=OIDC_ISSUE_URL)
      print(id_token)

  except OSError as e:
    auth()
  except jwt.ExpiredSignatureError as e:
    auth()
  except jwt.JWTClaimsError as e:
    auth()
  except jwt.JWTError as e:
    auth()


if __name__ == '__main__':
  main()