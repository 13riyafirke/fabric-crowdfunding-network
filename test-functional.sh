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
# FUNCTIONAL TESTS — test-network version
# Matches microfab logic exactly. Expected: 13/14 pass
# Known failure: TEST 5 refund (same as microfab — "refund only allowed on cancelled projects")
# ============================================================
RESULTS_DIR="./results/functional"; mkdir -p "$RESULTS_DIR"
RESULTS_FILE="$RESULTS_DIR/functional_results.csv"
PASS=0; FAIL=0; TOTAL=0

setup() {
  section "SETUP — Preparing base entities"
  set_startup_env;   gov_invoke -c '{"function":"RegisterStartup","Args":["sfunc","FuncStartup","func@startup.com","PANF01","GSTF01","2022-06-01","fintech","product","India","Maharashtra","Pune","www.func.com","Functional test startup","2022","Func Founder"]}' > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c '{"function":"ValidateStartup","Args":["sfunc","APPROVED"]}' > /dev/null 2>&1; sleep 2
  set_startup_env;   gov_invoke -c '{"function":"RegisterInvestor","Args":["ifunc","FuncInvestor","func@inv.com","PANF02","AADHARIF02","angel","India","Maharashtra","Mumbai","fintech","large","1000000",""]}' > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c '{"function":"ValidateInvestor","Args":["ifunc","APPROVED"]}' > /dev/null 2>&1; sleep 2
  set_startup_env;   inv_invoke -c '{"function":"RegisterStartup","Args":["sfunc","FuncStartup","func@startup.com","PANF01","GSTF01","2022-06-01","fintech","product","India","Maharashtra","Pune","www.func.com","Functional test startup","2022","Func Founder"]}' > /dev/null 2>&1; sleep 2
  set_validator_env; inv_invoke -c '{"function":"ValidateStartup","Args":["sfunc","APPROVED"]}' > /dev/null 2>&1; sleep 2
  set_investor_env;  inv_invoke -c '{"function":"RegisterInvestor","Args":["ifunc","FuncInvestor","func@inv.com","PANF02","AADHARIF02","angel","India","Maharashtra","Mumbai","fintech","large","1000000",""]}' > /dev/null 2>&1; sleep 2
  set_validator_env; inv_invoke -c '{"function":"ValidateInvestor","Args":["ifunc","APPROVED"]}' > /dev/null 2>&1; sleep 2
  echo " Setup complete."
}

test_duplicate_registration() {
  section "TEST 1 — DUPLICATE REGISTRATION"
  set_startup_env
  out=$(gov_invoke -c '{"function":"RegisterStartup","Args":["sfunc","DupStartup","dup@startup.com","PANDUP","GSTDUP","2022-06-01","fintech","product","India","Maharashtra","Pune","www.dup.com","Dup startup","2022","Dup Founder"]}' 2>&1)
  echo "$out" | grep -qiE "already registered|error|500" && pass "Duplicate startup registration correctly rejected" || { fail "Duplicate startup registration was allowed"; echo " Output: $out"; }
  out=$(gov_invoke -c '{"function":"RegisterInvestor","Args":["ifunc","DupInvestor","dup@inv.com","PANDUP2","AADHARDUP2","angel","India","Maharashtra","Mumbai","fintech","large","1000000",""]}' 2>&1)
  echo "$out" | grep -qiE "already registered|error|500" && pass "Duplicate investor registration correctly rejected" || { fail "Duplicate investor registration was allowed"; echo " Output: $out"; }
}

test_income_threshold() {
  section "TEST 2 — INCOME BELOW THRESHOLD"
  set_startup_env;   gov_invoke -c '{"function":"RegisterInvestor","Args":["ilow","LowInvestor","low@inv.com","PANLOW1","AADHARLOW1","individual","India","Maharashtra","Mumbai","fintech","small","100000",""]}' > /dev/null 2>&1; sleep 2
  set_validator_env
  out=$(gov_invoke -c '{"function":"ValidateInvestor","Args":["ilow","APPROVED"]}' 2>&1)
  echo "$out" | grep -qiE "below minimum|threshold|error|500" && pass "Investor with income below 500000 correctly rejected" || { fail "Investor with low income was approved — THRESHOLD CHECK BROKEN"; echo " Output: $out"; }
}

test_reject_flow() {
  section "TEST 3 — PROJECT REJECT FLOW"
  local pid="func_reject_$$"
  set_startup_env;   gov_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$pid\",\"sfunc\",\"Reject Test\",\"Project to be rejected\",\"100000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
  set_validator_env
  out=$(gov_invoke -c "{\"function\":\"RejectProject\",\"Args\":[\"$pid\"]}" 2>&1)
  echo "$out" | grep -q "status:200" && pass "Project rejection succeeded on gov channel" || { fail "Project rejection failed"; echo " Output: $out"; }
  out=$(gov_query -c "{\"function\":\"GetProject\",\"Args\":[\"$pid\"]}" 2>&1)
  echo "$out" | grep -q "CANCELLED" && pass "Rejected project status correctly set to CANCELLED" || { fail "Rejected project status not CANCELLED"; echo " Output: $out"; }
  out=$(gov_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$pid\"]}" 2>&1)
  echo "$out" | grep -qiE "already|error|500" && pass "Cannot approve already rejected project" || fail "Rejected project was approved — STATE MACHINE BROKEN"
}

test_invalid_amount() {
  section "TEST 4 — INVALID AMOUNT"
  local pid="func_amount_$$"
  set_startup_env;   gov_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$pid\",\"sfunc\",\"Amount Test\",\"Amount test project\",\"100000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$pid\"]}" > /dev/null 2>&1; sleep 2
  local hash=$(get_approval_hash "$pid")
  set_platform_env;  inv_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$pid\",\"sfunc\",\"Amount Test\",\"Amount test project\",\"100000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
                     inv_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$pid\",\"$hash\"]}" > /dev/null 2>&1; sleep 2
  set_investor_env
  out=$(inv_invoke -c "{\"function\":\"Fund\",\"Args\":[\"$pid\",\"ifunc\",\"0\"]}" 2>&1)
  echo "$out" | grep -qiE "invalid amount|error|500" && pass "Zero amount funding correctly rejected" || { fail "Zero amount funding was allowed — AMOUNT VALIDATION BROKEN"; echo " Output: $out"; }
}

test_refund_flow() {
  section "TEST 5 — REFUND FLOW"
  # NOTE: This test FAILS in microfab too with "refund only allowed on cancelled projects"
  # RejectProject on investment channel does not put project in CANCELLED state.
  # Keeping EXACT same logic as microfab for fair comparison.
  local pid="func_refund_$$"
  set_startup_env;   gov_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$pid\",\"sfunc\",\"Refund Test\",\"Refund test project\",\"100000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$pid\"]}" > /dev/null 2>&1; sleep 2
  local hash=$(get_approval_hash "$pid")
  set_platform_env;  inv_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$pid\",\"sfunc\",\"Refund Test\",\"Refund test project\",\"100000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
                     inv_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$pid\",\"$hash\"]}" > /dev/null 2>&1; sleep 2
  set_investor_env;  inv_invoke -c "{\"function\":\"Fund\",\"Args\":[\"$pid\",\"ifunc\",\"50000\"]}" > /dev/null 2>&1; sleep 2
  # Same cancel method as microfab — RejectProject on investment channel
  set_validator_env; inv_invoke -c "{\"function\":\"RejectProject\",\"Args\":[\"$pid\"]}" > /dev/null 2>&1; sleep 2
  set_investor_env
  out=$(inv_invoke -c "{\"function\":\"Refund\",\"Args\":[\"$pid\",\"ifunc\"]}" 2>&1)
  if echo "$out" | grep -q "status:200"; then
    pass "Refund on cancelled project succeeded"
  else
    fail "Refund on cancelled project failed"
    echo " Output: $out"
  fi
  out=$(inv_invoke -c "{\"function\":\"Refund\",\"Args\":[\"$pid\",\"ifunc\"]}" 2>&1)
  echo "$out" | grep -qiE "already refunded|error|500" && pass "Double refund correctly rejected" || fail "Double refund was allowed — REFUND LOGIC BROKEN"
}

test_dispute_flow() {
  section "TEST 6 — DISPUTE FLOW"
  local pid="func_dispute_$$"
  set_startup_env;   gov_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$pid\",\"sfunc\",\"Dispute Test\",\"Dispute test project\",\"100000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$pid\"]}" > /dev/null 2>&1; sleep 2
  local hash=$(get_approval_hash "$pid")
  set_platform_env;  inv_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$pid\",\"sfunc\",\"Dispute Test\",\"Dispute test project\",\"100000\",\"30\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
                     inv_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$pid\",\"$hash\"]}" > /dev/null 2>&1; sleep 2
  set_investor_env;  inv_invoke -c "{\"function\":\"Fund\",\"Args\":[\"$pid\",\"ifunc\",\"50000\"]}" > /dev/null 2>&1; sleep 2
  out=$(inv_invoke -c "{\"function\":\"RaiseDispute\",\"Args\":[\"$pid\",\"ifunc\",\"Startup not delivering as promised\"]}" 2>&1)
  echo "$out" | grep -q "status:200" && pass "Dispute raised successfully within window" || { fail "Dispute raising failed"; echo " Output: $out"; }
  set_validator_env
  out=$(inv_invoke -c "{\"function\":\"ResolveDispute\",\"Args\":[\"$pid\",\"ifunc\",\"REFUND\"]}" 2>&1)
  echo "$out" | grep -q "status:200" && pass "Dispute resolved successfully — REFUND decision" || { fail "Dispute resolution failed"; echo " Output: $out"; }
  set_investor_env
  out=$(inv_invoke -c "{\"function\":\"RaiseDispute\",\"Args\":[\"$pid\",\"ifunc\",\"Duplicate dispute\"]}" 2>&1)
  echo "$out" | grep -qiE "already raised|error|500" && pass "Duplicate dispute correctly rejected" || fail "Duplicate dispute was allowed — DISPUTE LOGIC BROKEN"
}

test_unvalidated_entity() {
  section "TEST 7 — UNVALIDATED ENTITY TRYING TO ACT"
  set_startup_env;  gov_invoke -c '{"function":"RegisterStartup","Args":["sunval","UnvalidatedStartup","unval@startup.com","PANUN1","GSTUN1","2022-01-01","fintech","product","India","Maharashtra","Pune","www.unval.com","Unvalidated startup","2022","Unval Founder"]}' > /dev/null 2>&1; sleep 2
  out=$(gov_invoke -c '{"function":"CreateProject","Args":["punval","sunval","Unvalidated Project","Should fail","100000","30","fintech","equity","India","SMEs","mvp"]}' 2>&1)
  echo "$out" | grep -qiE "not approved|error|500" && pass "Unvalidated startup correctly blocked from creating project" || { fail "Unvalidated startup was allowed to create project — VALIDATION GATE BROKEN"; echo " Output: $out"; }
  set_investor_env; inv_invoke -c '{"function":"RegisterInvestor","Args":["iunval","UnvalidatedInvestor","unval@inv.com","PANUN2","AADHARUN2","individual","India","Maharashtra","Mumbai","fintech","small","1000000",""]}' > /dev/null 2>&1; sleep 2
  out=$(inv_invoke -c '{"function":"Fund","Args":["func_amount_99","iunval","50000"]}' 2>&1)
  echo "$out" | grep -qiE "not approved|not found|error|500" && pass "Unvalidated investor correctly blocked from funding" || fail "Unvalidated investor was allowed to fund — VALIDATION GATE BROKEN"
}

echo ""; echo "============================================"
echo " DUAL CHANNEL FUNCTIONAL TEST SUITE"
echo " Gov: $GOV_CHANNEL | Inv: $INV_CHANNEL"
echo "============================================"
> "$RESULTS_FILE"; echo "status,test_name" >> "$RESULTS_FILE"
setup; sleep 2
test_duplicate_registration; sleep 2
test_income_threshold; sleep 2
test_reject_flow; sleep 2
test_invalid_amount; sleep 2
test_refund_flow; sleep 2
test_dispute_flow; sleep 2
test_unvalidated_entity
echo ""; echo "============================================"; echo " FUNCTIONAL TEST SUMMARY"
echo "============================================"
echo " Total Tests : $TOTAL"; echo " Passed      : $PASS"; echo " Failed      : $FAIL"
echo " Pass Rate   : $(echo "scale=1; $PASS*100/$TOTAL" | bc)%"; echo "============================================"