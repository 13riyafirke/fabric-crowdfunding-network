// ============================================================
// HYPERLEDGER FABRIC GO CHAINCODE TEMPLATE
// ============================================================
// This is a fully-annotated, generalized chaincode template.
// The AI chatbot uses this as a base and customizes:
//   - Asset structs
//   - Transaction functions
//   - State machine transitions
//   - Access-control rules
//
// Supported patterns shown:
//   - Asset CRUD
//   - State machine
//   - Role-based access control (MSPID check)
//   - Rich queries (CouchDB)
//   - Event emission
//   - Transaction timestamp
// ============================================================

package main

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// ============================================================
// ASSET STRUCTS
// Define one struct per asset type in your domain.
// Use json tags for CouchDB serialization.
// Add a DocType field so CouchDB rich queries can filter by type.
// ============================================================

// Asset is the main data object stored on the ledger.
// Replace fields with your actual domain attributes.
type Asset struct {
	DocType   string `json:"docType"`  // always "asset" — used for CouchDB queries
	ID        string `json:"id"`
	Owner     string `json:"owner"`
	Value     string `json:"value"`
	Status    string `json:"status"`    // state machine field
	CreatedAt string `json:"createdAt"` // RFC3339 timestamp
	UpdatedAt string `json:"updatedAt"`
}

// StatusXxx constants for the state machine.
// Replace with your own workflow states.
const (
	StatusPending  = "PENDING"
	StatusApproved = "APPROVED"
	StatusRejected = "REJECTED"
	StatusActive   = "ACTIVE"
	StatusClosed   = "CLOSED"
)

// ============================================================
// SMART CONTRACT
// ============================================================

// SmartContract implements the Fabric chaincode interface.
type SmartContract struct {
	contractapi.Contract
}

// ============================================================
// INITIALIZATION
// Called once when chaincode is deployed (optional).
// ============================================================

// InitLedger seeds initial data. Called with --init-required flag.
// Remove this function if you don't need pre-seeded data.
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	assets := []Asset{
		{DocType: "asset", ID: "ASSET001", Owner: "Org1", Value: "initial", Status: StatusPending, CreatedAt: time.Now().Format(time.RFC3339)},
	}
	for _, asset := range assets {
		if err := s.putAsset(ctx, &asset); err != nil {
			return fmt.Errorf("InitLedger: failed to put asset %s: %w", asset.ID, err)
		}
	}
	return nil
}

// ============================================================
// CREATE / UPDATE OPERATIONS
// ============================================================

// CreateAsset stores a new asset on the ledger.
// ACCESS: Any org can create (remove the MSPID check if open).
func (s *SmartContract) CreateAsset(ctx contractapi.TransactionContextInterface, id string, owner string, value string) error {
	// Role-based access control: uncomment and adapt if only certain orgs can create
	// if err := s.requireMSP(ctx, "Org1MSP"); err != nil { return err }

	// Prevent duplicate IDs
	exists, err := s.assetExists(ctx, id)
	if err != nil {
		return err
	}
	if exists {
		return fmt.Errorf("asset %s already exists", id)
	}

	now := txTimestamp(ctx)
	asset := &Asset{
		DocType:   "asset",
		ID:        id,
		Owner:     owner,
		Value:     value,
		Status:    StatusPending,
		CreatedAt: now,
		UpdatedAt: now,
	}

	if err := s.putAsset(ctx, asset); err != nil {
		return err
	}

	// Emit an event so off-chain listeners (Node SDK, REST API) can react
	ctx.GetStub().SetEvent("AssetCreated", []byte(id))
	return nil
}

// UpdateAsset modifies the value of an existing asset.
// ACCESS: Only the current owner's org can update.
func (s *SmartContract) UpdateAsset(ctx contractapi.TransactionContextInterface, id string, newValue string) error {
	asset, err := s.getAsset(ctx, id)
	if err != nil {
		return err
	}

	// Enforce: only the org that owns the asset can update it
	if err := s.requireMSP(ctx, asset.Owner+"MSP"); err != nil {
		return fmt.Errorf("only the asset owner (%s) can update it: %w", asset.Owner, err)
	}

	asset.Value = newValue
	asset.UpdatedAt = txTimestamp(ctx)
	return s.putAsset(ctx, asset)
}

// ============================================================
// STATE MACHINE TRANSITIONS
// ============================================================

// ApproveAsset transitions an asset from PENDING to APPROVED.
// Replace "Org3MSP" with whichever org has approval authority.
func (s *SmartContract) ApproveAsset(ctx contractapi.TransactionContextInterface, id string, notes string) error {
	if err := s.requireMSP(ctx, "Org3MSP"); err != nil {
		return err
	}

	asset, err := s.getAsset(ctx, id)
	if err != nil {
		return err
	}

	if asset.Status != StatusPending {
		return fmt.Errorf("asset %s must be in PENDING state to approve; current: %s", id, asset.Status)
	}

	asset.Status = StatusApproved
	asset.Value = notes // store approval notes in value (adjust to a dedicated field)
	asset.UpdatedAt = txTimestamp(ctx)
	return s.putAsset(ctx, asset)
}

// RejectAsset transitions an asset from PENDING to REJECTED.
func (s *SmartContract) RejectAsset(ctx contractapi.TransactionContextInterface, id string, reason string) error {
	if err := s.requireMSP(ctx, "Org3MSP"); err != nil {
		return err
	}

	asset, err := s.getAsset(ctx, id)
	if err != nil {
		return err
	}

	if asset.Status != StatusPending {
		return fmt.Errorf("asset %s is not in PENDING state; current: %s", id, asset.Status)
	}

	asset.Status = StatusRejected
	asset.UpdatedAt = txTimestamp(ctx)
	return s.putAsset(ctx, asset)
}

// ActivateAsset transitions an asset from APPROVED to ACTIVE.
// E.g., a startup project moving from approved to actively fundraising.
func (s *SmartContract) ActivateAsset(ctx contractapi.TransactionContextInterface, id string) error {
	asset, err := s.getAsset(ctx, id)
	if err != nil {
		return err
	}

	if asset.Status != StatusApproved {
		return fmt.Errorf("asset %s must be APPROVED before it can be ACTIVE; current: %s", id, asset.Status)
	}

	asset.Status = StatusActive
	asset.UpdatedAt = txTimestamp(ctx)
	return s.putAsset(ctx, asset)
}

// CloseAsset terminates an active asset (e.g., funding round closed).
func (s *SmartContract) CloseAsset(ctx contractapi.TransactionContextInterface, id string) error {
	if err := s.requireMSP(ctx, "Org4MSP"); err != nil {
		return err
	}

	asset, err := s.getAsset(ctx, id)
	if err != nil {
		return err
	}

	if asset.Status != StatusActive {
		return fmt.Errorf("asset %s must be ACTIVE to close; current: %s", id, asset.Status)
	}

	asset.Status = StatusClosed
	asset.UpdatedAt = txTimestamp(ctx)
	return s.putAsset(ctx, asset)
}

// ============================================================
// QUERY OPERATIONS (read-only, no state change)
// ============================================================

// GetAsset returns a single asset by ID.
func (s *SmartContract) GetAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
	return s.getAsset(ctx, id)
}

// GetAssetHistory returns all historical versions of an asset.
func (s *SmartContract) GetAssetHistory(ctx contractapi.TransactionContextInterface, id string) ([]map[string]interface{}, error) {
	iter, err := ctx.GetStub().GetHistoryForKey(id)
	if err != nil {
		return nil, fmt.Errorf("GetHistoryForKey failed for %s: %w", id, err)
	}
	defer iter.Close()

	var history []map[string]interface{}
	for iter.HasNext() {
		result, err := iter.Next()
		if err != nil {
			return nil, err
		}
		var asset Asset
		entry := map[string]interface{}{
			"txID":      result.TxId,
			"timestamp": result.Timestamp,
			"isDeleted": result.IsDelete,
		}
		if !result.IsDelete {
			if err := json.Unmarshal(result.Value, &asset); err == nil {
				entry["value"] = asset
			}
		}
		history = append(history, entry)
	}
	return history, nil
}

// QueryAssetsByStatus returns all assets with a given status (requires CouchDB).
// Example query: '{"Args":["QueryAssetsByStatus","APPROVED"]}'
func (s *SmartContract) QueryAssetsByStatus(ctx contractapi.TransactionContextInterface, status string) ([]*Asset, error) {
	query := fmt.Sprintf(`{"selector":{"docType":"asset","status":"%s"}}`, status)
	return s.runRichQuery(ctx, query)
}

// QueryAssetsByOwner returns all assets owned by a specific org.
func (s *SmartContract) QueryAssetsByOwner(ctx contractapi.TransactionContextInterface, owner string) ([]*Asset, error) {
	query := fmt.Sprintf(`{"selector":{"docType":"asset","owner":"%s"}}`, owner)
	return s.runRichQuery(ctx, query)
}

// GetAllAssets returns every asset on the channel ledger.
// WARNING: expensive on large datasets; use pagination in production.
func (s *SmartContract) GetAllAssets(ctx contractapi.TransactionContextInterface) ([]*Asset, error) {
	query := `{"selector":{"docType":"asset"}}`
	return s.runRichQuery(ctx, query)
}

// ============================================================
// INTERNAL HELPER FUNCTIONS
// ============================================================

func (s *SmartContract) getAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
	data, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("GetState failed for %s: %w", id, err)
	}
	if data == nil {
		return nil, fmt.Errorf("asset %s does not exist", id)
	}
	var asset Asset
	if err := json.Unmarshal(data, &asset); err != nil {
		return nil, fmt.Errorf("failed to unmarshal asset %s: %w", id, err)
	}
	return &asset, nil
}

func (s *SmartContract) putAsset(ctx contractapi.TransactionContextInterface, asset *Asset) error {
	data, err := json.Marshal(asset)
	if err != nil {
		return fmt.Errorf("failed to marshal asset %s: %w", asset.ID, err)
	}
	return ctx.GetStub().PutState(asset.ID, data)
}

func (s *SmartContract) assetExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	data, err := ctx.GetStub().GetState(id)
	if err != nil {
		return false, fmt.Errorf("GetState failed for %s: %w", id, err)
	}
	return data != nil, nil
}

// requireMSP returns an error if the calling client is not from the expected MSP.
func (s *SmartContract) requireMSP(ctx contractapi.TransactionContextInterface, expectedMSP string) error {
	clientMSP, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return fmt.Errorf("failed to get client MSPID: %w", err)
	}
	if clientMSP != expectedMSP {
		return fmt.Errorf("access denied: expected %s, got %s", expectedMSP, clientMSP)
	}
	return nil
}

// txTimestamp returns the transaction timestamp as an RFC3339 string.
func txTimestamp(ctx contractapi.TransactionContextInterface) string {
	ts, err := ctx.GetStub().GetTxTimestamp()
	if err != nil || ts == nil {
		return time.Now().Format(time.RFC3339)
	}
	return time.Unix(ts.Seconds, int64(ts.Nanos)).Format(time.RFC3339)
}

// runRichQuery executes a CouchDB selector query and returns matching assets.
func (s *SmartContract) runRichQuery(ctx contractapi.TransactionContextInterface, query string) ([]*Asset, error) {
	iter, err := ctx.GetStub().GetQueryResult(query)
	if err != nil {
		return nil, fmt.Errorf("GetQueryResult failed: %w", err)
	}
	defer iter.Close()

	var assets []*Asset
	for iter.HasNext() {
		result, err := iter.Next()
		if err != nil {
			return nil, err
		}
		var asset Asset
		if err := json.Unmarshal(result.Value, &asset); err != nil {
			return nil, fmt.Errorf("failed to unmarshal query result: %w", err)
		}
		assets = append(assets, &asset)
	}
	return assets, nil
}

// ============================================================
// MAIN ENTRY POINT
// ============================================================

func main() {
	chaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		log.Panicf("Error creating chaincode: %v", err)
	}
	if err := chaincode.Start(); err != nil {
		log.Panicf("Error starting chaincode: %v", err)
	}
}
