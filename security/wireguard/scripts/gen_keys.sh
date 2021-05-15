#!/bin/bash
set -e

eval "$(jq -r '@sh "IP_ADDRESS=\(.ip_address) PRIVATE_KEY=\(.private_key)"')"
# Run or script will fail
private_key=$(ssh root@$IP_ADDRESS -i $PRIVATE_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "wg genkey || true")
public_key=$(ssh root@$IP_ADDRESS -i $PRIVATE_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "echo $private_key | wg pubkey || true")

jq -n --arg private_key "$private_key" \
  --arg public_key "$public_key" \
  '{"private_key":$private_key,"public_key":$public_key}'
