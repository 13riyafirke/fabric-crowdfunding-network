# Crowdfunding Platform — 2-Channel Hyperledger Fabric Network
---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    gov-validation-channel                        │
│                                                                  │
│  Org1 (Startup) ──── Org3 (Validator) ──── Org4 (Platform)       │
│                                                                  │
│  • RegisterStartup / ValidateStartup                            │
│  • RegisterInvestor / ValidateInvestor                          │
│  • CreateProject / ApproveProject → generates approvalHash      │
│  • RejectProject / ResolveDispute                               │       │
└──────────────────────────┬──────────────────────────────────────┘
                           │ approvalHash (SHA-256)
                           │ passed manually by operator
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    investment-channel                            │
│                                                                  │
│  Org1 ──── Org2 (Investor) ──── Org3 ──── Org4                 │
│                                                                  │
│  • Mirror: RegisterStartup / RegisterInvestor (sync)            │
│  • ApproveProject (requires approvalHash from gov channel)      │
│  • Fund / ReleaseFunds / Refund                                 │
│  • RaiseDispute / ResolveDispute                                │
                                                                  │
└─────────────────────────────────────────────────────────────────┘
```
### What Org2 (Investor) Cannot See

| Data | Stored On | Org2 Access |
|---|---|---|
| Startup PAN / GST numbers | gov-validation-channel |  No access |
| Investor Aadhar numbers | gov-validation-channel |  No access |
| Validator decisions & notes | gov-validation-channel |  No access |
| Project rejection reasons | gov-validation-channel |  No access |
| approvalHash | gov-validation-channel | No access |

### Prerequisites

```bash
# Fabric binaries must be in PATH
export PATH=$PWD/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
export CORE_PEER_TLS_ENABLED=true

# Verify
peer version   # should show v2.5.x
```

### Step 1 — Start network + create investment-channel

```bash
cd fabric-samples/test-network

./network.sh up createChannel -c investment-channel -ca -s couchdb
# Org1 + Org2 auto-join investment-channel
```

### Step 2 — Add Org3 (Validator) to investment-channel

```bash
cd addOrg3
./addOrg3.sh up -ca -s couchdb -c investment-channel
cd ..
```

### Step 3 — Add Org4 (Platform) to investment-channel

```bash
cd addOrg4
./addOrg4.sh up -ca -s couchdb -c investment-channel
cd ..
```

### Step 4 — Generate gov-validation-channel genesis block

```bash
export FABRIC_CFG_PATH=$PWD/configtx

configtxgen \
  -profile ChannelUsingRaft \
  -outputBlock ./channel-artifacts/gov-validation-channel.block \
  -channelID gov-validation-channel
```

### Step 5 — Orderer joins gov-validation-channel

```bash
export ORDERER_CA=$PWD/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
export ORDERER_ADMIN_TLS_SIGN_CERT=$PWD/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=$PWD/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key
export FABRIC_CFG_PATH=$PWD/../config/

osnadmin channel join \
  --channelID gov-validation-channel \
  --config-block ./channel-artifacts/gov-validation-channel.block \
  -o localhost:7053 \
  --ca-file "$ORDERER_CA" \
  --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" \
  --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"
# Expected: Status 201
```

### Step 6 — Add Org3 and Org4 MSPs to gov-validation-channel config


cd addOrg3
./addOrg3.sh up -ca -s couchdb -c gov-validation-channel
cd ..

cd addOrg4
./addOrg4.sh up -ca -s couchdb -c gov-validation-channel
cd ..

### Step 7 — Manually join peers to gov-validation-channel

```bash
ORG1_TLS=$PWD/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
ORG3_TLS=$PWD/organizations/peerOrganizations/org3.example.com/tlsca/tlsca.org3.example.com-cert.pem
ORG4_TLS=$PWD/organizations/peerOrganizations/org4.example.com/tlsca/tlsca.org4.example.com-cert.pem

# Org1
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$ORG1_TLS
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
peer channel join -b ./channel-artifacts/gov-validation-channel.block

# Org3
export CORE_PEER_LOCALMSPID=Org3MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$ORG3_TLS
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051
peer channel join -b ./channel-artifacts/gov-validation-channel.block

# Org4
export CORE_PEER_LOCALMSPID=Org4MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$ORG4_TLS
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/org4.example.com/users/Admin@org4.example.com/msp
export CORE_PEER_ADDRESS=localhost:12051
peer channel join -b ./channel-artifacts/gov-validation-channel.block
```

### Verify Channel Membership

```bash
# Org2 should ONLY see investment-channel
export CORE_PEER_LOCALMSPID=Org2MSP
export CORE_PEER_ADDRESS=localhost:9051
peer channel list
# Output: Channels peers has joined: investment-channel  
```

## Chaincode Deployment

### governancecc — gov-validation-channel

```bash
export ORDERER_CA=$PWD/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
GOV_CC_PATH=/path/to/fabric-samples/gov-chaincode

# Package
peer lifecycle chaincode package governancecc.tar.gz \
  --path $GOV_CC_PATH --lang golang --label governancecc_1.0

# Install on Org1, Org3, Org4
for PORT in 7051 11051 12051; do
  # set env for each org, then:
  peer lifecycle chaincode install governancecc.tar.gz
done

export GOV_PKG_ID=governancecc_1.0:<hash>  # from install output

# Approve for all 3 orgs (run once per org with correct CORE_PEER env)
peer lifecycle chaincode approveformyorg \
  -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile $ORDERER_CA \
  --channelID gov-validation-channel \
  --name governancecc --version 1.0 \
  --package-id $GOV_PKG_ID --sequence 1 \
  --signature-policy "AND('Org1MSP.peer','Org3MSP.peer','Org4MSP.peer')" \
  --collections-config $GOV_CC_PATH/collections_config.json

# Commit (from Org1, targeting all 3 peers)
peer lifecycle chaincode commit \
  -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile $ORDERER_CA \
  --channelID gov-validation-channel \
  --name governancecc --version 1.0 --sequence 1 \
  --signature-policy "AND('Org1MSP.peer','Org3MSP.peer','Org4MSP.peer')" \
  --peerAddresses localhost:7051  --tlsRootCertFiles $ORG1_TLS \
  --peerAddresses localhost:11051 --tlsRootCertFiles $ORG3_TLS \
  --peerAddresses localhost:12051 --tlsRootCertFiles $ORG4_TLS \
  --collections-config $GOV_CC_PATH/collections_config.json
```

### investmentcc — investment-channel

```bash
INV_CC_PATH=/path/to/fabric-samples/investment-chaincode

# Package
peer lifecycle chaincode package investmentcc.tar.gz \
  --path $INV_CC_PATH --lang golang --label investmentcc_1.0

# Install on all 4 orgs
# Approve with version 1.1 (to avoid "unchanged content" error if re-approving)
peer lifecycle chaincode approveformyorg \
  --channelID investment-channel \
  --name investmentcc --version 1.1 --sequence 1 \
  --signature-policy "AND('Org1MSP.peer','Org2MSP.peer','Org3MSP.peer','Org4MSP.peer')" \
  --collections-config $INV_CC_PATH/collections_config.json

# Commit (targeting all 4 peers)
peer lifecycle chaincode commit \
  --channelID investment-channel \
  --name investmentcc --version 1.1 --sequence 1 \
  --signature-policy "AND('Org1MSP.peer','Org2MSP.peer','Org3MSP.peer','Org4MSP.peer')" \
  --peerAddresses localhost:7051  --tlsRootCertFiles $ORG1_TLS \
  --peerAddresses localhost:9051  --tlsRootCertFiles $ORG2_TLS \
  --peerAddresses localhost:11051 --tlsRootCertFiles $ORG3_TLS \
  --peerAddresses localhost:12051 --tlsRootCertFiles $ORG4_TLS \
  --collections-config $INV_CC_PATH/collections_config.json
```

### Final State Verification

```bash
peer lifecycle chaincode querycommitted --channelID gov-validation-channel
# Name: governancecc, Version: 1.0, Sequence: 1

peer lifecycle chaincode querycommitted --channelID investment-channel
# Name: investmentcc, Version: 1.1, Sequence: 1
```

---

## Running Tests

All test scripts are in the `test-network/` directory. Run from there:

./test-functional.sh    # 14 tests — business logic & edge cases
./test-privacy.sh       # 11 tests — channel isolation & data leakage
./test-security.sh      #  6 tests — role enforcement & unauthorized access
./test-failure.sh       #  9 tests — state machine & error handling
./test-concurrency.sh   #  3 tests — parallel transactions & MVCC

Results are saved to `./results/<suite>/` as CSV files.

##  Project Structure

```
fabric-samples/
├── test-network/
│   ├── network.sh                     # Fabric network lifecycle
│   ├── addOrg3/addOrg3.sh             # Org3 setup script
│   ├── addOrg4/addOrg4.sh             # Org4 setup script
│   ├── channel-artifacts/
│   │   ├── investment-channel.block
│   │   └── gov-validation-channel.block
│   ├── test-functional.sh             # 14 functional tests
│   ├── test-privacy.sh                # 11 privacy tests
│   ├── test-security.sh               #  6 security tests
│   ├── test-failure.sh                #  9 failure/recovery tests
│   └── test-concurrency.sh            #  3 concurrency tests
│
├── gov-chaincode/
│   ├── main.go                        # governancecc chaincode
│   ├── go.mod
│   ├── go.sum
│   └── collections_config.json        # PDC config (Org1MSP, Org3MSP, Org4MSP)
│
├── investment-chaincode/
│   ├── main.go                        # investmentcc chaincode
│   ├── go.mod
│   ├── go.sum
│   └── collections_config.json        # PDC config (all 4 MSPs)
│
├── README.md                          # Single-channel architecture docs
└── README_2CHANNEL.md                 # This file
```
