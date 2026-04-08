# Hyperledger Fabric Chatbot — Training Q&A Dataset

This file contains question-answer pairs reverse-engineered from the crowdfunding
case study implementation. Feed these pairs to your LLM fine-tuning pipeline.
Each entry follows the format:

```
Q: <question a user might ask>
A: <complete, actionable answer>
```

---

## SECTION 1 — Hyperledger Fabric Fundamentals

---

**Q: What is Hyperledger Fabric and when should I use it?**

A: Hyperledger Fabric is a permissioned enterprise blockchain framework. Use it when you need a shared, tamper-proof ledger between multiple organizations that do NOT fully trust each other, but must collaborate on a common business process. Typical use cases include supply chain, trade finance, healthcare data sharing, crowdfunding, government KYC, and cross-bank settlements. Unlike Ethereum or Bitcoin, every participant must be enrolled through a Certificate Authority — there is no anonymous access or cryptocurrency mining.

---

**Q: What is the difference between a public blockchain and Hyperledger Fabric?**

A: Public blockchains (Bitcoin, Ethereum) are open to anyone, use mining or proof-of-stake, and expose all data to everyone. Hyperledger Fabric is permissioned: every participant has a verified identity (X.509 certificate), transactions are finalized in seconds (not minutes), no cryptocurrency or mining is needed, data visibility can be restricted by channel and private data collections, and throughput is orders of magnitude higher (hundreds of TPS vs. ~15 TPS on Ethereum).

---

**Q: What is an organization in Hyperledger Fabric?**

A: An organization (org) represents a real-world business entity participating in the network. Each org has its own Certificate Authority that issues identities, runs one or more peer nodes that store the ledger, and has an MSP (Membership Service Provider) that maps certificates to roles. In the crowdfunding case study: Org1 = Startup, Org2 = Investor, Org3 = Validator, Org4 = Platform.

---

**Q: What is a peer in Hyperledger Fabric?**

A: A peer is a server process run by an organization. It stores the ledger (blockchain + world state database), executes chaincode during transaction endorsement, and validates and commits blocks received from the orderer. Each org typically runs at least one peer. In the Fabric test-network, Org1's peer runs on port 7051, Org2 on 9051, Org3 on 11051, and Org4 on 12051.

---

**Q: What is the orderer and what does it do?**

A: The orderer is a cluster of nodes that provides consensus for the network. It receives endorsed transactions from client applications, orders them into blocks (using Raft consensus in Fabric v2.x), and distributes blocks to all peers on the channel. The orderer does NOT execute chaincode and does NOT hold the world state — it only orders transactions. The default orderer port is 7050 (gRPC) and 7053 (admin/osnadmin).

---

**Q: What is a channel in Hyperledger Fabric?**

A: A channel is a private subnet within a Fabric network. It has its own isolated ledger, its own member organizations, its own chaincode, and its own policies. Organizations that are not members of a channel cannot see any of its transactions or data. In the 2-channel crowdfunding architecture: `gov-validation-channel` is for governance (Org1+Org3+Org4) and `investment-channel` is for financial transactions (Org1+Org2+Org3+Org4). Org2 (Investor) cannot see KYC data on the governance channel.

---

**Q: What is chaincode?**

A: Chaincode is the smart contract (business logic) running on a Fabric channel. It is a program written in Go, Node.js, or Java that defines the data model, transaction functions (invokes), and query functions. Chaincode runs inside Docker containers on each peer. In the crowdfunding case study, the chaincode is written in Go and implements functions like RegisterStartup, ValidateStartup, RegisterInvestor, Fund, and ReleaseFunds.

---

**Q: What is an endorsement policy?**

A: An endorsement policy defines which organizations must approve (simulate and sign) a transaction before it can be submitted to the orderer. Examples:
- `OR('Org1MSP.peer','Org2MSP.peer')` — either org can endorse
- `AND('Org1MSP.peer','Org2MSP.peer')` — BOTH orgs must endorse
- `OutOf(2, 'Org1MSP.peer','Org2MSP.peer','Org3MSP.peer')` — any 2 of 3

The crowdfunding case study uses `AND('Org1MSP.peer','Org2MSP.peer','Org3MSP.peer','Org4MSP.peer')` — all four organizations must endorse every transaction, ensuring maximum trust and auditability.

---

**Q: What is the world state?**

A: The world state is a key-value database that holds the current value of every asset managed by the chaincode. It is derived from the blockchain (ledger history) and provides fast lookups without scanning the entire transaction log. Fabric supports two world state databases:
- **LevelDB** — default, key-value only, faster
- **CouchDB** — JSON documents, supports rich queries (`selector`, `sort`, `fields`)

Use CouchDB when your chaincode needs queries like "find all projects with status=APPROVED".

---

**Q: What is an MSP?**

A: MSP (Membership Service Provider) is the identity framework. It is a folder structure containing the certificates that define an organization's identity:
- `cacerts/` — CA root certificate
- `admincerts/` — admin certificates
- `signcerts/` — the peer/user's own certificate
- `keystore/` — private key (for signing)
- `tlscacerts/` — TLS certificates

The `CORE_PEER_MSPCONFIGPATH` environment variable points to the MSP folder of the admin submitting commands.

---

**Q: What is TLS in the context of Hyperledger Fabric?**

A: Transport Layer Security (TLS) encrypts all communication between peers, orderers, clients, and CAs. In Fabric, TLS is enabled by default. Every `peer` CLI command must provide:
- `--cafile` — the orderer's TLS CA certificate (for `-o` flag)
- `--tlsRootCertFiles` — the peer's TLS CA certificate (for `--peerAddresses`)
- `CORE_PEER_TLS_ROOTCERT_FILE` — set in environment for the current peer context

---

## SECTION 2 — Network Design Questions

---

**Q: How many organizations do I need for my Hyperledger Fabric network?**

A: You need at least 2 organizations (Fabric's test-network starts with 2). Decide based on your use case:
- **2 orgs** — simple bilateral agreement (e.g., buyer and seller)
- **3 orgs** — add a neutral third party (e.g., regulator, auditor, validator)
- **4 orgs** — add a platform/operator org (e.g., the system running the service)
- **5+ orgs** — consortium with multiple competing parties

In the crowdfunding case study, 4 organizations were used: Startup (Org1), Investor (Org2), Validator/Regulator (Org3), and Platform (Org4).

---

**Q: How do I decide how many channels I need?**

A: Create a new channel only when two groups of organizations need strict data isolation from each other:
- **1 channel** — all orgs see all data, simplest setup
- **2 channels** — split private governance data from financial data (crowdfunding case study uses this)
- **3+ channels** — needed in large consortia with many independent business processes

If some organizations should never see certain data, put that data on a separate channel or use Private Data Collections (PDC) within a single channel.

---

**Q: When should I use Private Data Collections instead of multiple channels?**

A: Use PDC when:
- You want to keep most data on one channel but hide specific fields from some orgs
- The secret data is small (Aadhaar/PAN numbers, salary data)
- You want the hash of the private data on-chain as proof of existence

Use multiple channels when:
- Entirely different business processes run in parallel
- Whole transaction sets must be hidden (not just fields)
- Different chaincode must be applied to different data sets

---

**Q: What endorsement policy should I use?**

A: Choose based on your trust model:
- `AND(all orgs)` — maximum trust, but any org going offline blocks all transactions. Best for high-stakes use cases (crowdfunding, cross-bank payments).
- `OR(any org)` — maximum availability, but one compromised org can write bad data.
- `MAJORITY` — balanced; network stays live if a minority of orgs are offline.
- `OutOf(N, ...)` — custom threshold.

For the crowdfunding case study `AND(Org1MSP, Org2MSP, Org3MSP, Org4MSP)` was chosen because no single party should be able to approve a funding transaction unilaterally.

---

**Q: How do I add more than 2 organizations to a Fabric network?**

A: The default `network.sh up` creates Org1 and Org2. To add more:
1. Start the base network: `./network.sh up createChannel -c mychannel -ca -s couchdb`
2. Add Org3: `cd addOrg3 && ./addOrg3.sh up -ca -s couchdb -c mychannel && cd ..`
3. Add Org4: `cd addOrg4 && ./addOrg4.sh up -ca -s couchdb -c mychannel && cd ..`
4. Verify: `docker ps` — you should see peer containers for org1, org2, org3, org4

Each `addOrgN.sh` script generates crypto material for the new org, updates the channel config to include its MSP, and joins the new peer to the channel.

---

**Q: What chaincode language should I choose?**

A: 
- **Go** — recommended. Best performance, smallest Docker image, most complete official examples. Used in the crowdfunding case study.
- **Node.js** — good if your team knows JavaScript/TypeScript. Slightly slower cold-start.
- **Java** — good for enterprises already using Java. Heavier memory footprint.

For all new projects, use **Go** unless you have a specific reason not to.

---

## SECTION 3 — Network Setup Step-by-Step

---

**Q: What are the prerequisites for setting up a Hyperledger Fabric network?**

A: You need:
1. **OS**: Linux (Ubuntu 20.04+ recommended) or macOS. Windows with WSL2 works.
2. **Docker** (version 20.10+) and **Docker Compose**
3. **Go** (version 1.21+) for chaincode development
4. **curl**, **git**, **jq**, **bc** utilities
5. **Fabric binaries** (`peer`, `configtxgen`, `osnadmin`, etc.) installed via `./install-fabric.sh`

Run `./install-fabric.sh` first. It downloads Fabric binaries, Docker images, and the test-network samples.

---

**Q: How do I start a basic 2-organization Hyperledger Fabric network?**

A:
```bash
cd fabric-samples/test-network

# Start network with Org1 + Org2, create a channel, enable CAs, use CouchDB
./network.sh up createChannel -c mychannel -ca -s couchdb
```

This command:
- Generates crypto material (X.509 certs) for Org1, Org2, and the Orderer
- Starts Docker containers for peer0.org1, peer0.org2, orderer.example.com, and two CouchDB instances
- Creates the channel `mychannel` and joins both peers to it

Verify: `docker ps` — you should see 5 containers (2 peers, 1 orderer, 2 CouchDBs).

---

**Q: How do I deploy chaincode on the network?**

A: Use the `deployCC` subcommand of `network.sh`:
```bash
./network.sh deployCC \
  -ccn <chaincode-name> \
  -ccp <path-to-chaincode-folder> \
  -ccl go \
  -c mychannel
```

For a 4-org network you must also pass endorsement policy and ensure all 4 peers are targeted. The deploy script will:
1. Package the chaincode into a `.tar.gz`
2. Install it on each org's peer
3. Run `approveformyorg` for each org
4. Check commit readiness
5. Commit the chaincode definition to the channel

Verify deployment:
```bash
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
peer lifecycle chaincode querycommitted -C mychannel -n <chaincode-name>
```

---

**Q: How do I invoke a chaincode transaction?**

A: Use `peer chaincode invoke`:
```bash
peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls \
  --cafile $PWD/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem \
  -C mychannel \
  -n <chaincode-name> \
  --peerAddresses localhost:7051 --tlsRootCertFiles <org1-tls-cert> \
  --peerAddresses localhost:9051 --tlsRootCertFiles <org2-tls-cert> \
  -c '{"Args":["FunctionName","arg1","arg2"]}'
```

You must include `--peerAddresses` for every org required by the endorsement policy. If you have an AND policy over 4 orgs, you must list all 4.

---

**Q: How do I query (read) data from the chaincode without modifying state?**

A: Use `peer chaincode query`:
```bash
peer chaincode query \
  -C mychannel \
  -n <chaincode-name> \
  -c '{"Args":["GetAsset","ASSET_ID"]}'
```

Query does NOT require orderer or endorsement policy satisfaction — it reads directly from the peer's local state. Always set the correct `CORE_PEER_*` environment variables before querying.

---

**Q: How do I bring down and clean up the Fabric network?**

A:
```bash
# Graceful teardown — removes containers, volumes, crypto material
./network.sh down

# Force remove all Docker containers
docker rm -f $(docker ps -aq)

# Prune Docker volumes
docker volume prune -f

# Remove specific volume if needed
docker volume rm compose_peer0.org4.example.com
```

Always run `network.sh down` before restarting a network to avoid certificate and state conflicts.

---

## SECTION 4 — Chaincode Development

---

**Q: What is the structure of a Go chaincode file?**

A: A Go chaincode must:
1. Import `"github.com/hyperledger/fabric-contract-api-go/contractapi"`
2. Define a `SmartContract` struct that embeds `contractapi.Contract`
3. Implement `InitLedger(ctx contractapi.TransactionContextInterface)` for initialization
4. Implement transaction functions with `(ctx contractapi.TransactionContextInterface, ...args) error` signature
5. Implement query functions that return data
6. Have a `main()` function that calls `contractapi.NewChaincode` and starts the server

Example skeleton:
```go
package main

import (
    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type SmartContract struct {
    contractapi.Contract
}

func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *SmartContract) CreateAsset(ctx contractapi.TransactionContextInterface, id string, value string) error {
    asset := map[string]string{"ID": id, "Value": value}
    assetJSON, _ := json.Marshal(asset)
    return ctx.GetStub().PutState(id, assetJSON)
}

func main() {
    cc, _ := contractapi.NewChaincode(&SmartContract{})
    cc.Start()
}
```

---

**Q: How do I read and write state in chaincode?**

A:
- **Write**: `ctx.GetStub().PutState(key, valueBytes)` — stores a JSON-serialized value
- **Read**: `ctx.GetStub().GetState(key)` — returns bytes or nil
- **Delete**: `ctx.GetStub().DelState(key)`
- **Rich query** (CouchDB only): `ctx.GetStub().GetQueryResult(queryString)` where queryString is a Mango query
- **History**: `ctx.GetStub().GetHistoryForKey(key)` — returns all historical values

---

**Q: How do I enforce role-based access in chaincode?**

A: Read the client's MSPID from the transaction context and compare it to the allowed org:
```go
func (s *SmartContract) ValidateStartup(ctx contractapi.TransactionContextInterface, id string) error {
    clientMSP, err := ctx.GetClientIdentity().GetMSPID()
    if err != nil {
        return fmt.Errorf("failed to get client MSP: %v", err)
    }
    if clientMSP != "Org3MSP" {
        return fmt.Errorf("only Org3 (Validator) can call ValidateStartup, got: %s", clientMSP)
    }
    // ... rest of logic
}
```

---

**Q: How do I implement a state machine in chaincode?**

A: Define a `Status` field on your asset struct, and check it at the start of each transition:
```go
const (
    StatusPending  = "PENDING"
    StatusApproved = "APPROVED"
    StatusFunded   = "FUNDED"
    StatusReleased = "RELEASED"
)

func (s *SmartContract) ApproveProject(ctx ..., projectID string) error {
    project, err := s.getProject(ctx, projectID)
    if err != nil { return err }

    if project.Status != StatusPending {
        return fmt.Errorf("project %s is not in PENDING state, current: %s", projectID, project.Status)
    }
    project.Status = StatusApproved
    return s.putProject(ctx, project)
}
```

---

**Q: How do I implement a funding logic with goal tracking in chaincode?**

A:
```go
type Project struct {
    ID          string  `json:"id"`
    Goal        int64   `json:"goal"`
    Raised      int64   `json:"raised"`
    Status      string  `json:"status"`
}

func (s *SmartContract) Fund(ctx ..., projectID string, investorID string, amountStr string) error {
    amount, _ := strconv.ParseInt(amountStr, 10, 64)
    project, _ := s.getProject(ctx, projectID)

    if project.Status != "APPROVED" {
        return fmt.Errorf("project must be APPROVED to receive funds")
    }

    project.Raised += amount
    if project.Raised >= project.Goal {
        project.Status = "FUNDED"
    }

    return s.putProject(ctx, project)
}
```

---

**Q: How does the chaincode get the caller's identity?**

A:
```go
// Get the MSP ID of the calling organization
mspID, err := ctx.GetClientIdentity().GetMSPID()

// Get specific attribute from the certificate (e.g., role)
val, found, err := ctx.GetClientIdentity().GetAttributeValue("role")

// Get the full certificate of the calling user
cert, err := ctx.GetClientIdentity().GetX509Certificate()

// Get a unique ID string for the caller
id, err := ctx.GetClientIdentity().GetID()
```

---

## SECTION 5 — The Crowdfunding Case Study (Reverse-Engineered)

---

**Q: Describe the overall architecture of the crowdfunding Hyperledger Fabric network.**

A: The crowdfunding network has 4 organizations:
- **Org1 (Startup)** — Companies seeking funding; port 7051
- **Org2 (Investor)** — Individuals or entities providing capital; port 9051
- **Org3 (Validator)** — KYC/compliance authority that approves startups, investors, and projects; port 11051
- **Org4 (Platform)** — The crowdfunding platform itself, which releases funds; port 12051

**Single-channel version**: one channel `mychannel`, one chaincode `crowdfund`, `AND` policy over all 4 orgs.

**Two-channel version**: 
- `gov-validation-channel` (Org1+Org3+Org4) for KYC and governance — Investors cannot see PAN/Aadhaar numbers
- `investment-channel` (Org1+Org2+Org3+Org4) for financial transactions

---

**Q: What is the transaction workflow in the crowdfunding platform?**

A: The platform enforces a strict 8-step state machine:
1. **RegisterStartup** (Org1) — Startup submits company name, PAN, GST, industry, description
2. **ValidateStartup** (Org3) — Validator reviews KYC and approves/rejects the startup
3. **RegisterInvestor** (Org2) — Investor submits name, Aadhaar, income details
4. **ValidateInvestor** (Org3) — Validator verifies KYC and income eligibility
5. **CreateProject** (Org1) — Approved startup creates a funding campaign with goal amount
6. **ApproveProject** (Org3) — Validator reviews and approves the project
7. **Fund** (Org2) — Approved investor funds the project
8. **ReleaseFunds** (Org4) — Platform releases collected funds to startup

Each step checks that the previous step has been completed (state machine validation in chaincode).

---

**Q: How do I register a startup on the crowdfunding network?**

A: Set Org1 environment and invoke RegisterStartup:
```bash
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer chaincode invoke \
  -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
  --cafile $PWD/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem \
  -C mychannel -n crowdfund \
  --peerAddresses localhost:7051 --tlsRootCertFiles .../org1/tlsca/tlsca.org1...-cert.pem \
  --peerAddresses localhost:9051 --tlsRootCertFiles .../org2/tlsca/tlsca.org2...-cert.pem \
  --peerAddresses localhost:11051 --tlsRootCertFiles .../org3/tlsca/tlsca.org3...-cert.pem \
  --peerAddresses localhost:12051 --tlsRootCertFiles .../org4/tlsca/tlsca.org4...-cert.pem \
  -c '{"Args":["RegisterStartup","S100","AcmeCorp","acme@test.com","PANST1234","GST1234","2020-01-01","IT","Tech","India","MH","Mumbai","www.acme.com","AI Startup","2020","Alice"]}'
```

---

**Q: How do I validate (approve) a startup on the crowdfunding network?**

A: Set Org3 (Validator) environment and invoke ValidateStartup:
```bash
export CORE_PEER_LOCALMSPID=Org3MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/org3.example.com/tlsca/tlsca.org3.example.com-cert.pem
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

peer chaincode invoke ... -c '{"Args":["ValidateStartup","S100","APPROVED","KYC verified"]}'
```

Only Org3's MSP is allowed to call ValidateStartup. The chaincode enforces this with `ctx.GetClientIdentity().GetMSPID()`.

---

**Q: How do I query the details of a startup, investor, or project?**

A:
```bash
# Get startup details
peer chaincode query -C mychannel -n crowdfund -c '{"Args":["GetStartup","S100"]}'

# Get investor details
peer chaincode query -C mychannel -n crowdfund -c '{"Args":["GetInvestor","I100"]}'

# Get project details
peer chaincode query -C mychannel -n crowdfund -c '{"Args":["GetProject","P100"]}'
```

---

**Q: How did the 2-channel crowdfunding architecture achieve privacy for Org2 (Investors)?**

A: By placing KYC/governance functions on a separate channel (`gov-validation-channel`) that does NOT include Org2:
- Startup PAN and GST numbers are stored only on `gov-validation-channel`
- Investor Aadhaar numbers are stored only on `gov-validation-channel`
- Validator decisions and rejection notes are on `gov-validation-channel`
- Org2 ONLY has access to `investment-channel` — it can fund projects and receive distributions but cannot see any sensitive KYC data

A cryptographic `approvalHash` (SHA-256) is generated on the governance channel when a project is approved, and passed as a parameter on the investment channel to prove the project was legitimately approved.

---

**Q: What are the performance characteristics of this network?**

A: In testing with 20 sequential transactions:
- Each test batch (20 transactions) ran against all 4 peers with `AND` endorsement policy
- TPS ranged from 1–5 for sequential transactions (limited by block timeout and endorsement round-trips)
- The `AND` policy over 4 orgs adds latency because all 4 endorsements must be collected before ordering
- For higher TPS, use `MAJORITY` policy, increase batch size, or use parallel transaction submission

---

## SECTION 6 — Script Generation and Automation

---

**Q: What information do I need to provide to generate a complete Fabric network setup script?**

A: You need to specify:
1. **Number of organizations** (minimum 2)
2. **Name and role of each organization** (e.g., Hospital, Pharmacy, Regulator)
3. **Number of channels** and which orgs belong to each channel
4. **Chaincode name and language** (Go/Node/Java)
5. **Chaincode path** (relative to test-network)
6. **Endorsement policy** for each chaincode (AND/OR/MAJORITY/OutOf)
7. **State database** (CouchDB for rich queries, LevelDB for simple key lookups)
8. **Business logic** — what functions does the chaincode need?
9. **Transaction workflow** — what is the sequence of operations?
10. **Access control** — which org can call which function?

---

**Q: What does a generated network setup script look like for a 3-org supply chain network?**

A: Here is a complete example for a 3-org supply chain (Manufacturer, Distributor, Retailer):

```bash
#!/bin/bash
set -e

BASE_DIR="$PWD"
export PATH=$BASE_DIR/../bin:$PATH
export FABRIC_CFG_PATH=$BASE_DIR/../config/
CHANNEL_NAME="supply-channel"
CHAINCODE_NAME="supplycc"
CHAINCODE_PATH="../supply-chaincode"
CHAINCODE_LANG="go"

echo "=== Tearing down old network ==="
./network.sh down
sleep 2

echo "=== Starting 2-org base network ==="
./network.sh up createChannel -c $CHANNEL_NAME -ca -s couchdb
sleep 3

echo "=== Adding Org3 (Retailer) ==="
cd addOrg3
./addOrg3.sh up -ca -s couchdb -c $CHANNEL_NAME
cd ..
sleep 2

echo "=== Deploying chaincode ==="
./network.sh deployCC \
  -ccn $CHAINCODE_NAME \
  -ccp $CHAINCODE_PATH \
  -ccl $CHAINCODE_LANG \
  -c $CHANNEL_NAME \
  -ccep "AND('Org1MSP.peer','Org2MSP.peer','Org3MSP.peer')"

echo "=== Verifying deployment ==="
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
peer lifecycle chaincode querycommitted -C $CHANNEL_NAME -n $CHAINCODE_NAME
echo "=== Network setup complete ==="
```

---

**Q: How does the automated script handle errors?**

A: Always include `set -e` at the top of the script so it stops on any error. Additionally:
- Add `sleep` between steps so Docker containers have time to fully start
- Check Docker with `docker ps` before invoking chaincode
- Verify chaincode deployment with `querycommitted` before running tests
- Use `|| true` for cleanup commands that may fail if nothing exists (e.g., `./network.sh down`)

---

**Q: How do I write a reusable invoke function in a shell script?**

A:
```bash
# Set environment for a specific org
set_org_env() {
  local ORG=$1
  local PORT=$2
  export CORE_PEER_LOCALMSPID="${ORG}MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/${ORG,,}.example.com/tlsca/tlsca.${ORG,,}.example.com-cert.pem
  export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/${ORG,,}.example.com/users/Admin@${ORG,,}.example.com/msp
  export CORE_PEER_ADDRESS=localhost:$PORT
}

# Generic invoke function
invoke_chaincode() {
  local CHANNEL=$1
  local CHAINCODE=$2
  local ARGS=$3
  peer chaincode invoke \
    -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
    --cafile $PWD/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem \
    -C $CHANNEL -n $CHAINCODE \
    --peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_TLS \
    --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_TLS \
    --peerAddresses localhost:11051 --tlsRootCertFiles $ORG3_TLS \
    -c "$ARGS"
}

# Usage
set_org_env "Org1" 7051
invoke_chaincode "mychannel" "mycc" '{"Args":["CreateAsset","A1","value"]}'
```

---

## SECTION 7 — Troubleshooting

---

**Q: The chaincode invoke fails with "ENDORSEMENT_POLICY_FAILURE". How do I fix it?**

A: This means not enough organizations endorsed the transaction. Check:
1. Are all required `--peerAddresses` listed in your invoke command?
2. Is each org's TLS certificate path correct (`--tlsRootCertFiles`)?
3. Is the endorsement policy correctly set during `approveformyorg` and `commit`?
4. Is the peer for each org actually running? (`docker ps`)
5. Did you set the correct `CORE_PEER_*` environment variables?

Run `peer lifecycle chaincode querycommitted -C <channel> -n <chaincode>` to see the committed endorsement policy.

---

**Q: The peer binary is not found. What do I do?**

A:
```bash
export PATH=$PWD/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
peer version   # should print version info
```

If that fails, the binaries haven't been downloaded. Run `./install-fabric.sh` from the fabric-samples root.

---

**Q: CouchDB is not accessible or queries fail. How do I fix it?**

A:
1. Check CouchDB containers are running: `docker ps | grep couchdb`
2. Access CouchDB UI: `http://localhost:5984/_utils` (Org1's CouchDB)
3. Ensure the network was started with `-s couchdb` flag
4. Check CouchDB logs: `docker logs couchdb0`

---

**Q: The channel creation fails with "genesis block not found". How do I fix it?**

A:
```bash
# Regenerate channel artifacts
export FABRIC_CFG_PATH=$PWD/configtx
configtxgen -profile ChannelUsingRaft -outputBlock ./channel-artifacts/<channelname>.block -channelID <channelname>
```

Make sure `configtx.yaml` includes the correct organization definitions.

---

**Q: Docker containers won't start. How do I diagnose?**

A:
```bash
# Check logs of a specific container
docker logs peer0.org1.example.com

# Check if ports are already in use
netstat -tulnp | grep 7051

# Full cleanup and restart
./network.sh down
docker rm -f $(docker ps -aq)
docker volume prune -f
./network.sh up createChannel -c mychannel -ca -s couchdb
```

---

## SECTION 8 — Performance Testing

---

**Q: How do I measure TPS (transactions per second) for a Fabric network?**

A:
```bash
total=20; success=0; failed=0; start=$(date +%s)

for ((i=1; i<=total; i++)); do
    peer chaincode invoke ... -c '{"Args":["CreateAsset","A'$i'","val"]}' 2>/dev/null
    [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))
done

end=$(date +%s); elapsed=$((end-start))
tps=$(echo "scale=2; $success/$elapsed" | bc)
echo "TPS: $tps | Success: $success/$total | Time: ${elapsed}s"
```

---

**Q: What factors affect TPS in Hyperledger Fabric?**

A:
- **Endorsement policy** — `AND` over 4 orgs adds 4 network round trips; `OR` reduces this
- **Block size / batch timeout** — larger blocks increase throughput; lower timeout reduces latency
- **CouchDB vs LevelDB** — CouchDB is slower for simple key lookups
- **Number of peers per org** — more peers means more parallel endorsement capability
- **Hardware** — CPU and disk I/O on peer nodes
- **Transaction conflicts (MVCC)** — concurrent updates to the same key cause failures

In the crowdfunding tests (sequential, single-thread), TPS was 1–5 due to 4-org endorsement latency.
