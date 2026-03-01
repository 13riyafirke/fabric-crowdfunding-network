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
# FAILURE & RECOVERY TESTS — test-network version
# Matches microfab logic EXACTLY. Expected: 9/9 pass
# ============================================================
RESULTS_DIR="./results/failure"; mkdir -p "$RESULTS_DIR"
RESULTS_FILE="$RESULTS_DIR/failure_results.csv"
PASS=0; FAIL=0; TOTAL=0

setup_funded_project() {
  local prefix=$1; local pid="${prefix}_$$"
  set_startup_env;   gov_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$pid\",\"sfail\",\"$prefix Project\",\"Test\",\"100000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$pid\"]}" > /dev/null 2>&1; sleep 2
  local hash=$(get_approval_hash "$pid")
  set_platform_env;  inv_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$pid\",\"sfail\",\"$prefix Project\",\"Test\",\"100000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
                     inv_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$pid\",\"$hash\"]}" > /dev/null 2>&1; sleep 2
  set_investor_env;  inv_invoke -c "{\"function\":\"Fund\",\"Args\":[\"$pid\",\"ifail\",\"102100\"]}" > /dev/null 2>&1; sleep 2
  echo "$pid"
}

setup() {
  section "SETUP — Preparing base entities"
  set_startup_env;   gov_invoke -c '{"function":"RegisterStartup","Args":["sfail","FailStartup","fail@startup.com","PANFL1","GSTFL1","2022-01-01","fintech","product","India","Maharashtra","Pune","www.fail.com","Failure test startup","2022","Fail Founder"]}' > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c '{"function":"ValidateStartup","Args":["sfail","APPROVED"]}' > /dev/null 2>&1; sleep 2
  set_startup_env;   gov_invoke -c '{"function":"RegisterInvestor","Args":["ifail","FailInvestor","fail@inv.com","PANFL2","AADHARFL2","angel","India","Maharashtra","Mumbai","fintech","large","1000000",""]}' > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c '{"function":"ValidateInvestor","Args":["ifail","APPROVED"]}' > /dev/null 2>&1; sleep 2
  set_startup_env;   inv_invoke -c '{"function":"RegisterStartup","Args":["sfail","FailStartup","fail@startup.com","PANFL1","GSTFL1","2022-01-01","fintech","product","India","Maharashtra","Pune","www.fail.com","Failure test startup","2022","Fail Founder"]}' > /dev/null 2>&1; sleep 2
  set_validator_env; inv_invoke -c '{"function":"ValidateStartup","Args":["sfail","APPROVED"]}' > /dev/null 2>&1; sleep 2
  set_investor_env;  inv_invoke -c '{"function":"RegisterInvestor","Args":["ifail","FailInvestor","fail@inv.com","PANFL2","AADHARFL2","angel","India","Maharashtra","Mumbai","fintech","large","1000000",""]}' > /dev/null 2>&1; sleep 2
  set_validator_env; inv_invoke -c '{"function":"ValidateInvestor","Args":["ifail","APPROVED"]}' > /dev/null 2>&1; sleep 2
  echo " Setup complete."
}

test_fund_closed_project() {
  section "TEST 1 — FUND ALREADY CLOSED/RELEASED PROJECT"
  local pid=$(setup_funded_project "closed")
  set_platform_env;  inv_invoke -c "{\"function\":\"ReleaseFunds\",\"Args\":[\"$pid\"]}" > /dev/null 2>&1; sleep 2
  set_investor_env
  out=$(inv_invoke -c "{\"function\":\"Fund\",\"Args\":[\"$pid\",\"ifail\",\"50000\"]}" 2>&1)
  echo "$out" | grep -qiE "already closed|not open|error|500" && pass "Funding closed project correctly rejected" || fail "Closed project was funded — STATE MACHINE BROKEN"
}

test_double_release() {
  section "TEST 2 — DOUBLE RELEASE FUNDS"
  local pid=$(setup_funded_project "release")
  set_platform_env;  inv_invoke -c "{\"function\":\"ReleaseFunds\",\"Args\":[\"$pid\"]}" > /dev/null 2>&1; sleep 2
  out=$(inv_invoke -c "{\"function\":\"ReleaseFunds\",\"Args\":[\"$pid\"]}" 2>&1)
  echo "$out" | grep -qiE "already released|not open|error|500" && pass "Double release correctly rejected" || fail "Double fund release was allowed — SERIOUS BUG"
}

test_refund_active_project() {
  section "TEST 3 — REFUND ON ACTIVE OPEN PROJECT"
  local pid="fail_refact_$$"
  set_startup_env;   gov_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$pid\",\"sfail\",\"Active Project\",\"Active\",\"100000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$pid\"]}" > /dev/null 2>&1; sleep 2
  local hash=$(get_approval_hash "$pid")
  set_platform_env;  inv_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$pid\",\"sfail\",\"Active Project\",\"Active\",\"100000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
                     inv_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$pid\",\"$hash\"]}" > /dev/null 2>&1; sleep 2
  set_investor_env;  inv_invoke -c "{\"function\":\"Fund\",\"Args\":[\"$pid\",\"ifail\",\"50000\"]}" > /dev/null 2>&1; sleep 2
  out=$(inv_invoke -c "{\"function\":\"Refund\",\"Args\":[\"$pid\",\"ifail\"]}" 2>&1)
  echo "$out" | grep -qiE "project not cancelled|not eligible|error|500" && pass "Refund on active project correctly rejected" || fail "Refund was allowed on active project — REFUND LOGIC BROKEN"
}

test_double_approve() {
  section "TEST 4 — DOUBLE APPROVAL OF PROJECT"
  local pid="fail_dapprove_$$"
  set_startup_env;   gov_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$pid\",\"sfail\",\"Double Approve\",\"Test\",\"100000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$pid\"]}" > /dev/null 2>&1; sleep 2
  out=$(gov_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$pid\"]}" 2>&1)
  echo "$out" | grep -qiE "already approved|error|500" && pass "Double approval correctly rejected" || fail "Project was approved twice — STATE MACHINE BROKEN"
}

test_query_nonexistent() {
  section "TEST 5 — QUERY NON-EXISTENT ENTITIES"
  set_validator_env
  out=$(gov_query -c '{"function":"GetStartup","Args":["startup_does_not_exist_xyz"]}' 2>&1)
  echo "$out" | grep -qiE "not found|error|failed" && pass "Non-existent startup query returns proper error" || { fail "Non-existent startup query returned data — unexpected"; echo " Output: $out"; }
  out=$(gov_query -c '{"function":"GetInvestor","Args":["investor_does_not_exist_xyz"]}' 2>&1)
  echo "$out" | grep -qiE "not found|error|failed" && pass "Non-existent investor query returns proper error" || { fail "Non-existent investor query returned data — unexpected"; echo " Output: $out"; }
  out=$(gov_query -c '{"function":"GetProject","Args":["project_does_not_exist_xyz"]}' 2>&1)
  echo "$out" | grep -qiE "not found|error|failed" && pass "Non-existent project query returns proper error" || { fail "Non-existent project query returned data — unexpected"; echo " Output: $out"; }
}

test_resolve_nonexistent_dispute() {
  section "TEST 6 — RESOLVE NON-EXISTENT DISPUTE"
  set_validator_env
  out=$(inv_invoke -c '{"function":"ResolveDispute","Args":["proj_does_not_exist","inv_does_not_exist","REFUND"]}' 2>&1)
  echo "$out" | grep -qiE "not found|error|500" && pass "Resolving non-existent dispute correctly rejected" || { fail "Non-existent dispute resolution succeeded — unexpected"; echo " Output: $out"; }
}

test_project_nonexistent_startup() {
  section "TEST 7 — CREATE PROJECT FOR NON-EXISTENT STARTUP"
  set_startup_env
  out=$(gov_invoke -c '{"function":"CreateProject","Args":["proj_ghost","startup_ghost_xyz","Ghost Project","Ghost","100000","30","fintech","equity","India","SMEs","mvp"]}' 2>&1)
  echo "$out" | grep -qiE "not found|not approved|error|500" && pass "Project creation for non-existent startup correctly rejected" || { fail "Project was created for non-existent startup — VALIDATION BROKEN"; echo " Output: $out"; }
}

echo ""; echo "============================================"
echo " DUAL CHANNEL FAILURE & RECOVERY TEST SUITE"
echo " Gov: $GOV_CHANNEL | Inv: $INV_CHANNEL"
echo "============================================"
> "$RESULTS_FILE"; echo "status,test_name" >> "$RESULTS_FILE"
setup; sleep 2
test_fund_closed_project; sleep 2
test_double_release; sleep 2
test_refund_active_project; sleep 2
test_double_approve; sleep 2
test_query_nonexistent; sleep 2
test_resolve_nonexistent_dispute; sleep 2
test_project_nonexistent_startup
echo ""; echo "============================================"; echo " FAILURE & RECOVERY TEST SUMMARY"
echo "============================================"
echo " Total Tests : $TOTAL"; echo " Passed      : $PASS"; echo " Failed      : $FAIL"
echo " Pass Rate   : $(echo "scale=1; $PASS*100/$TOTAL" | bc)%"; echo "============================================"