#!/bin/bash
# ============================================================
# SHARED ENVIRONMENT — TEST-NETWORK
# Org1=Startup(7051) Org2=Investor(9051) Org3=Validator(11051) Org4=Platform(12051)
# governancecc on gov-validation-channel (AND Org1MSP+Org3MSP+Org4MSP)
# investmentcc  on investment-channel    (AND Org1MSP+Org2MSP+Org3MSP+Org4MSP)
#
# IMPORTANT: Like microfab, each invoke uses the CALLING ORG'S PEER as primary.
# The endorsement policy handles role enforcement.
# For gov channel commits, we MUST still collect endorsements from all 3 required peers.
# ============================================================

BASE="/mnt/c/Users/riyaf/Downloads/Blockchain1/fabric-samples/test-network"
export PATH=$BASE/../bin:$PATH
export FABRIC_CFG_PATH=$BASE/../config/
export CORE_PEER_TLS_ENABLED=true

ORDERER_CA="$BASE/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem"
ORDERER="localhost:7050"
ORDERER_FLAGS="-o $ORDERER --ordererTLSHostnameOverride orderer.example.com --tls --cafile $ORDERER_CA"

GOV_CHANNEL="gov-validation-channel"
INV_CHANNEL="investment-channel"
GOV_CHAINCODE="governancecc"
INV_CHAINCODE="investmentcc"

ORG1_TLS="$BASE/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem"
ORG2_TLS="$BASE/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem"
ORG3_TLS="$BASE/organizations/peerOrganizations/org3.example.com/tlsca/tlsca.org3.example.com-cert.pem"
ORG4_TLS="$BASE/organizations/peerOrganizations/org4.example.com/tlsca/tlsca.org4.example.com-cert.pem"

set_startup_env() {
  export CORE_PEER_LOCALMSPID=Org1MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=$ORG1_TLS
  export CORE_PEER_MSPCONFIGPATH=$BASE/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
  export CORE_PEER_ADDRESS=localhost:7051
}
set_investor_env() {
  export CORE_PEER_LOCALMSPID=Org2MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=$ORG2_TLS
  export CORE_PEER_MSPCONFIGPATH=$BASE/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
  export CORE_PEER_ADDRESS=localhost:9051
}
set_validator_env() {
  export CORE_PEER_LOCALMSPID=Org3MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=$ORG3_TLS
  export CORE_PEER_MSPCONFIGPATH=$BASE/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
  export CORE_PEER_ADDRESS=localhost:11051
}
set_platform_env() {
  export CORE_PEER_LOCALMSPID=Org4MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=$ORG4_TLS
  export CORE_PEER_MSPCONFIGPATH=$BASE/organizations/peerOrganizations/org4.example.com/users/Admin@org4.example.com/msp
  export CORE_PEER_ADDRESS=localhost:12051
}

# Gov channel invoke — must collect endorsements from all 3 required orgs (Org1+Org3+Org4)
gov_invoke() {
  peer chaincode invoke $ORDERER_FLAGS -C "$GOV_CHANNEL" -n "$GOV_CHAINCODE" \
    --peerAddresses localhost:7051  --tlsRootCertFiles $ORG1_TLS \
    --peerAddresses localhost:11051 --tlsRootCertFiles $ORG3_TLS \
    --peerAddresses localhost:12051 --tlsRootCertFiles $ORG4_TLS \
    "$@"
}

# Investment channel invoke — must collect endorsements from all 4 orgs
inv_invoke() {
  peer chaincode invoke $ORDERER_FLAGS -C "$INV_CHANNEL" -n "$INV_CHAINCODE" \
    --peerAddresses localhost:7051  --tlsRootCertFiles $ORG1_TLS \
    --peerAddresses localhost:9051  --tlsRootCertFiles $ORG2_TLS \
    --peerAddresses localhost:11051 --tlsRootCertFiles $ORG3_TLS \
    --peerAddresses localhost:12051 --tlsRootCertFiles $ORG4_TLS \
    "$@"
}

# Single-peer invoke — used for security/role tests to simulate microfab behavior
# (calling org only sends to its own peer — endorsement policy rejects if wrong role)
gov_invoke_single() {
  # Uses CORE_PEER_ADDRESS and CORE_PEER_TLS_ROOTCERT_FILE from current env
  peer chaincode invoke $ORDERER_FLAGS -C "$GOV_CHANNEL" -n "$GOV_CHAINCODE" \
    --peerAddresses "$CORE_PEER_ADDRESS" --tlsRootCertFiles "$CORE_PEER_TLS_ROOTCERT_FILE" \
    "$@"
}
inv_invoke_single() {
  peer chaincode invoke $ORDERER_FLAGS -C "$INV_CHANNEL" -n "$INV_CHAINCODE" \
    --peerAddresses "$CORE_PEER_ADDRESS" --tlsRootCertFiles "$CORE_PEER_TLS_ROOTCERT_FILE" \
    "$@"
}

gov_query() { peer chaincode query -C "$GOV_CHANNEL" -n "$GOV_CHAINCODE" "$@"; }
inv_query()  { peer chaincode query -C "$INV_CHANNEL" -n "$INV_CHAINCODE" "$@"; }

pass()    { echo " ✅ PASS — $1"; PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "PASS,$1" >> "$RESULTS_FILE"; }
fail()    { echo " ❌ FAIL — $1"; FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "FAIL,$1" >> "$RESULTS_FILE"; }
section() { echo ""; echo "============================================"; echo " $1"; echo "============================================"; }

get_approval_hash() {
  local pid=$1
  set_validator_env
  gov_query -c "{\"function\":\"GetProject\",\"Args\":[\"$pid\"]}" 2>/dev/null | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('approvalHash',''))" 2>/dev/null
}
# ============================================================
# PRIVACY TESTS — test-network version
# Matches microfab logic EXACTLY. Expected: 8/11 pass
# Known failures (same as microfab — chaincode stores everything in public state):
#   TEST 2a: Aadhar IS visible → FAIL
#   TEST 2b: PAN IS visible → FAIL
#   TEST 4a: annualIncome IS visible → FAIL
# ============================================================
RESULTS_DIR="./results/privacy"; mkdir -p "$RESULTS_DIR"
RESULTS_FILE="$RESULTS_DIR/privacy_results.csv"
PASS=0; FAIL=0; TOTAL=0

setup() {
  section "SETUP — Preparing test entities"
  set_startup_env;   gov_invoke -c '{"function":"RegisterStartup","Args":["spriv","PrivStartup","priv@startup.com","PANPRIV1","GSTPRIV1","2022-01-01","fintech","product","India","Maharashtra","Pune","www.priv.com","Privacy test startup","2022","Priv Founder"]}' > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c '{"function":"ValidateStartup","Args":["spriv","APPROVED"]}' > /dev/null 2>&1; sleep 2
  set_startup_env;   gov_invoke -c '{"function":"RegisterInvestor","Args":["ipriv","PrivInvestor","priv@inv.com","PANPRIV2","AADHARPRIV2","angel","India","Maharashtra","Mumbai","fintech","large","1000000",""]}' > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c '{"function":"ValidateInvestor","Args":["ipriv","APPROVED"]}' > /dev/null 2>&1; sleep 2
  set_startup_env;   inv_invoke -c '{"function":"RegisterStartup","Args":["spriv","PrivStartup","priv@startup.com","PANPRIV1","GSTPRIV1","2022-01-01","fintech","product","India","Maharashtra","Pune","www.priv.com","Privacy test startup","2022","Priv Founder"]}' > /dev/null 2>&1; sleep 2
  set_validator_env; inv_invoke -c '{"function":"ValidateStartup","Args":["spriv","APPROVED"]}' > /dev/null 2>&1; sleep 2
  set_investor_env;  inv_invoke -c '{"function":"RegisterInvestor","Args":["ipriv","PrivInvestor","priv@inv.com","PANPRIV2","AADHARPRIV2","angel","India","Maharashtra","Mumbai","fintech","large","1000000",""]}' > /dev/null 2>&1; sleep 2
  set_validator_env; inv_invoke -c '{"function":"ValidateInvestor","Args":["ipriv","APPROVED"]}' > /dev/null 2>&1; sleep 2
  echo " Setup complete."
}

test_channel_isolation() {
  section "TEST 1 — CHANNEL ISOLATION"
  echo " Verifying InvestorOrg cannot access gov-validation-channel"
  # Org2 is NOT a member of gov-validation-channel — query must fail at peer level
  set_investor_env
  out=$(peer chaincode query -C "$GOV_CHANNEL" -n "$GOV_CHAINCODE" \
    -c '{"function":"GetStartup","Args":["spriv"]}' 2>&1)
  echo "$out" | grep -qiE "access denied|not authorized|no such channel|cannot connect|failed|error" \
    && pass "InvestorOrg correctly denied access to gov-validation-channel" \
    || { fail "InvestorOrg was able to access gov-validation-channel — CHANNEL ISOLATION BROKEN"; echo " Output: $out"; }
  out=$(peer chaincode invoke $ORDERER_FLAGS -C "$GOV_CHANNEL" -n "$GOV_CHAINCODE" \
    --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_TLS \
    -c '{"function":"GetProject","Args":["spriv"]}' 2>&1)
  echo "$out" | grep -qiE "access denied|not authorized|no such channel|cannot connect|failed|error" \
    && pass "InvestorOrg invoke on gov-validation-channel correctly rejected" \
    || { fail "InvestorOrg invoke on gov-validation-channel succeeded — ISOLATION BROKEN"; echo " Output: $out"; }
}

test_data_leakage() {
  section "TEST 2 — PUBLIC STATE DATA LEAKAGE CHECK"
  echo " Verifying sensitive fields not exposed in public state"
  # NOTE: These FAIL in microfab too — chaincode stores PAN/Aadhar/annualIncome in public state.
  # Keeping EXACT same test logic as microfab for direct comparison.

  set_startup_env
  out=$(inv_query -c '{"function":"GetInvestor","Args":["ipriv"]}' 2>&1)
  if echo "$out" | grep -q "AADHARPRIV2"; then
    fail "Investor Aadhar number visible in public state — DATA LEAKAGE DETECTED"
    echo " Output: $out"
  else
    pass "Investor Aadhar number NOT visible in public state"
  fi

  set_investor_env
  out=$(inv_query -c '{"function":"GetStartup","Args":["spriv"]}' 2>&1)
  if echo "$out" | grep -q "PANPRIV1"; then
    fail "Startup PAN number visible to InvestorOrg in public state — DATA LEAKAGE"
    echo " Output: $out"
  else
    pass "Startup PAN number NOT visible to InvestorOrg in public state"
  fi

  set_validator_env
  out=$(gov_query -c '{"function":"GetStartup","Args":["spriv"]}' 2>&1)
  echo "$out" | grep -q "validationStatus" \
    && pass "Validator can read startup validation status on gov channel" \
    || { fail "Validator cannot read startup on gov channel"; echo " Output: $out"; }
}

test_cross_channel_separation() {
  section "TEST 3 — CROSS CHANNEL DATA SEPARATION"
  echo " Verifying gov channel data does not leak to investment channel"
  local test_pid="priv_sep_test_$$"
  set_startup_env;  gov_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$test_pid\",\"spriv\",\"Sep Test\",\"Separation test\",\"50000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
  set_investor_env
  out=$(inv_query -c "{\"function\":\"GetProject\",\"Args\":[\"$test_pid\"]}" 2>&1)
  echo "$out" | grep -qiE "not found|error|failed" \
    && pass "Project created only on gov channel NOT visible on investment channel" \
    || { fail "Project from gov channel leaked to investment channel — SEPARATION BROKEN"; echo " Output: $out"; }
  set_validator_env
  out=$(gov_query -c "{\"function\":\"GetProject\",\"Args\":[\"$test_pid\"]}" 2>&1)
  echo "$out" | grep -q "projectID" \
    && pass "Project correctly exists only on gov channel" \
    || { fail "Project not found on gov channel either — unexpected"; echo " Output: $out"; }
}

test_org_boundary() {
  section "TEST 4 — ORG ROLE BOUNDARY ON INVESTMENT CHANNEL"
  echo " Verifying orgs can only access their own data"
  local test_pid="priv_bound_$$"
  set_startup_env;   gov_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$test_pid\",\"spriv\",\"Boundary Test\",\"Boundary test project\",\"100000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$test_pid\"]}" > /dev/null 2>&1; sleep 2
  local hash=$(get_approval_hash "$test_pid")
  set_platform_env;  inv_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$test_pid\",\"spriv\",\"Boundary Test\",\"Boundary test project\",\"100000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
                     inv_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$test_pid\",\"$hash\"]}" > /dev/null 2>&1; sleep 2
  set_investor_env;  inv_invoke -c "{\"function\":\"Fund\",\"Args\":[\"$test_pid\",\"ipriv\",\"102100\"]}" > /dev/null 2>&1; sleep 2
  # NOTE: This FAILS in microfab too — annualIncome IS in public state
  set_startup_env
  out=$(inv_query -c "{\"function\":\"GetInvestor\",\"Args\":[\"ipriv\"]}" 2>&1)
  if echo "$out" | grep -q "annualIncome"; then
    fail "Startup can see investor annualIncome — sensitive financial data exposed"
    echo " Output: $out"
  else
    pass "Startup cannot see investor sensitive financial fields"
  fi
  set_validator_env
  out=$(gov_query -c "{\"function\":\"GetInvestor\",\"Args\":[\"ipriv\"]}" 2>&1)
  echo "$out" | grep -q "validationStatus" \
    && pass "Validator correctly sees investor validation status on gov channel" \
    || { fail "Validator cannot see investor on gov channel"; echo " Output: $out"; }
}

test_approval_hash_integrity() {
  section "TEST 5 — APPROVAL HASH INTEGRITY"
  echo " Verifying fake approval hash is rejected on investment channel"
  local test_pid="priv_hash_$$"
  set_platform_env;  inv_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$test_pid\",\"spriv\",\"Hash Test\",\"Hash test project\",\"100000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
  out=$(inv_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$test_pid\",\"\"]}" 2>&1)
  echo "$out" | grep -qiE "approval hash required|error|failed|500" \
    && pass "Empty approval hash correctly rejected on investment channel" \
    || { fail "Empty approval hash was accepted — HASH INTEGRITY BROKEN"; echo " Output: $out"; }
  set_investor_env
  out=$(inv_invoke -c "{\"function\":\"Fund\",\"Args\":[\"$test_pid\",\"ipriv\",\"102100\"]}" 2>&1)
  echo "$out" | grep -qiE "not approved|error|failed|500" \
    && pass "Funding unapproved project correctly rejected" \
    || { fail "Unapproved project was funded — APPROVAL INTEGRITY BROKEN"; echo " Output: $out"; }
}

echo ""; echo "============================================"
echo " DUAL CHANNEL PRIVACY TEST SUITE"
echo " Gov: $GOV_CHANNEL | Inv: $INV_CHANNEL"
echo "============================================"
> "$RESULTS_FILE"; echo "status,test_name" >> "$RESULTS_FILE"
setup; sleep 2
test_channel_isolation; sleep 2
test_data_leakage; sleep 2
test_cross_channel_separation; sleep 2
test_org_boundary; sleep 2
test_approval_hash_integrity
echo ""; echo "============================================"; echo " PRIVACY TEST SUMMARY"
echo "============================================"
echo " Total Tests : $TOTAL"; echo " Passed      : $PASS"; echo " Failed      : $FAIL"
echo " Pass Rate   : $(echo "scale=1; $PASS*100/$TOTAL" | bc)%"; echo "============================================"