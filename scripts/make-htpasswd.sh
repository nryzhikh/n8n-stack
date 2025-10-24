#!/bin/bash
echo "Enter username:"
read USERNAME
echo "Enter password:"
read -s PASSWORD
echo
HASH=$(docker run --rm caddy caddy hash-password --plaintext "$PASSWORD")
mkdir -p ./caddy_config
echo "$USERNAME:$HASH" > ./caddy_config/.htpasswd
echo ".htpasswd file updated successfully!"
cat ./caddy_config/.htpasswd