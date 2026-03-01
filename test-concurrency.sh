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
# CONCURRENCY TESTS — test-network version
# Matches microfab logic EXACTLY. Expected: 3/3 pass
# microfab results: 10/10, 5/5, 5/5 all succeeded (single-node, no MVCC)
# test-network may have some MVCC conflicts (multi-node ordering)
# Thresholds kept same as microfab: ≥80% for creation, ≥1 for funding, ≥80% for validation
# ============================================================
RESULTS_DIR="./results/concurrency"; mkdir -p "$RESULTS_DIR"
RESULTS_FILE="$RESULTS_DIR/concurrency_results.csv"
PASS=0; FAIL=0; TOTAL=0

setup() {
  section "SETUP — Preparing entities"
  set_startup_env;   gov_invoke -c '{"function":"RegisterStartup","Args":["sconc","ConcStartup","conc@startup.com","PANC01","GSTC01","2022-01-01","fintech","product","India","Maharashtra","Pune","www.conc.com","Concurrency test startup","2022","Conc Founder"]}' > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c '{"function":"ValidateStartup","Args":["sconc","APPROVED"]}' > /dev/null 2>&1; sleep 2
  set_startup_env;   gov_invoke -c '{"function":"RegisterInvestor","Args":["iconc","ConcInvestor","conc@inv.com","PANC02","AADHARC02","angel","India","Maharashtra","Mumbai","fintech","large","1000000",""]}' > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c '{"function":"ValidateInvestor","Args":["iconc","APPROVED"]}' > /dev/null 2>&1; sleep 2
  set_startup_env;   inv_invoke -c '{"function":"RegisterStartup","Args":["sconc","ConcStartup","conc@startup.com","PANC01","GSTC01","2022-01-01","fintech","product","India","Maharashtra","Pune","www.conc.com","Concurrency test startup","2022","Conc Founder"]}' > /dev/null 2>&1; sleep 2
  set_validator_env; inv_invoke -c '{"function":"ValidateStartup","Args":["sconc","APPROVED"]}' > /dev/null 2>&1; sleep 2
  set_investor_env;  inv_invoke -c '{"function":"RegisterInvestor","Args":["iconc","ConcInvestor","conc@inv.com","PANC02","AADHARC02","angel","India","Maharashtra","Mumbai","fintech","large","1000000",""]}' > /dev/null 2>&1; sleep 2
  set_validator_env; inv_invoke -c '{"function":"ValidateInvestor","Args":["iconc","APPROVED"]}' > /dev/null 2>&1; sleep 2
  echo " Setup complete."
}

test_concurrent_project_creation() {
  local N=${1:-10}
  section "TEST 1 — CONCURRENT PROJECT CREATION ($N parallel)"
  local tmp_dir=$(mktemp -d)
  local start=$(date +%s%N)

  for i in $(seq 1 $N); do
    local pid="conc_proj_${i}_$$"
    (
      export CORE_PEER_TLS_ENABLED=true
      export CORE_PEER_LOCALMSPID=Org1MSP
      export CORE_PEER_TLS_ROOTCERT_FILE=$ORG1_TLS
      export CORE_PEER_MSPCONFIGPATH=$BASE/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
      export CORE_PEER_ADDRESS=localhost:7051
      out=$(peer chaincode invoke $ORDERER_FLAGS -C "$GOV_CHANNEL" -n "$GOV_CHAINCODE" \
        --peerAddresses localhost:7051  --tlsRootCertFiles $ORG1_TLS \
        --peerAddresses localhost:11051 --tlsRootCertFiles $ORG3_TLS \
        --peerAddresses localhost:12051 --tlsRootCertFiles $ORG4_TLS \
        -c "{\"function\":\"CreateProject\",\"Args\":[\"$pid\",\"sconc\",\"Conc Project $i\",\"Concurrent test\",\"500000\",\"60\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" 2>&1)
      if echo "$out" | grep -q "status:200"; then
        echo "SUCCESS" > "$tmp_dir/result_$i"
      else
        echo "FAIL" > "$tmp_dir/result_$i"
      fi
    ) &
  done
  wait

  local end=$(date +%s%N)
  local total_ms=$(( (end - start) / 1000000 ))
  local success=0
  for i in $(seq 1 $N); do
    result=$(cat "$tmp_dir/result_$i" 2>/dev/null || echo "FAIL")
    [ "$result" == "SUCCESS" ] && success=$((success + 1))
  done
  rm -rf "$tmp_dir"

  echo " Concurrent Results: $success/$N succeeded in ${total_ms}ms"
  echo "concurrent_creation,$success,$N,$total_ms" >> "$RESULTS_FILE"

  if [ $success -ge $(($N * 8 / 10)) ]; then
    pass "Concurrent project creation — $success/$N succeeded (≥80% threshold)"
  else
    fail "Concurrent project creation — too many failures: $success/$N"
  fi
}

test_concurrent_funding() {
  local N=${1:-5}
  section "TEST 2 — CONCURRENT FUNDING ($N parallel investors)"

  local pid="conc_fund_$$"
  set_startup_env;   gov_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$pid\",\"sconc\",\"Fund Conc Test\",\"Concurrent funding\",\"1000000\",\"60\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
  set_validator_env; gov_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$pid\"]}" > /dev/null 2>&1; sleep 2
  local hash=$(get_approval_hash "$pid")
  set_platform_env;  inv_invoke -c "{\"function\":\"CreateProject\",\"Args\":[\"$pid\",\"sconc\",\"Fund Conc Test\",\"Concurrent funding\",\"1000000\",\"60\",\"fintech\",\"equity\",\"India\",\"SMEs\",\"mvp\"]}" > /dev/null 2>&1; sleep 2
                     inv_invoke -c "{\"function\":\"ApproveProject\",\"Args\":[\"$pid\",\"$hash\"]}" > /dev/null 2>&1; sleep 2

  local tmp_dir=$(mktemp -d)
  local start=$(date +%s%N)

  for i in $(seq 1 $N); do
    (
      export CORE_PEER_TLS_ENABLED=true
      export CORE_PEER_LOCALMSPID=Org2MSP
      export CORE_PEER_TLS_ROOTCERT_FILE=$ORG2_TLS
      export CORE_PEER_MSPCONFIGPATH=$BASE/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
      export CORE_PEER_ADDRESS=localhost:9051
      out=$(peer chaincode invoke $ORDERER_FLAGS -C "$INV_CHANNEL" -n "$INV_CHAINCODE" \
        --peerAddresses localhost:7051  --tlsRootCertFiles $ORG1_TLS \
        --peerAddresses localhost:9051  --tlsRootCertFiles $ORG2_TLS \
        --peerAddresses localhost:11051 --tlsRootCertFiles $ORG3_TLS \
        --peerAddresses localhost:12051 --tlsRootCertFiles $ORG4_TLS \
        -c "{\"function\":\"Fund\",\"Args\":[\"$pid\",\"iconc\",\"50000\"]}" 2>&1)
      if echo "$out" | grep -q "status:200"; then
        echo "SUCCESS" > "$tmp_dir/fund_$i"
      else
        echo "FAIL" > "$tmp_dir/fund_$i"
      fi
    ) &
  done
  wait

  local end=$(date +%s%N)
  local total_ms=$(( (end - start) / 1000000 ))
  local success=0
  for i in $(seq 1 $N); do
    result=$(cat "$tmp_dir/fund_$i" 2>/dev/null || echo "FAIL")
    [ "$result" == "SUCCESS" ] && success=$((success + 1))
  done
  rm -rf "$tmp_dir"

  echo " Concurrent Funding Results: $success/$N succeeded in ${total_ms}ms"
  echo "concurrent_funding,$success,$N,$total_ms" >> "$RESULTS_FILE"

  if [ $success -ge 1 ]; then
    pass "Concurrent funding handled — $success/$N succeeded (MVCC conflicts expected)"
    echo " ℹ️  MVCC conflicts on same key are expected behaviour in Fabric"
  else
    fail "All concurrent fund attempts failed — unexpected"
  fi
}

test_concurrent_validation() {
  local N=${1:-5}
  section "TEST 3 — CONCURRENT VALIDATION REQUESTS ($N parallel)"
  local tmp_dir=$(mktemp -d)

  # Register N startups sequentially first
  for i in $(seq 1 $N); do
    local sid="conc_val_s${i}_$$"
    set_startup_env
    gov_invoke -c "{\"function\":\"RegisterStartup\",\"Args\":[\"$sid\",\"ConcValStartup$i\",\"val$i@test.com\",\"PANCV$i\",\"GSTCV$i\",\"2022-01-01\",\"fintech\",\"product\",\"India\",\"Maharashtra\",\"Pune\",\"www.cv$i.com\",\"Test\",\"2022\",\"Founder$i\"]}" > /dev/null 2>&1
  done
  sleep 3

  local start=$(date +%s%N)

  for i in $(seq 1 $N); do
    local sid="conc_val_s${i}_$$"
    (
      export CORE_PEER_TLS_ENABLED=true
      export CORE_PEER_LOCALMSPID=Org3MSP
      export CORE_PEER_TLS_ROOTCERT_FILE=$ORG3_TLS
      export CORE_PEER_MSPCONFIGPATH=$BASE/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
      export CORE_PEER_ADDRESS=localhost:11051
      out=$(peer chaincode invoke $ORDERER_FLAGS -C "$GOV_CHANNEL" -n "$GOV_CHAINCODE" \
        --peerAddresses localhost:7051  --tlsRootCertFiles $ORG1_TLS \
        --peerAddresses localhost:11051 --tlsRootCertFiles $ORG3_TLS \
        --peerAddresses localhost:12051 --tlsRootCertFiles $ORG4_TLS \
        -c "{\"function\":\"ValidateStartup\",\"Args\":[\"$sid\",\"APPROVED\"]}" 2>&1)
      if echo "$out" | grep -q "status:200"; then
        echo "SUCCESS" > "$tmp_dir/val_$i"
      else
        echo "FAIL:$out" > "$tmp_dir/val_$i"
      fi
    ) &
  done
  wait

  local end=$(date +%s%N)
  local total_ms=$(( (end - start) / 1000000 ))
  local success=0
  for i in $(seq 1 $N); do
    result=$(cat "$tmp_dir/val_$i" 2>/dev/null || echo "FAIL")
    echo "$result" | grep -q "SUCCESS" && success=$((success + 1))
  done
  rm -rf "$tmp_dir"

  echo " Concurrent Validation Results: $success/$N succeeded in ${total_ms}ms"
  echo "concurrent_validation,$success,$N,$total_ms" >> "$RESULTS_FILE"

  if [ $success -eq $N ]; then
    pass "All concurrent validations succeeded — $success/$N"
  elif [ $success -ge $(($N * 8 / 10)) ]; then
    pass "Most concurrent validations succeeded — $success/$N (≥80%)"
  else
    fail "Too many concurrent validation failures — $success/$N"
  fi
}

echo ""; echo "============================================"
echo " DUAL CHANNEL CONCURRENCY TEST SUITE"
echo " Gov: $GOV_CHANNEL | Inv: $INV_CHANNEL"
echo "============================================"
> "$RESULTS_FILE"; echo "status,test_name" >> "$RESULTS_FILE"
setup; sleep 2
test_concurrent_project_creation 10; sleep 2
test_concurrent_funding 5; sleep 2
test_concurrent_validation 5
echo ""; echo "============================================"; echo " CONCURRENCY TEST SUMMARY"
echo "============================================"
echo " Total Tests : $TOTAL"; echo " Passed      : $PASS"; echo " Failed      : $FAIL"
echo " Pass Rate   : $(echo "scale=1; $PASS*100/$TOTAL" | bc)%"; echo "============================================"
echo ""
echo " ℹ️  Note: MVCC conflicts in concurrent writes to same key"
echo " are EXPECTED in Hyperledger Fabric and not a bug."
echo " Fabric uses optimistic concurrency — last write wins."
echo "============================================"
