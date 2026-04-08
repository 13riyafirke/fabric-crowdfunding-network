#!/bin/bash
# ============================================================
# HYPERLEDGER FABRIC NETWORK GENERATOR SCRIPT
# ============================================================
# This script is a PARAMETERIZED template that the AI chatbot
# will customize based on user inputs. Users provide:
#   - Number of organizations
#   - Channel names
#   - Chaincode name, path, language
#   - Endorsement policy
#
# The chatbot fills in the variables at the top, generating
# a ready-to-run, error-free setup script.
# ============================================================

set -e  # Exit immediately on any error

# ============================================================
# USER-CONFIGURABLE PARAMETERS
# (Chatbot fills these in based on user requirements)
# ============================================================

# Base working directory (absolute path to fabric-samples/test-network)
BASE_DIR="/path/to/fabric-samples/test-network"

# Number of organizations (2, 3, or 4 supported by default test-network tooling)
NUM_ORGS=4

# Channel configuration
# PRIMARY_CHANNEL is created with network.sh up (always has Org1 + Org2)
PRIMARY_CHANNEL="mychannel"

# OPTIONAL: second channel (leave empty "" if you only need one channel)
SECONDARY_CHANNEL=""

# Chaincode configuration
CHAINCODE_NAME="mycc"
CHAINCODE_PATH="../my-chaincode"   # relative to test-network dir
CHAINCODE_LANG="go"               # go | node | java
CHAINCODE_VERSION="1.0"
CHAINCODE_SEQUENCE="1"

# Endorsement policy
# Examples:
#   AND('Org1MSP.peer','Org2MSP.peer','Org3MSP.peer','Org4MSP.peer')
#   OR('Org1MSP.peer','Org2MSP.peer')
#   OutOf(2,'Org1MSP.peer','Org2MSP.peer','Org3MSP.peer')
ENDORSEMENT_POLICY="AND('Org1MSP.peer','Org2MSP.peer','Org3MSP.peer','Org4MSP.peer')"

# State database: couchdb | leveldb
STATE_DB="couchdb"

# ============================================================
# INTERNAL VARIABLES (derived automatically)
# ============================================================

export PATH=${BASE_DIR}/../bin:$PATH
export FABRIC_CFG_PATH=${BASE_DIR}/../config/
export CORE_PEER_TLS_ENABLED=true

ORDERER_CA="${BASE_DIR}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem"
ORDERER_FLAGS="-o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile $ORDERER_CA"

ORG1_TLS="${BASE_DIR}/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem"
ORG2_TLS="${BASE_DIR}/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem"
ORG3_TLS="${BASE_DIR}/organizations/peerOrganizations/org3.example.com/tlsca/tlsca.org3.example.com-cert.pem"
ORG4_TLS="${BASE_DIR}/organizations/peerOrganizations/org4.example.com/tlsca/tlsca.org4.example.com-cert.pem"

# ============================================================
# HELPER FUNCTIONS
# ============================================================

print_section() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

check_prereqs() {
  print_section "CHECKING PREREQUISITES"
  command -v peer >/dev/null 2>&1  || { echo "ERROR: peer binary not found. Run: export PATH=\$PWD/../bin:\$PATH"; exit 1; }
  command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found. Install Docker."; exit 1; }
  command -v jq >/dev/null 2>&1     || { echo "ERROR: jq not found. Install: sudo apt install jq"; exit 1; }
  echo "✓ All prerequisites found"
  peer version | grep "Version:"
}

set_org1_env() {
  export CORE_PEER_LOCALMSPID=Org1MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=$ORG1_TLS
  export CORE_PEER_MSPCONFIGPATH=${BASE_DIR}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
  export CORE_PEER_ADDRESS=localhost:7051
}

set_org2_env() {
  export CORE_PEER_LOCALMSPID=Org2MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=$ORG2_TLS
  export CORE_PEER_MSPCONFIGPATH=${BASE_DIR}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
  export CORE_PEER_ADDRESS=localhost:9051
}

set_org3_env() {
  export CORE_PEER_LOCALMSPID=Org3MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=$ORG3_TLS
  export CORE_PEER_MSPCONFIGPATH=${BASE_DIR}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
  export CORE_PEER_ADDRESS=localhost:11051
}

set_org4_env() {
  export CORE_PEER_LOCALMSPID=Org4MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=$ORG4_TLS
  export CORE_PEER_MSPCONFIGPATH=${BASE_DIR}/organizations/peerOrganizations/org4.example.com/users/Admin@org4.example.com/msp
  export CORE_PEER_ADDRESS=localhost:12051
}

# Generic invoke — collects endorsements from all orgs required by policy
# Usage: invoke_on_channel <channel> <chaincode> <json_args>
invoke_on_channel() {
  local CHANNEL=$1
  local CC=$2
  local ARGS=$3

  # Build peer addresses based on NUM_ORGS
  local PEERS=""
  PEERS="--peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_TLS"
  PEERS="$PEERS --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_TLS"
  [ "$NUM_ORGS" -ge 3 ] && PEERS="$PEERS --peerAddresses localhost:11051 --tlsRootCertFiles $ORG3_TLS"
  [ "$NUM_ORGS" -ge 4 ] && PEERS="$PEERS --peerAddresses localhost:12051 --tlsRootCertFiles $ORG4_TLS"

  peer chaincode invoke $ORDERER_FLAGS -C "$CHANNEL" -n "$CC" $PEERS -c "$ARGS"
}

# Generic query — reads from local peer state (no orderer needed)
# Usage: query_on_channel <channel> <chaincode> <json_args>
query_on_channel() {
  local CHANNEL=$1
  local CC=$2
  local ARGS=$3
  peer chaincode query -C "$CHANNEL" -n "$CC" -c "$ARGS"
}

# ============================================================
# STEP 1 — TEAR DOWN OLD NETWORK
# ============================================================
cd "$BASE_DIR"

print_section "STEP 1: Tearing down old network"
./network.sh down 2>/dev/null || true
sleep 2
echo "✓ Old network removed"

# ============================================================
# STEP 2 — START BASE NETWORK (Org1 + Org2)
# ============================================================
print_section "STEP 2: Starting base network (Org1 + Org2)"
./network.sh up createChannel -c "$PRIMARY_CHANNEL" -ca -s "$STATE_DB"
sleep 3
echo "✓ Channel '$PRIMARY_CHANNEL' created — Org1 and Org2 joined"

# ============================================================
# STEP 3 — ADD ORG3 (if NUM_ORGS >= 3)
# ============================================================
if [ "$NUM_ORGS" -ge 3 ]; then
  print_section "STEP 3: Adding Org3"
  cd addOrg3
  ./addOrg3.sh up -ca -s "$STATE_DB" -c "$PRIMARY_CHANNEL"
  cd ..
  sleep 2
  echo "✓ Org3 added and joined '$PRIMARY_CHANNEL'"
fi

# ============================================================
# STEP 4 — ADD ORG4 (if NUM_ORGS >= 4)
# ============================================================
if [ "$NUM_ORGS" -ge 4 ]; then
  print_section "STEP 4: Adding Org4"
  cd addOrg4
  ./addOrg4.sh up -ca -s "$STATE_DB" -c "$PRIMARY_CHANNEL"
  cd ..
  sleep 2
  echo "✓ Org4 added and joined '$PRIMARY_CHANNEL'"
fi

# ============================================================
# STEP 5 — VERIFY ALL PEERS ARE RUNNING
# ============================================================
print_section "STEP 5: Verifying all peers are running"
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep "peer0\|orderer"
echo ""

# ============================================================
# STEP 6 — DEPLOY CHAINCODE
# ============================================================
print_section "STEP 6: Deploying chaincode '$CHAINCODE_NAME'"
./network.sh deployCC \
  -c "$PRIMARY_CHANNEL" \
  -ccn "$CHAINCODE_NAME" \
  -ccp "$CHAINCODE_PATH" \
  -ccl "$CHAINCODE_LANG" \
  -ccv "$CHAINCODE_VERSION" \
  -ccs "$CHAINCODE_SEQUENCE" \
  -ccep "$ENDORSEMENT_POLICY"
sleep 3
echo "✓ Chaincode '$CHAINCODE_NAME' deployed to '$PRIMARY_CHANNEL'"

# ============================================================
# STEP 7 — VERIFY CHAINCODE DEPLOYMENT
# ============================================================
print_section "STEP 7: Verifying chaincode deployment"
set_org1_env
peer lifecycle chaincode querycommitted -C "$PRIMARY_CHANNEL" -n "$CHAINCODE_NAME"
echo "✓ Chaincode verified"

# ============================================================
# STEP 8 — OPTIONAL SECONDARY CHANNEL SETUP
# ============================================================
if [ -n "$SECONDARY_CHANNEL" ]; then
  print_section "STEP 8: Setting up secondary channel '$SECONDARY_CHANNEL'"

  export FABRIC_CFG_PATH="$BASE_DIR/configtx"
  configtxgen \
    -profile ChannelUsingRaft \
    -outputBlock ./channel-artifacts/${SECONDARY_CHANNEL}.block \
    -channelID "$SECONDARY_CHANNEL"

  ORDERER_ADMIN_TLS_SIGN_CERT="${BASE_DIR}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt"
  ORDERER_ADMIN_TLS_PRIVATE_KEY="${BASE_DIR}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key"

  export FABRIC_CFG_PATH="${BASE_DIR}/../config/"
  osnadmin channel join \
    --channelID "$SECONDARY_CHANNEL" \
    --config-block ./channel-artifacts/${SECONDARY_CHANNEL}.block \
    -o localhost:7053 \
    --ca-file "$ORDERER_CA" \
    --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" \
    --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"

  echo "✓ Secondary channel '$SECONDARY_CHANNEL' created"
fi

# ============================================================
# SETUP COMPLETE
# ============================================================
echo ""
echo "============================================================"
echo "  NETWORK SETUP COMPLETE"
echo "============================================================"
echo "  Channel       : $PRIMARY_CHANNEL"
echo "  Chaincode     : $CHAINCODE_NAME"
echo "  Organizations : $NUM_ORGS"
echo "  State DB      : $STATE_DB"
echo "============================================================"
echo ""
echo "Quick test — invoke InitLedger:"
echo "  set_org1_env  (run the function above)"
echo "  peer chaincode invoke ... -c '{\"Args\":[\"InitLedger\"]}'"
echo ""
echo "To bring down the network:"
echo "  ./network.sh down"
