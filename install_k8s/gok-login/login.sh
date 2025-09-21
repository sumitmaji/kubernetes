#!/bin/bash
# Usage: ./login.sh <username> <password>

API_URL="https://gok-login.gokcloud.com/login"
USERNAME="$1"
PASSWORD="$2"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Usage: $0 <username> <password>"
  exit 1
fi


echo "API URL: $API_URL"
echo "Username: $USERNAME"
echo "Password: [hidden]"
echo "Request payload: {\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}"

if [ "$VERBOSE" = "1" ]; then
  echo "Curl verbose mode enabled."
  RESPONSE=$(curl -vk -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}")
else
  RESPONSE=$(curl -sk -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}")
fi

echo "Response: $RESPONSE"
