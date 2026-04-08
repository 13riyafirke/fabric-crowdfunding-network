# FabricBot — AI Chatbot Training Documentation

This folder contains everything needed to train or configure an AI chatbot
that helps users design, set up, and operate Hyperledger Fabric networks.

---

## Files in This Folder

| File | Purpose |
|---|---|
| `FABRIC_NETWORK_CONCEPTS.md` | Core Fabric concepts reference — fed as knowledge base |
| `CHATBOT_TRAINING_QA.md` | ~60 reverse-engineered Q&A pairs from the crowdfunding case study |
| `CHATBOT_CONVERSATION_FLOW.md` | Requirements gathering flow — how the chatbot should talk to users |
| `CHATBOT_SYSTEM_PROMPT.md` | Ready-to-paste LLM system prompt + fine-tuning instructions |
| `NETWORK_SCRIPT_TEMPLATE.sh` | Parameterized Bash script the chatbot fills in for users |
| `CHAINCODE_TEMPLATE.go` | Annotated Go chaincode template the chatbot adapts for users |
| `convert_qa_to_jsonl.py` | Python script to convert Q&A pairs into JSONL training data |

---

## What the Chatbot Does

```
User: "I want to build a crowdfunding blockchain network with 4 organizations"
         │
         ▼
FabricBot gathers requirements
  • How many orgs? What are their roles?
  • How many channels? Which orgs on each?
  • What chaincode logic do you need?
  • What is the transaction workflow?
  • What endorsement policy?
         │
         ▼
FabricBot generates:
  1. setup_network.sh   — run this to bring the network up
  2. chaincode.go       — your smart contract logic
  3. Invoke/query commands for every function
  4. Test script to verify everything works
```

---

## How to Use These Documents

### Option A — RAG (Recommended for Quick Start)

1. Chunk all `.md` files into 500-token pieces
2. Embed using OpenAI `text-embedding-3-small` or `all-MiniLM-L6-v2`
3. Store in a vector database (Chroma, Pinecone, Weaviate, FAISS)
4. At query time: retrieve top-5 chunks → inject into GPT-4 / Claude context
5. Use the system prompt from `CHATBOT_SYSTEM_PROMPT.md`

```bash
# Example: embed with LangChain + Chroma
pip install langchain chromadb openai
python3 - <<'EOF'
from langchain.document_loaders import DirectoryLoader, UnstructuredMarkdownLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.vectorstores import Chroma
from langchain.embeddings import OpenAIEmbeddings

loader = DirectoryLoader("docs/", glob="*.md", loader_cls=UnstructuredMarkdownLoader)
docs = loader.load()
splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)
chunks = splitter.split_documents(docs)
vectorstore = Chroma.from_documents(chunks, OpenAIEmbeddings(), persist_directory="./chroma_db")
vectorstore.persist()
print(f"Indexed {len(chunks)} chunks")
EOF
```

### Option B — Fine-Tuning (Better Quality, Higher Cost)

1. Convert Q&A pairs to JSONL:
   ```bash
   python3 docs/convert_qa_to_jsonl.py
   # Output: docs/training_data.jsonl
   ```

2. Upload and fine-tune (OpenAI example):
   ```bash
   pip install openai
   openai api fine_tuning.jobs.create \
     -t docs/training_data.jsonl \
     -m gpt-4o-mini \
     --suffix "fabricbot"
   ```

3. Use the fine-tuned model ID in your application with the system prompt from `CHATBOT_SYSTEM_PROMPT.md`

### Option C — Simple Prompt Engineering (Zero Cost)

Use any LLM (GPT-4, Claude, Mistral) with:
- The system prompt from `CHATBOT_SYSTEM_PROMPT.md`
- The content of `FABRIC_NETWORK_CONCEPTS.md` pasted as user context
- The Q&A pairs as few-shot examples

---

## Chatbot Capabilities

The trained chatbot can handle:

✅ **Network Design**
- How many orgs, channels, endorsement policy should I use?
- Should I use CouchDB or LevelDB?
- What is the difference between 1-channel and 2-channel architectures?

✅ **Script Generation**
- Generate `setup_network.sh` for N organizations
- Generate chaincode in Go for any business domain
- Generate invoke/query commands for every function

✅ **Deployment Guidance**
- Step-by-step chaincode lifecycle commands
- Environment variable setup for each org
- How to verify deployment succeeded

✅ **Troubleshooting**
- ENDORSEMENT_POLICY_FAILURE → why and how to fix
- peer binary not found → how to fix
- CouchDB not accessible → how to fix
- Channel creation failures → how to fix

✅ **Performance Testing**
- How to measure TPS
- How to write batch test scripts
- What factors affect throughput

---

## Case Study: Crowdfunding Network

The training data is derived from this implemented case study:

```
4 Organizations:
  Org1 (Startup)    port 7051  — RegisterStartup, CreateProject
  Org2 (Investor)   port 9051  — RegisterInvestor, Fund
  Org3 (Validator)  port 11051 — ValidateStartup, ValidateInvestor, ApproveProject
  Org4 (Platform)   port 12051 — ReleaseFunds

Endorsement: AND(Org1MSP, Org2MSP, Org3MSP, Org4MSP)

Workflow (8 steps):
  RegisterStartup → ValidateStartup → RegisterInvestor → ValidateInvestor
  → CreateProject → ApproveProject → Fund → ReleaseFunds

Two-channel variant:
  gov-validation-channel (Org1+Org3+Org4) — KYC & governance
  investment-channel (Org1+Org2+Org3+Org4) — financial transactions
  (Org2/Investor cannot see KYC data on gov channel)
```

---

## Extending the Documentation

To add more training examples:
1. Add new Q&A pairs to `CHATBOT_TRAINING_QA.md` following the existing format
2. Run `python3 docs/convert_qa_to_jsonl.py` to regenerate the JSONL files
3. Re-embed or re-fine-tune with the updated data
