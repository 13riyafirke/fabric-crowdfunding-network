#!/bin/bash
# TEST 5: CreateProject — Org1
# Sig: CreateProject(projectID,startupID,title,description,
#      goal[int64],duration[int],industry,projectType,
#      country,targetMarket,currentStage)
echo "============================================"
echo "TEST 5: CREATE PROJECT PERFORMANCE (ORG1)"
echo "============================================"
echo "ℹ Organization: Org1 | Channel: mychannel | Chaincode: crowdfund"
echo ""
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
total=20; success=0; failed=0; count=0; start=$(date +%s)
echo "Creating 20 Projects (P100–P119)"
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
      -c "{\"Args\":[\"CreateProject\",\"P$i\",\"S$i\",\"Project$i Title\",\"AI project $i description\",\"1000000\",\"90\",\"IT\",\"EQUITY\",\"India\",\"B2B\",\"MVP\"]}" 2>/dev/null
    if [ $? -eq 0 ]; then echo -n "✓"; success=$((success+1)); else echo -n "✗"; failed=$((failed+1)); fi
    count=$((count+1)); [ $((count%10)) -eq 0 ] && echo -n " [$count/$total]"
done
end=$(date +%s); elapsed=$((end-start))
[ $success -gt 0 ] && [ $elapsed -gt 0 ] && tps=$(echo "scale=2; $success/$elapsed" | bc) && latency=$(echo "scale=2; ($elapsed*1000)/$success" | bc) || { tps=0; latency=0; }
echo ""; echo ""
echo "============================================"
echo "TEST 5 RESULTS"
echo "============================================"
echo "📊 Projects Created: $success/$total"
echo "📊 Failed: $failed/$total"
echo "📊 Time Taken: ${elapsed}s"
echo "📊 TPS: $tps"
echo "📊 Avg Latency: ${latency}ms"
echo "📊 Success Rate: $(echo "scale=2; ($success/$total)*100" | bc)%"
if [ $failed -eq 0 ]; then echo "✓ ALL PROJECTS CREATED SUCCESSFULLY! 🎉"; echo "ℹ Run ./test_6_approve_project.sh next"
else echo "⚠ Some failed."; fi
RESULT_FILE="test5_create_project_results_$(date +%Y%m%d_%H%M%S).txt"
{ echo "TEST 5: CREATE PROJECT RESULTS"; echo "Timestamp: $(date)"; echo "Projects Created: $success/$total"; echo "Failed: $failed/$total"; echo "Time Taken: ${elapsed}s"; echo "TPS: $tps"; echo "Avg Latency: ${latency}ms"; echo "Success Rate: $(echo "scale=2; ($success/$total)*100" | bc)%"; } > "$RESULT_FILE"
echo "ℹ Results saved to: $RESULT_FILE"