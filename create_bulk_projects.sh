#!/bin/bash

export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem

echo "Creating bulk projects P11-P50..."

for i in {11..50}; do
    echo -n "Creating project P$i... "
    peer chaincode invoke -o localhost:7050 \
      --ordererTLSHostnameOverride orderer.example.com \
      --tls --cafile $ORDERER_CA \
      -C mychannel -n crowdfund \
      -c "{\"function\":\"CreateProject\",\"Args\":[\"P$i\",\"S1\",\"Project $i\",\"Description $i\",\"100000\",\"12\",\"IT\",\"Software\",\"India\",\"Global\",\"Prototype\"]}" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅"
    else
        echo "❌ FAILED"
    fi
done

echo "Bulk project creation done!"