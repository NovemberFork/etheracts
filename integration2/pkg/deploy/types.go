package deploy

import (
	"time"

	"github.com/NethermindEth/juno/core/felt"
)

// DeploymentResult contains the result of a contract deployment
type DeploymentResult struct {
	ContractName   string    `json:"contract_name"`
	ClassHash      string    `json:"class_hash"`
	DeployedAddress string   `json:"deployed_address"`
	TransactionHash string   `json:"transaction_hash"`
	DeploymentTime  time.Time `json:"deployment_time"`
	Network        string    `json:"network"`
}

// ContractDeployer defines the interface for contract deployment
type ContractDeployer interface {
	// Deploy deploys the contract and returns the deployment result
	Deploy() (*DeploymentResult, error)
	
	// GetContractName returns the name of the contract
	GetContractName() string
	
	// ValidateConfig validates the contract configuration
	ValidateConfig() error
}

// ConstructorArgs represents constructor arguments for a contract
type ConstructorArgs struct {
	Args []*felt.Felt `json:"args"`
}

// ContractInfo contains information about a contract
type ContractInfo struct {
	Name        string `json:"name"`
	SierraPath  string `json:"sierra_path"`
	CasmPath    string `json:"casm_path"`
	Constructor ConstructorArgs `json:"constructor"`
}

// DeploymentStatus represents the status of a deployment
type DeploymentStatus string

const (
	StatusPending    DeploymentStatus = "pending"
	StatusDeclaring  DeploymentStatus = "declaring"
	StatusDeploying  DeploymentStatus = "deploying"
	StatusCompleted  DeploymentStatus = "completed"
	StatusFailed     DeploymentStatus = "failed"
)

// DeploymentProgress contains progress information for a deployment
type DeploymentProgress struct {
	Status        DeploymentStatus `json:"status"`
	Message       string           `json:"message"`
	Progress      float64          `json:"progress"`
	CurrentStep   string           `json:"current_step"`
	TotalSteps    int              `json:"total_steps"`
	ElapsedTime   time.Duration    `json:"elapsed_time"`
	EstimatedTime time.Duration    `json:"estimated_time"`
}

