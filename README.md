# Crowdfunding on Hyperledger Fabric
## Architecture Overview

| Organization | Role | Port |
|---|---|---|
| **Org1** | Startup | 7051 |
| **Org2** | Investor | 9051 |
| **Org3** | Validator | 11051 |
| **Org4** | Platform  | 12051 |

### Endorsement Policy
All 4 organizations must endorse every transaction (`AND` policy across Org1MSP, Org2MSP, Org3MSP, Org4MSP).

## Prerequisites
Run install-fabric.sh for installing all Hyperledger Fabric binaries & samples (v2.x)
Command:  ./install-fabric.sh

## Network Setup

### Step 1 — Start the base network (Org1 + Org2)

From inside `fabric-samples/test-network`:

./network.sh up createChannel -c mychannel -ca -s couchdb

This starts:
- Org1 peer (port 7051)
- Org2 peer (port 9051)
- Orderer (port 7050)
- CouchDB state databases
- Certificate Authorities for each org
- Creates `mychannel`

### Step 2 — Add Org3
cd addOrg3
./addOrg3.sh up -ca -s couchdb

This adds Org3 peer on port **11051** and joins it to `mychannel`.

### Step 3 — Add Org4 
cd addOrg4
./addOrg4.sh up -ca -s couchdb
This adds Org4 peer on port **12051** and joins it to `mychannel`.


### Verify all peers are running
docker ps 

Expected output:
peer0.org1.example.com   0.0.0.0:7051->7051/tcp
peer0.org2.example.com   0.0.0.0:9051->9051/tcp
peer0.org3.example.com   0.0.0.0:11051->11051/tcp
peer0.org4.example.com   0.0.0.0:12051->12051/tcp
``

## Chaincode Deployment

From inside `fabric-samples/test-network`, deploy the Go chaincode:

./network.sh deployCC \
  -ccn crowdfund \
  -ccp ../crowdfund-chaincode \
  -ccl go

This will:
1. Package the chaincode
2. Install it on all 4 peers
3. Get approval from all 4 organizations
4. Commit the chaincode definition to `mychannel`

### Verify deployment

```bash
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode querycommitted -C mychannel -n crowdfund

Expected:
Committed chaincode definition for chaincode 'crowdfund' on channel 'mychannel':
Version: 1.0, Sequence: 1, Approvals: [Org1MSP: true, Org2MSP: true, Org3MSP: true, Org4MSP: true]


## Workflow

The platform enforces a strict 8-step sequence:

```
1. RegisterStartup   (Org1)  → Startup submits KYC & business details
2. ValidateStartup   (Org3)  → Validator reviews and approves startup
3. RegisterInvestor  (Org2)  → Investor submits KYC & financial info
4. ValidateInvestor  (Org3)  → Validator verifies KYC + income eligibility
5. CreateProject     (Org1)  → Approved startup creates a funding campaign
6. ApproveProject    (Org3)  → Validator reviews and approves the project
7. Fund              (Org2)  → Approved investor funds the project
8. ReleaseFunds      (Org4)  → Platform releases funds to startup
``

### Query Functions


# Get startup details
peer chaincode query -C mychannel -n crowdfund -c '{"Args":["GetStartup","S100"]}'

# Get investor details
peer chaincode query -C mychannel -n crowdfund -c '{"Args":["GetInvestor","I100"]}'

# Get project details
peer chaincode query -C mychannel -n crowdfund -c '{"Args":["GetProject","P100"]}'


## Running Performance Tests

All test scripts are in the `test-network` directory. Each script runs **20 transactions** and reports TPS, latency, and success rate.

``

### Or run each test individually in order

chmod +x test_*.sh

./test_1_register_startup.sh    # Org1 registers 20 startups (S100–S119)
./test_2_validate_startup.sh    # Org3 validates 20 startups
./test_3_register_investor.sh   # Org2 registers 20 investors (I100–I119)
./test_4_validate_investor.sh   # Org3 validates 20 investors
./test_5_create_project.sh      # Org1 creates 20 projects (P100–P119)
./test_6_approve_project.sh     # Org3 approves 20 projects
./test_7_fund_project.sh        # Org2 funds 20 projects
./test_8_release_funds.sh       # Org4 releases funds for 20 projects
```

## Project Structure

```
fabric-samples/
├── test-network/
│   ├── network.sh                        # Main network management script
│   ├── addOrg3/
│   │   └── addOrg3.sh                    # Script to add Org3 (Validator)
│   ├── addOrg4/
│   │   └── addOrg4.sh                    # Script to add Org4 (Platform)
│   ├── organizations/
│   │   └── peerOrganizations/            # TLS certs & MSP configs for all orgs
│   ├── test_1_register_startup.sh
│   ├── test_2_validate_startup.sh
│   ├── test_3_register_investor.sh
│   ├── test_4_validate_investor.sh
│   ├── test_5_create_project.sh
│   ├── test_6_approve_project.sh
│   ├── test_7_fund_project.sh
│   ├── test_8_release_funds.sh
│
└── crowdfund-chaincode/
    ├── go.mod
    ├── go.sum
    └── crowdfund.go                       # Main chaincode (structs + all functions)
```

## Teardown (To bring Network down:)

#To stop and clean up the entire network:

./network.sh down
``

## Remove ALL Docker Containers (Force Clean)
docker rm -f $(docker ps -aq)
``
## Remove Docker Volumes 
docker volume prune -f

Check: docker volume ls
Remove : docker volume rm compose_peer0.org4.example.com


This removes all containers, volumes, and generated crypto material.

---
For 2 channel refer readme_2channel 
