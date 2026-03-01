#!/bin/bash
# Run this EXACTLY as-is — it will show the real error
cd /mnt/c/Users/riyaf/Downloads/Blockchain1/fabric-samples/test-network

export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

echo "=== FULL ERROR OUTPUT (no suppression) ==="
peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls \
  --cafile $PWD/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem \
  -C mychannel -n crowdfund \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem \
  --peerAddresses localhost:11051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/org3.example.com/tlsca/tlsca.org3.example.com-cert.pem \
  --peerAddresses localhost:13051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/org4.example.com/tlsca/tlsca.org4.example.com-cert.pem \
  -c '{"Args":["RegisterStartup","STEST1","TestStartup","t@test.com","PAN001","GST001","2020-01-01","IT","Tech","India","MH","Mumbai","www.test.com","Test startup","2020","Founder1"]}'

echo ""
echo "=== EXIT CODE: $? ==="
echo ""
echo "=== DOCKER PEER LOGS (last 20 lines from peer0.org1) ==="
docker logs peer0.org1.example.com --tail 20 2>&1