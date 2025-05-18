#!/bin/bash
set -eu

get_public_ip() {
  # Define a list of HTTP-based providers
  local PROVIDERS=(
    "http://ifconfig.me"
    "http://api.ipify.org"
    "http://ipecho.net/plain"
    "http://v4.ident.me"
  )
  # Iterate through the providers until an IP is found or the list is exhausted
  for provider in "${PROVIDERS[@]}"; do
    local IP
    IP=$(curl -s "$provider")
    # Check if IP contains a valid format (simple regex for an IPv4 address)
    if [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "$IP"
      return 0
    fi
  done
  return 1
}
if PUBLIC_IP=$(get_public_ip); then
  echo "fetched public IP is: $PUBLIC_IP"
else
  echo "Could not retrieve public IP."
  exit 8
fi
echo "NODE_PUBLIC_IP="$PUBLIC_IP > .env

#rm -rf config
file_path="values.env"
current_utc_timestamp=$(date -u +%s)
OS="$(uname -s)"
case "${OS}" in
    Linux*)
        echo "Running on Linux"
        sed -i "s/GENESIS_TIMESTAMP=[0-9]*/GENESIS_TIMESTAMP=$current_utc_timestamp/" $file_path
        ;;
    Darwin*)
        echo "Running on macOS"
        sed -i '' "s/GENESIS_TIMESTAMP=[0-9]*/GENESIS_TIMESTAMP=$current_utc_timestamp/" $file_path
        ;;
    *)
        echo "Unknown OS: ${OS}"
        exit 1
        ;;
esac

source values.env
echo "FEE_RECIPIENT="$WITHDRAWAL_ADDRESS >> .env
echo "CHAIN_ID="$CHAIN_ID >> .env

docker run --rm -it \
-v $PWD/config:/data \
-v $PWD/values.env:/config/values.env \
ethpandaops/ethereum-genesis-generator:electra-genesis cl

rm -rf vc

docker run -it --rm -v $PWD/vc:/vc ghcr.io/thaichain/eth2-val-tools keystores \
--insecure \
--prysm-pass password \
--out-loc /vc/data \
--source-mnemonic "$EL_AND_CL_MNEMONIC" \
--source-min 0 \
--source-max $NUMBER_OF_VALIDATORS

rm -rf vc/data/lodestar-secrets vc/data/nimbus-keys vc/data/prysm vc/data/teku-keys vc/data/teku-secrets
