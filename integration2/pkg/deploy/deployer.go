package deploy

import (
	"context"
	"fmt"
	"math/big"
	"os"
	"strings"
	"time"

	"github.com/NethermindEth/juno/core/felt"
	"github.com/NethermindEth/starknet.go/account"
	"github.com/NethermindEth/starknet.go/contracts"
	"github.com/NethermindEth/starknet.go/hash"
	"github.com/NethermindEth/starknet.go/rpc"
	"github.com/NethermindEth/starknet.go/utils"
	"github.com/sirupsen/logrus"
)

// Deployer handles contract deployment operations
type Deployer struct {
	account *account.Account
	client  *rpc.Provider
	network string
	logger  *logrus.Logger
}

// NewDeployer creates a new deployment instance
func NewDeployer(rpcURL, network string, accountAddress, privateKey, publicKey string, logger *logrus.Logger) (*Deployer, error) {
	// Initialize connection to RPC provider
	client, err := rpc.NewProvider(rpcURL)
	if err != nil {
		return nil, fmt.Errorf("error connecting to RPC provider: %w", err)
	}

	// Initialize the account memkeyStore
	ks := account.NewMemKeystore()
	privKeyBI, ok := new(big.Int).SetString(privateKey, 0)
	if !ok {
		return nil, fmt.Errorf("failed to convert private key to big.Int")
	}
	ks.Put(publicKey, privKeyBI)

	// Convert account address to felt
	accountAddressInFelt, err := utils.HexToFelt(accountAddress)
	if err != nil {
		return nil, fmt.Errorf("failed to transform account address: %w", err)
	}

	// Initialize the account (Cairo v2)
	accnt, err := account.NewAccount(client, accountAddressInFelt, publicKey, ks, account.CairoV2)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize account: %w", err)
	}

	return &Deployer{
		account: accnt,
		client:  client,
		network: network,
		logger:  logger,
	}, nil
}

// DeployContract deploys a contract with the given configuration
func (d *Deployer) DeployContract(contractInfo ContractInfo) (*DeploymentResult, error) {
	d.logger.Infof("🚀 Starting deployment of %s contract", contractInfo.Name)
	d.logger.Infof("📡 Network: %s", d.network)
	d.logger.Infof("📋 Account: %s", d.account.Address.String())

	// Step 1: Declare the contract
	d.logger.Info("📋 Step 1: Declaring contract...")
	classHash, err := d.declareContract(contractInfo.SierraPath, contractInfo.CasmPath)
	if err != nil {
		return nil, fmt.Errorf("contract declaration failed: %w", err)
	}
	d.logger.Infof("✅ Contract declaration completed! Class Hash: %s", classHash)

	// Wait before deployment
	d.logger.Info("⏳ Waiting before deployment...")
	time.Sleep(5 * time.Second)

	// Step 2: Deploy the contract
	d.logger.Info("📋 Step 2: Deploying contract...")
	deployedAddress, txHash, err := d.deployContract(classHash, contractInfo.Constructor.Args)
	if err != nil {
		return nil, fmt.Errorf("contract deployment failed: %w", err)
	}

	d.logger.Infof("✅ Contract deployed successfully!")
	d.logger.Infof("   Deployed Address: %s", deployedAddress)
	d.logger.Infof("   Transaction Hash: %s", txHash)

	return &DeploymentResult{
		ContractName:    contractInfo.Name,
		ClassHash:       classHash,
		DeployedAddress: deployedAddress,
		TransactionHash: txHash,
		DeploymentTime:  time.Now(),
		Network:         d.network,
	}, nil
}

// declareContract declares a contract on the network
func (d *Deployer) declareContract(sierraPath, casmPath string) (string, error) {
	d.logger.Debugf("📋 Loading contract files:")
	d.logger.Debugf("   Sierra: %s", sierraPath)
	d.logger.Debugf("   Casm: %s", casmPath)

	// Check if contract files exist (paths are relative to repo root)
	if _, err := os.Stat(sierraPath); os.IsNotExist(err) {
		return "", fmt.Errorf("sierra contract file not found: %s", sierraPath)
	}
	if _, err := os.Stat(casmPath); os.IsNotExist(err) {
		return "", fmt.Errorf("casm contract file not found: %s", casmPath)
	}

	// Unmarshalling the casm contract class from a JSON file
	casmClass, err := utils.UnmarshalJSONFileToType[contracts.CasmClass](casmPath, "")
	if err != nil {
		return "", fmt.Errorf("failed to parse casm contract: %w", err)
	}

	// Unmarshalling the sierra contract class from a JSON file
	contractClass, err := utils.UnmarshalJSONFileToType[contracts.ContractClass](sierraPath, "")
	if err != nil {
		return "", fmt.Errorf("failed to parse sierra contract: %w", err)
	}

	// Building and sending the declare transaction
	d.logger.Debug("📤 Declaring contract...")
	resp, err := d.account.BuildAndSendDeclareTxn(
		context.Background(),
		casmClass,
		contractClass,
		nil,
	)
	if err != nil {
		// Check if it's an "already declared" error
		if strings.Contains(err.Error(), "already declared") {
			d.logger.Info("✅ Contract already declared, extracting class hash...")
			// Use the proper ClassHash function from the hash package
			classHash := hash.ClassHash(contractClass)
			return classHash.String(), nil
		}
		return "", fmt.Errorf("failed to declare contract: %w", err)
	}

	// Wait for transaction receipt
	d.logger.Debug("⏳ Waiting for declaration confirmation...")
	_, err = d.account.WaitForTransactionReceipt(context.Background(), resp.Hash, time.Second)
	if err != nil {
		return "", fmt.Errorf("declare transaction failed: %w", err)
	}

	return resp.ClassHash.String(), nil
}

// deployContract deploys a contract with constructor arguments
func (d *Deployer) deployContract(classHash string, constructorArgs []*felt.Felt) (string, string, error) {
	// Convert class hash to felt
	classHashFelt, err := utils.HexToFelt(classHash)
	if err != nil {
		return "", "", fmt.Errorf("invalid class hash: %w", err)
	}

	d.logger.Debug("📤 Sending deployment transaction...")

	// Deploy the contract with UDC
	resp, salt, err := d.account.DeployContractWithUDC(context.Background(), classHashFelt, constructorArgs, nil, nil)
	if err != nil {
		return "", "", fmt.Errorf("failed to deploy contract: %w", err)
	}

	// Extract transaction hash from response
	txHash := resp.Hash
	d.logger.Debugf("⏳ Transaction sent! Hash: %s", txHash.String())
	d.logger.Debug("⏳ Waiting for transaction confirmation...")

	// Wait for transaction receipt
	txReceipt, err := d.account.WaitForTransactionReceipt(context.Background(), txHash, time.Second)
	if err != nil {
		return "", "", fmt.Errorf("failed to get transaction receipt: %w", err)
	}

	d.logger.Debugf("✅ Transaction confirmed!")
	d.logger.Debugf("   Execution Status: %s", txReceipt.ExecutionStatus)
	d.logger.Debugf("   Finality Status: %s", txReceipt.FinalityStatus)

	// Compute the deployed contract address
	deployedAddress := utils.PrecomputeAddressForUDC(classHashFelt, salt, constructorArgs, utils.UDCCairoV0, d.account.Address)

	return deployedAddress.String(), txHash.String(), nil
}

// GetAccountAddress returns the deployer account address
func (d *Deployer) GetAccountAddress() string {
	return d.account.Address.String()
}

// GetNetwork returns the network name
func (d *Deployer) GetNetwork() string {
	return d.network
}

