#!/bin/bash
# TEST 8: ReleaseFunds — Org4
# Sig: ReleaseFunds(projectID)
# Prereq: project.Status == "FUNDED"
echo "============================================"
echo "TEST 8: RELEASE FUNDS (ORG4 - PLATFORM/ADMIN)"
echo "============================================"
echo "ℹ Organization: Org4 | Channel: mychannel | Chaincode: crowdfund"
echo ""
export CORE_PEER_LOCALMSPID=Org4MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/org4.example.com/tlsca/tlsca.org4.example.com-cert.pem
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/org4.example.com/users/Admin@org4.example.com/msp
export CORE_PEER_ADDRESS=localhost:12051
total=20; success=0; failed=0; count=0; start=$(date +%s)
echo "Releasing Funds for 20 Projects (P100–P119)"
echo "============================================"
for ((i=100;i<120;i++)); do
    peer chaincode invoke \
      -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
      --cafile $PWD/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem \
      -C mychannel -n crowdfund \
      --peerAddresses localhost:7051 --tlsRootCertFiles $PWD/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem \
      --peerAddresses localhost:9051 --tlsRootCertFiles $PWD/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem \
      --peerAddresses localhost:11051 --tlsRootCertFiles $PWD/organizations/peerOrganizations/org3.example.com/tlsca/tlsca.org3.example.com-cert.pem \
      --peerAddresses localhost:12051 --tlsRootCertFiles $PWD/organizations/peerOrganizations/org4.example.com/tlsca/tlsca.org4.example.com-cert.pem \
      -c "{\"Args\":[\"ReleaseFunds\",\"P$i\"]}" 2>/dev/null
    if [ $? -eq 0 ]; then echo -n "✓"; success=$((success+1)); else echo -n "✗"; failed=$((failed+1)); fi
    count=$((count+1)); [ $((count%10)) -eq 0 ] && echo -n " [$count/$total]"
done
end=$(date +%s); elapsed=$((end-start))
[ $success -gt 0 ] && [ $elapsed -gt 0 ] && tps=$(echo "scale=2; $success/$elapsed" | bc) && latency=$(echo "scale=2; ($elapsed*1000)/$success" | bc) || { tps=0; latency=0; }
echo ""; echo ""
echo "============================================"
echo "TEST 8 RESULTS"
echo "============================================"
echo "📊 Funds Released: $success/$total"
echo "📊 Failed: $failed/$total"
echo "📊 Time Taken: ${elapsed}s"
echo "📊 TPS: $tps"
echo "📊 Avg Latency: ${latency}ms"
echo "📊 Success Rate: $(echo "scale=2; ($success/$total)*100" | bc)%"
if [ $failed -eq 0 ]; then echo "✓ ALL FUNDS RELEASED SUCCESSFULLY! 🎉"; echo "✓ FULL END-TO-END WORKFLOW COMPLETE! 🎉"
else echo "⚠ Some failed."; fi
RESULT_FILE="test8_release_funds_results_$(date +%Y%m%d_%H%M%S).txt"
{ echo "TEST 8: RELEASE FUNDS RESULTS"; echo "Timestamp: $(date)"; echo "Funds Released: $success/$total"; echo "Failed: $failed/$total"; echo "Time Taken: ${elapsed}s"; echo "TPS: $tps"; echo "Avg Latency: ${latency}ms"; echo "Success Rate: $(echo "scale=2; ($success/$total)*100" | bc)%"; } > "$RESULT_FILE"
echo "ℹ Results saved to: $RESULT_FILE"