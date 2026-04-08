# Hyperledger Fabric — Core Concepts Reference

This document is the foundational knowledge base for understanding Hyperledger Fabric networks.
It is written to be fed directly into an AI model for chatbot training.

---

## 1. What is Hyperledger Fabric?

Hyperledger Fabric is a permissioned, enterprise-grade blockchain framework hosted by the Linux Foundation. Unlike public blockchains (Bitcoin, Ethereum), every participant must be enrolled through a Certificate Authority (CA) before they can interact with the network. This makes it suitable for business networks where identity, privacy, and fine-grained access control are required.

**Key properties:**
- **Permissioned**: all participants have verified identities (X.509 certificates)
- **Modular**: pluggable consensus, CA, chaincode runtime
- **Private data / channels**: data visibility can be scoped per group of organizations
- **No cryptocurrency**: ledger updates are driven by application logic (chaincode), not mining
- **Deterministic finality**: once a block is committed it is final — no forks

---

## 2. Core Components

### 2.1 Organizations (Orgs)
An organization is a member of the network. Every real-world entity (company, regulator, bank, hospital, etc.) maps to one Fabric organization. Each org:
- Has its own Certificate Authority (CA) that issues identities
- Runs one or more **peers** (nodes that store the ledger and run chaincode)
- Has an MSP (Membership Service Provider) that defines its identity rules

### 2.2 Peers
A peer is a server process run by an organization. It:
- Maintains a copy of the ledger (blockchain + world state DB)
- Executes chaincode (smart contracts) during endorsement
- Validates and commits transactions to its local ledger

**Peer roles:**
- **Endorsing peer** — executes chaincode, signs the result
- **Committing peer** — every peer commits validated transactions
- **Anchor peer** — used for cross-org communication (gossip discovery)

### 2.3 Orderer
The orderer is a cluster of nodes (Raft consensus) that:
- Receives endorsed transactions from clients
- Orders them into blocks (deterministic, fair ordering)
- Distributes blocks to all peers on the channel

The orderer does NOT execute chaincode and does NOT hold the full world state.

### 2.4 Certificate Authority (CA)
A Fabric CA issues X.509 certificates to organizations, peers, orderers, and users. Every cryptographic operation (signing transactions, TLS) relies on these certificates. Two types:
- **Root CA** — self-signed, long-lived
- **Intermediate CA** — issued by root CA, used in production

### 2.5 Channels
A channel is a private subnet of communication between a subset of organizations. Each channel has:
- Its own ledger (completely isolated from other channels)
- Its own set of member organizations
- Its own chaincode deployments
- Its own policies

One Fabric network can have many channels. A peer can be a member of multiple channels simultaneously. Organizations that are NOT members of a channel cannot see any of its data.

### 2.6 Chaincode (Smart Contracts)
Chaincode is the business logic of the network. It is a program (Go, Node.js, or Java) deployed to a channel that:
- Defines the data model (structs / keys in world state)
- Implements transaction functions (invokes that change state)
- Implements query functions (reads that do not change state)
- Enforces business rules and access control

### 2.7 World State (CouchDB / LevelDB)
The world state is a key-value database that reflects the current state of all assets. CouchDB supports rich JSON queries; LevelDB is faster but only supports key-based lookups.

### 2.8 Ledger
The ledger consists of:
- **Blockchain** — append-only log of all committed transaction blocks (tamper-evident)
- **World state** — current snapshot of all key-value pairs derived from the blockchain

### 2.9 MSP (Membership Service Provider)
MSP is the identity framework. It maps certificates to organizational roles (admin, peer, client). The MSP folder contains:
- `cacerts/` — root CA certificate
- `admincerts/` — admin certificates
- `signcerts/` — the member's own certificate
- `keystore/` — private key

### 2.10 Endorsement Policy
An endorsement policy defines *which organizations must approve a transaction* before it can be committed. Examples:
- `OR('Org1MSP.peer', 'Org2MSP.peer')` — any one of Org1 or Org2
- `AND('Org1MSP.peer', 'Org2MSP.peer')` — both Org1 AND Org2 required
- `MAJORITY` — more than half of the channel members

The crowdfunding case study uses `AND(Org1MSP, Org2MSP, Org3MSP, Org4MSP)` so ALL four orgs must endorse every transaction.

---

## 3. Transaction Lifecycle

1. **Client application** builds a transaction proposal and sends it to one or more endorsing peers.
2. **Endorsing peers** simulate the chaincode, sign the read-write set, and return the endorsement.
3. **Client** collects enough endorsements to satisfy the policy, then sends the endorsed transaction to the **orderer**.
4. **Orderer** sequences the transaction into a block and broadcasts the block to all peers on the channel.
5. **Peers validate** each transaction (check policy, check MVCC conflicts) and commit valid transactions to the ledger.

---

## 4. Chaincode Lifecycle (Fabric v2.x)

The new lifecycle introduced in Fabric v2.0 requires majority org approval before chaincode goes live:

1. `peer lifecycle chaincode package` — create `.tar.gz` package
2. `peer lifecycle chaincode install` — install on each org's peer
3. `peer lifecycle chaincode approveformyorg` — each org approves the definition
4. `peer lifecycle chaincode checkcommitreadiness` — verify enough approvals
5. `peer lifecycle chaincode commit` — commit definition to channel (requires endorsements from approved orgs)

After commit, the chaincode is active. To upgrade: increment `--version` and `--sequence`, repeat steps 1–5.

---

## 5. Private Data Collections (PDC)

Private Data Collections let a subset of organizations share data *within a channel* without exposing it to all channel members. The private data is sent peer-to-peer (gossip), not through the orderer. Only the hash of the private data goes on-chain.

Example use case in crowdfunding: Investor Aadhaar numbers are stored in a PDC visible only to Org2 (Investor) and Org3 (Validator), not to Org1 (Startup).

---

## 6. Network Sizing Guide

| Use Case Complexity | Orgs | Channels | Chaincodes |
|---|---|---|---|
| Simple (supply chain, voting) | 2–3 | 1 | 1 |
| Medium (healthcare, trade finance) | 3–5 | 1–2 | 1–3 |
| Complex (financial market, government) | 5–10 | 3+ | 3+ |

**Rules of thumb:**
- Start with 2 orgs (Org1, Org2) using `network.sh up`; add extra orgs via `addOrg3.sh`, `addOrg4.sh`
- Create a new channel only when two groups of organizations need strict data isolation
- One chaincode per business domain (e.g., governance logic vs. financial logic)
- Use CouchDB (`-s couchdb`) when you need rich queries on the world state

---

## 7. Port Assignments (Standard Test-Network)

| Component | Port |
|---|---|
| Orderer (gRPC) | 7050 |
| Orderer (admin/osnadmin) | 7053 |
| Org1 peer | 7051 |
| Org2 peer | 9051 |
| Org3 peer (addOrg3) | 11051 |
| Org4 peer (addOrg4) | 12051 |
| Org1 CA | 7054 |
| Org2 CA | 8054 |
| Org3 CA | 11054 |
| Org4 CA | 12054 |
| CouchDB (Org1) | 5984 |
| CouchDB (Org2) | 7984 |

---

## 8. Supported Chaincode Languages

| Language | Pros | Cons |
|---|---|---|
| **Go** | Best performance, official samples | Requires Go toolchain |
| **Node.js** | Familiar to web developers | Slower startup |
| **Java** | Enterprise familiarity | Heavier resource usage |

The crowdfunding case study uses **Go** (`--lang go`).

---

## 9. Key Environment Variables

```bash
export CORE_PEER_LOCALMSPID=Org1MSP                           # Which org's identity to use
export CORE_PEER_TLS_ROOTCERT_FILE=.../tlsca.org1...-cert.pem # TLS root cert
export CORE_PEER_MSPCONFIGPATH=.../users/Admin@org1.../msp     # Admin MSP path
export CORE_PEER_ADDRESS=localhost:7051                        # Peer endpoint
export FABRIC_CFG_PATH=$PWD/../config/                         # Fabric config dir
export CORE_PEER_TLS_ENABLED=true                              # Always enable TLS
```

These variables must be set correctly before every `peer` command. A common cause of errors is running a command with the wrong org's environment variables.

---

## 10. Common Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| `peer binary not found` | PATH not set | `export PATH=$PWD/../bin:$PATH` |
| `ENDORSEMENT_POLICY_FAILURE` | Not enough endorsements collected | Pass `--peerAddresses` for all required orgs |
| `MVCC_READ_CONFLICT` | Two concurrent txs read the same key | Retry the transaction |
| `chaincode definition not agreed to by this org` | Not enough orgs approved | Run `approveformyorg` for all required orgs |
| `could not find channel artifacts` | Channel genesis block missing | Run `configtxgen` first |
| `TLS handshake failed` | Wrong TLS cert path | Double-check `--tlsRootCertFiles` paths |
| `Error: status 404` in osnadmin | Orderer not joined to channel | Run `osnadmin channel join` first |
