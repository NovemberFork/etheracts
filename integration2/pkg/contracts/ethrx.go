package contracts

import (
	"fmt"
	"math/big"

	"github.com/NethermindEth/juno/core/felt"
	"github.com/NethermindEth/starknet.go/utils"
	"github.com/sirupsen/logrus"

	"github.com/NovemberFork/etheracts/integration/pkg/config"
	"github.com/NovemberFork/etheracts/integration/pkg/deploy"
)

// EthrxDeployer handles Ethrx contract deployment
type EthrxDeployer struct {
	deployer *deploy.Deployer
	config   *config.EthrxConfig
	logger   *logrus.Logger
}

// NewEthrxDeployer creates a new Ethrx deployer
func NewEthrxDeployer(deployer *deploy.Deployer, config *config.EthrxConfig, logger *logrus.Logger) *EthrxDeployer {
	return &EthrxDeployer{
		deployer: deployer,
		config:   config,
		logger:   logger,
	}
}

// Deploy deploys the Ethrx contract
func (e *EthrxDeployer) Deploy() (*deploy.DeploymentResult, error) {
	e.logger.Info("🚀 Deploying Ethrx Contract")
	e.logger.Info("=====================================")

	// Build constructor arguments
	constructorArgs, err := e.buildConstructorArgs()
	if err != nil {
		return nil, fmt.Errorf("failed to build constructor arguments: %w", err)
	}

	// Create contract info
	contractInfo := deploy.ContractInfo{
		Name:       "Ethrx",
		SierraPath: e.config.SierraPath,
		CasmPath:   e.config.CasmPath,
		Constructor: deploy.ConstructorArgs{
			Args: constructorArgs,
		},
	}

	// Deploy the contract
	result, err := e.deployer.DeployContract(contractInfo)
	if err != nil {
		return nil, fmt.Errorf("deployment failed: %w", err)
	}

	e.logger.Info("🎉 Ethrx deployment completed successfully!")
	e.logger.Info("📋 Summary:")
	e.logger.Infof("   Class Hash: %s", result.ClassHash)
	e.logger.Infof("   Deployed Address: %s", result.DeployedAddress)
	e.logger.Infof("   Transaction Hash: %s", result.TransactionHash)
	e.logger.Infof("   Deployment Time: %s", result.DeploymentTime.Format("2006-01-02 15:04:05"))

	return result, nil
}

// GetContractName returns the contract name
func (e *EthrxDeployer) GetContractName() string {
	return "Ethrx"
}

// ValidateConfig validates the Ethrx configuration
func (e *EthrxDeployer) ValidateConfig() error {
	if e.config.Owner == "" {
		return fmt.Errorf("owner address is required")
	}
	if e.config.Name == "" {
		return fmt.Errorf("contract name is required")
	}
	if e.config.Symbol == "" {
		return fmt.Errorf("contract symbol is required")
	}
	if e.config.SierraPath == "" {
		return fmt.Errorf("sierra path is required")
	}
	if e.config.CasmPath == "" {
		return fmt.Errorf("casm path is required")
	}
	return nil
}

// buildConstructorArgs builds the constructor arguments for Ethrx contract
func (e *EthrxDeployer) buildConstructorArgs() ([]*felt.Felt, error) {
	e.logger.Debug("🔧 Building constructor arguments...")

	var calldata []*felt.Felt

	// Convert owner address
	owner, err := utils.HexToFelt(e.config.Owner)
	if err != nil {
		return nil, fmt.Errorf("invalid owner address: %w", err)
	}
	calldata = append(calldata, owner)

	// Convert name to ByteArray (Cairo ByteArray structure)
	nameFelts, err := stringToByteArray(e.config.Name)
	if err != nil {
		return nil, fmt.Errorf("invalid name: %w", err)
	}
	calldata = append(calldata, nameFelts...)

	// Convert symbol to ByteArray (Cairo ByteArray structure)
	symbolFelts, err := stringToByteArray(e.config.Symbol)
	if err != nil {
		return nil, fmt.Errorf("invalid symbol: %w", err)
	}
	calldata = append(calldata, symbolFelts...)

	// Convert base URI to ByteArray (Cairo ByteArray structure)
	baseURIFelts, err := stringToByteArray(e.config.BaseURI)
	if err != nil {
		return nil, fmt.Errorf("invalid base URI: %w", err)
	}
	calldata = append(calldata, baseURIFelts...)

	// Convert contract URI to ByteArray (Cairo ByteArray structure)
	contractURIFelts, err := stringToByteArray(e.config.ContractURI)
	if err != nil {
		return nil, fmt.Errorf("invalid contract URI: %w", err)
	}
	calldata = append(calldata, contractURIFelts...)

	// Convert mint token address
	mintToken, err := utils.HexToFelt(e.config.MintToken)
	if err != nil {
		return nil, fmt.Errorf("invalid mint token address: %w", err)
	}
	calldata = append(calldata, mintToken)

	// Convert mint price (u256) - split into low and high 128 bits
	mintPriceBig, ok := new(big.Int).SetString(e.config.MintPrice, 10)
	if !ok {
		return nil, fmt.Errorf("invalid mint price: %s", e.config.MintPrice)
	}
	mintPriceLow, mintPriceHigh := splitU256(mintPriceBig)
	calldata = append(calldata, mintPriceLow, mintPriceHigh)

	// Convert max supply (u256) - split into low and high 128 bits
	maxSupplyBig, ok := new(big.Int).SetString(e.config.MaxSupply, 10)
	if !ok {
		return nil, fmt.Errorf("invalid max supply: %s", e.config.MaxSupply)
	}
	maxSupplyLow, maxSupplyHigh := splitU256(maxSupplyBig)
	calldata = append(calldata, maxSupplyLow, maxSupplyHigh)

	e.logger.Debugf("✅ Constructor arguments built: %d arguments", len(calldata))
	e.logger.Debugf("   Owner: %s", e.config.Owner)
	e.logger.Debugf("   Name: %s", e.config.Name)
	e.logger.Debugf("   Symbol: %s", e.config.Symbol)
	e.logger.Debugf("   Base URI: %s", e.config.BaseURI)
	e.logger.Debugf("   Contract URI: %s", e.config.ContractURI)
	e.logger.Debugf("   Mint Token: %s", e.config.MintToken)
	e.logger.Debugf("   Mint Price: %s", e.config.MintPrice)
	e.logger.Debugf("   Max Supply: %s", e.config.MaxSupply)

	// Log the actual felt array for debugging
	e.logger.Debugf("🔍 Constructor calldata (felt array):")
	for i, felt := range calldata {
		e.logger.Debugf("   [%d]: %s", i, felt.String())
	}

	return calldata, nil
}

// splitU256 splits a u256 into low and high 128-bit parts
func splitU256(value *big.Int) (*felt.Felt, *felt.Felt) {
	// Create mask for low 128 bits (2^128 - 1)
	lowMask := new(big.Int)
	lowMask.Exp(big.NewInt(2), big.NewInt(128), nil)
	lowMask.Sub(lowMask, big.NewInt(1))

	// Extract low 128 bits
	low := new(big.Int).And(value, lowMask)

	// Extract high 128 bits by right-shifting by 128
	high := new(big.Int).Rsh(value, 128)

	return new(felt.Felt).SetBigInt(low), new(felt.Felt).SetBigInt(high)
}

// stringToByteArray converts a string to Cairo ByteArray structure
// Returns: [data_len, data_words..., pending_word, pending_word_len]
// Cairo ByteArray structure:
//   - data: Array<bytes31> (each bytes31 is 31 bytes, stored as felt252)
//   - pending_word: felt252 (last incomplete word, 0-31 bytes)
//   - pending_word_len: u32 (number of bytes in pending_word)
// When serialized for calldata, Array is: [length, element0, element1, ...]
func stringToByteArray(s string) ([]*felt.Felt, error) {
	if s == "" {
		// Empty ByteArray: data_len=0, pending_word=0, pending_word_len=0
		return []*felt.Felt{
			new(felt.Felt).SetUint64(0), // data_len
			new(felt.Felt).SetUint64(0), // pending_word
			new(felt.Felt).SetUint64(0), // pending_word_len
		}, nil
	}

	bytes := []byte(s)
	length := len(bytes)
	const wordSize = 31 // bytes31 is 31 bytes

	// Calculate number of full words and remaining bytes
	fullWords := length / wordSize
	remainingBytes := length % wordSize

	var result []*felt.Felt

	// Add data_len (number of full 31-byte words)
	result = append(result, new(felt.Felt).SetUint64(uint64(fullWords)))

	// Add full words (31 bytes each)
	for i := 0; i < fullWords; i++ {
		start := i * wordSize
		end := start + wordSize
		wordBytes := bytes[start:end]
		hexStr := fmt.Sprintf("0x%x", wordBytes)
		word, err := utils.HexToFelt(hexStr)
		if err != nil {
			return nil, fmt.Errorf("failed to convert word to felt: %w", err)
		}
		result = append(result, word)
	}

	// Add pending_word (last incomplete word, if any)
	var pendingWord *felt.Felt
	if remainingBytes > 0 {
		start := fullWords * wordSize
		pendingBytes := bytes[start:]
		hexStr := fmt.Sprintf("0x%x", pendingBytes)
		var err error
		pendingWord, err = utils.HexToFelt(hexStr)
		if err != nil {
			return nil, fmt.Errorf("failed to convert pending word to felt: %w", err)
		}
	} else {
		pendingWord = new(felt.Felt).SetUint64(0)
	}
	result = append(result, pendingWord)

	// Add pending_word_len
	result = append(result, new(felt.Felt).SetUint64(uint64(remainingBytes)))

	return result, nil
}
