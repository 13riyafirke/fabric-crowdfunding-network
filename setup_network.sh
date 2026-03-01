#!/bin/bash
# ================================================================
# COMPLETE 2-CHANNEL NETWORK SETUP
# Run this from: fabric-samples/test-network
#
# investment-channel     → Org1 + Org2 + Org3 + Org4
# 
# ================================================================

set -e  # stop on any error

cd /mnt/c/Users/riyaf/Downloads/Blockchain1/fabric-samples/test-network

# ── Fix PATH first ───────────────────────────────────────────────
export PATH=$PWD/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/

echo "================================================================"
echo "  2-CHANNEL CROWDFUNDING NETWORK SETUP"
echo "================================================================"
echo ""

# ════════════════════════════════════════════════════════════════
# STEP 1 — Tear down old network
# ════════════════════════════════════════════════════════════════
echo "━━━ STEP 1: Tearing down old network ━━━"
./network.sh down
sleep 2
echo "✓ Old network down"

# ════════════════════════════════════════════════════════════════
# STEP 2 — Start network + create investment-channel
# Org1 + Org2 auto-join investment-channel
# ════════════════════════════════════════════════════════════════
echo ""
echo "━━━ STEP 2: Starting network + creating investment-channel ━━━"
./network.sh up createChannel -c investment-channel -ca -s couchdb
sleep 3
echo "✓ investment-channel created — Org1 + Org2 joined"

# ════════════════════════════════════════════════════════════════
# STEP 3 — Add Org3 (Validator) and join investment-channel
# ════════════════════════════════════════════════════════════════
echo ""
echo "━━━ STEP 3: Adding Org3 (Validator) ━━━"
cd addOrg3
./addOrg3.sh up -ca -s couchdb -c investment-channel
cd ..
sleep 2
echo "✓ Org3 added and joined investment-channel"

# ════════════════════════════════════════════════════════════════
# STEP 4 — Add Org4 (Platform) and join investment-channel
# ════════════════════════════════════════════════════════════════
echo ""
echo "━━━ STEP 4: Adding Org4 (Platform) ━━━"
cd addOrg4
./addOrg4.sh up -ca -s couchdb -c investment-channel
cd ..
sleep 2
echo "✓ Org4 added and joined investment-channel"

# ════════════════════════════════════════════════════════════════
# STEP 5 — Verify all 4 peers running
# ════════════════════════════════════════════════════════════════
echo ""
echo "━━━ STEP 5: Verifying all 4 peers ━━━"
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep peer0
echo ""

