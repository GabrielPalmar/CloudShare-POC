#!/bin/bash

# Check for dependencies
for pkg in jq curl; do
    if ! command -v $pkg &> /dev/null; then
        sudo apt install $pkg -y &> /dev/null
    fi
done

# Check for OpenVPN3 installation
if ! command openvpn3 --help &> /dev/null; then
    # Install the OpenVPN repository key used by the OpenVPN packages
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://packages.openvpn.net/packages-repo.gpg | sudo tee /etc/apt/keyrings/openvpn.asc &> /dev/null

    # Add the OpenVPN repository
    echo "deb [signed-by=/etc/apt/keyrings/openvpn.asc] https://packages.openvpn.net/openvpn3/debian $(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/openvpn-packages.list &> /dev/null
    sudo apt update &> /dev/null

    # Install OpenVPN Connector setup tool
    sudo apt install python3-openvpn-connector-setup -y &> /dev/null
fi

# API Data
API_URL='https://gabrielpalmar.api.openvpn.com'
CLIENT_ID="${OPENVPN_CLIENT_ID:-}"
CLIENT_SECRET="${OPENVPN_CLIENT_SECRET:-}"

# Generate OAuth token:
API_TOKEN=$(curl -X POST "${API_URL}/api/v1/oauth/token?client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&grant_type=client_credentials" | jq -r '.access_token')

# Get UUID
UUID=$(sudo dmidecode -t system | grep Serial | awk -F: '{ print $2 }')

# Network Name
NET_NAME=$(echo $UUID | awk -F- '{ print $1 }')

# Create a new network
NET_PAYLOAD=$(cat <<EOF
{
  "name": "NETWORK $NET_NAME",
  "description": "$UUID",
  "internetAccess": "SPLIT_TUNNEL_ON",
  "egress": false,
  "connectors": [
    {
      "name": "Network A Connector",
      "description": "$UUID",
      "vpnRegionId": "us-mia"
    }
  ],
  "tunnelingProtocol": "OPENVPN"
}
EOF
)

NET_RES=$(curl -X POST "${API_URL}/api/v1/networks" \
-H 'accept: application/json' \
-H "authorization: Bearer ${API_TOKEN}" \
-H 'Content-Type: application/json' \
-d "$NET_PAYLOAD")

echo -e "Network Response: $NET_RES\n"

# Extract Connector ID
CONN_ID=$(echo $NET_RES | jq -r '.connectors[0].id')

# Obtain Token and install Connector
CONN_TOKEN=$(curl -X POST "${API_URL}/api/v1/networks/connectors/${CONN_ID}/profile/encrypt" \
-H 'accept: text/plain' \
-H "authorization: Bearer ${API_TOKEN}" \
-d '')

sudo openvpn-connector-setup --token "$CONN_TOKEN"
