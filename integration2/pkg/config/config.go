package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
	"github.com/sirupsen/logrus"
)

// Config holds all deployment configuration
type Config struct {
	Network    NetworkConfig    `json:"network"`
	Deployer   DeployerConfig   `json:"deployer"`
	Contracts  ContractsConfig  `json:"contracts"`
	Deployment DeploymentConfig `json:"deployment"`
	Logging    LoggingConfig    `json:"logging"`
}

// NetworkConfig holds network-specific configuration
type NetworkConfig struct {
	Name    string `json:"name"`
	RPCURL  string `json:"rpc_url"`
	ChainID string `json:"chain_id"`
}

// DeployerConfig holds deployer account configuration
type DeployerConfig struct {
	Address    string `json:"address"`
	PrivateKey string `json:"private_key"`
	PublicKey  string `json:"public_key"`
}

// ContractsConfig holds contract-specific configuration
type ContractsConfig struct {
	Ethrx EthrxConfig `json:"ethrx"`
}

// EthrxConfig holds Ethrx contract configuration
type EthrxConfig struct {
	Owner       string `json:"owner"`
	Name        string `json:"name"`
	Symbol      string `json:"symbol"`
	BaseURI     string `json:"base_uri"`
	ContractURI string `json:"contract_uri"`
	MintToken   string `json:"mint_token"`
	MintPrice   string `json:"mint_price"`
	MaxSupply   string `json:"max_supply"`

	// Contract file paths
	SierraPath string `json:"sierra_path"`
	CasmPath   string `json:"casm_path"`
}

// DeploymentConfig holds deployment options
type DeploymentConfig struct {
	DeclarationDelay time.Duration `json:"declaration_delay"`
	MaxFee           string        `json:"max_fee"`
	GasPrice         string        `json:"gas_price"`
}

// LoggingConfig holds logging configuration
type LoggingConfig struct {
	Level   string `json:"level"`
	Verbose bool   `json:"verbose"`
}

// LoadConfig loads configuration from environment variables
func LoadConfig() (*Config, error) {
	// Try to load .env file from multiple locations
	envFiles := []string{
		".env",       // Current directory
		"../.env",    // Parent directory (when running from integration/)
		"../../.env", // Two levels up (fallback)
	}

	var loaded bool
	for _, envFile := range envFiles {
		if err := godotenv.Load(envFile); err == nil {
			logrus.Debugf("Loaded .env from: %s", envFile)
			loaded = true
			break
		}
	}

	if !loaded {
		logrus.Warn("No .env file found, using environment variables")
	}

	config := &Config{}

	// Load network configuration
	network, err := loadNetworkConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load network config: %w", err)
	}
	config.Network = *network

	// Load deployer configuration
	deployer, err := loadDeployerConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load deployer config: %w", err)
	}
	config.Deployer = *deployer

	// Load contracts configuration
	contracts, err := loadContractsConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load contracts config: %w", err)
	}
	config.Contracts = *contracts

	// Load deployment configuration
	deployment, err := loadDeploymentConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load deployment config: %w", err)
	}
	config.Deployment = *deployment

	// Load logging configuration
	logging, err := loadLoggingConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load logging config: %w", err)
	}
	config.Logging = *logging

	return config, nil
}

func loadNetworkConfig() (*NetworkConfig, error) {
	network := os.Getenv("NETWORK")
	if network == "" {
		network = "local"
	}

	var rpcURL string
	switch network {
	case "local":
		rpcURL = getEnvOrDefault("LOCAL_RPC_URL", "http://localhost:5050/rpc")
	case "testnet":
		rpcURL = os.Getenv("TESTNET_RPC_URL")
		if rpcURL == "" {
			return nil, fmt.Errorf("TESTNET_RPC_URL is required for testnet deployment")
		}
	case "mainnet":
		rpcURL = os.Getenv("MAINNET_RPC_URL")
		if rpcURL == "" {
			return nil, fmt.Errorf("MAINNET_RPC_URL is required for mainnet deployment")
		}
	default:
		return nil, fmt.Errorf("unsupported network: %s", network)
	}

	return &NetworkConfig{
		Name:    network,
		RPCURL:  rpcURL,
		ChainID: getChainID(network),
	}, nil
}

func loadDeployerConfig() (*DeployerConfig, error) {
	network := os.Getenv("NETWORK")
	if network == "" {
		network = "local"
	}

	var address, privateKey, publicKey string
	switch network {
	case "local":
		address = os.Getenv("LOCAL_DEPLOYER_ADDRESS")
		privateKey = os.Getenv("LOCAL_DEPLOYER_PRIVATE_KEY")
		publicKey = os.Getenv("LOCAL_DEPLOYER_PUBLIC_KEY")
	case "testnet":
		address = os.Getenv("TESTNET_DEPLOYER_ADDRESS")
		privateKey = os.Getenv("TESTNET_DEPLOYER_PRIVATE_KEY")
		publicKey = os.Getenv("TESTNET_DEPLOYER_PUBLIC_KEY")
	case "mainnet":
		address = os.Getenv("MAINNET_DEPLOYER_ADDRESS")
		privateKey = os.Getenv("MAINNET_DEPLOYER_PRIVATE_KEY")
		publicKey = os.Getenv("MAINNET_DEPLOYER_PUBLIC_KEY")
	default:
		return nil, fmt.Errorf("unsupported network: %s", network)
	}

	if address == "" || privateKey == "" || publicKey == "" {
		return nil, fmt.Errorf("missing required deployer environment variables for %s: %s_DEPLOYER_ADDRESS, %s_DEPLOYER_PRIVATE_KEY, %s_DEPLOYER_PUBLIC_KEY",
			strings.ToUpper(network), strings.ToUpper(network), strings.ToUpper(network), strings.ToUpper(network))
	}

	return &DeployerConfig{
		Address:    address,
		PrivateKey: privateKey,
		PublicKey:  publicKey,
	}, nil
}

func loadContractsConfig() (*ContractsConfig, error) {
	ethrx, err := loadEthrxConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load ethrx config: %w", err)
	}

	return &ContractsConfig{
		Ethrx: *ethrx,
	}, nil
}

func loadEthrxConfig() (*EthrxConfig, error) {
	network := os.Getenv("NETWORK")
	if network == "" {
		network = "local"
	}

	var owner, mintToken, mintPrice, maxSupply string
	switch network {
	case "local":
		owner = os.Getenv("LOCAL_ETHRX_OWNER")
		mintToken = os.Getenv("LOCAL_ETHRX_MINT_TOKEN")
		mintPrice = os.Getenv("LOCAL_ETHRX_MINT_PRICE")
		maxSupply = os.Getenv("LOCAL_ETHRX_MAX_SUPPLY")
	case "testnet":
		owner = os.Getenv("TESTNET_ETHRX_OWNER")
		mintToken = os.Getenv("TESTNET_ETHRX_MINT_TOKEN")
		mintPrice = os.Getenv("TESTNET_ETHRX_MINT_PRICE")
		maxSupply = os.Getenv("TESTNET_ETHRX_MAX_SUPPLY")
	case "mainnet":
		owner = os.Getenv("MAINNET_ETHRX_OWNER")
		mintToken = os.Getenv("MAINNET_ETHRX_MINT_TOKEN")
		mintPrice = os.Getenv("MAINNET_ETHRX_MINT_PRICE")
		maxSupply = os.Getenv("MAINNET_ETHRX_MAX_SUPPLY")
	default:
		return nil, fmt.Errorf("unsupported network: %s", network)
	}

	if owner == "" {
		return nil, fmt.Errorf("%s_ETHRX_OWNER is required", strings.ToUpper(network))
	}
	if mintToken == "" {
		return nil, fmt.Errorf("%s_ETHRX_MINT_TOKEN is required", strings.ToUpper(network))
	}
	if mintPrice == "" {
		return nil, fmt.Errorf("%s_ETHRX_MINT_PRICE is required", strings.ToUpper(network))
	}
	if maxSupply == "" {
		return nil, fmt.Errorf("%s_ETHRX_MAX_SUPPLY is required", strings.ToUpper(network))
	}

	name := getEnvOrDefault("ETHRX_NAME", "Etheracts")
	symbol := getEnvOrDefault("ETHRX_SYMBOL", "Ethrx")
	baseURI := getEnvOrDefault("ETHRX_BASE_URI", "http://novemberfork.io/etheracts/URI/")
	contractURI := getEnvOrDefault("ETHRX_CONTRACT_URI", "https://novemberfork.io/etheracts/URI/contract")

	sierraPath := getEnvOrDefault("ETHRX_SIERRA_PATH", "../target/dev/etheracts_Ethrx.contract_class.json")
	casmPath := getEnvOrDefault("ETHRX_CASM_PATH", "../target/dev/etheracts_Ethrx.compiled_contract_class.json")

	return &EthrxConfig{
		Owner:       owner,
		Name:        name,
		Symbol:      symbol,
		BaseURI:     baseURI,
		ContractURI: contractURI,
		MintToken:   mintToken,
		MintPrice:   mintPrice,
		MaxSupply:   maxSupply,
		SierraPath:  sierraPath,
		CasmPath:    casmPath,
	}, nil
}

func loadDeploymentConfig() (*DeploymentConfig, error) {
	network := os.Getenv("NETWORK")
	if network == "" {
		network = "local"
	}

	var delayStr string
	switch network {
	case "local":
		delayStr = getEnvOrDefault("LOCAL_DECLARATION_DELAY", "5")
	case "testnet":
		delayStr = getEnvOrDefault("TESTNET_DECLARATION_DELAY", "5")
	case "mainnet":
		delayStr = getEnvOrDefault("MAINNET_DECLARATION_DELAY", "5")
	default:
		delayStr = "5"
	}

	delay, err := strconv.Atoi(delayStr)
	if err != nil {
		return nil, fmt.Errorf("invalid %s_DECLARATION_DELAY: %w", strings.ToUpper(network), err)
	}

	return &DeploymentConfig{
		DeclarationDelay: time.Duration(delay) * time.Second,
		MaxFee:           getEnvOrDefault("MAX_FEE", "1000000000000000"),
		GasPrice:         getEnvOrDefault("GAS_PRICE", "1000000000"),
	}, nil
}

func loadLoggingConfig() (*LoggingConfig, error) {
	level := getEnvOrDefault("LOG_LEVEL", "info")
	verboseStr := getEnvOrDefault("VERBOSE", "false")
	verbose, err := strconv.ParseBool(verboseStr)
	if err != nil {
		return nil, fmt.Errorf("invalid VERBOSE value: %w", err)
	}

	return &LoggingConfig{
		Level:   level,
		Verbose: verbose,
	}, nil
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getChainID(network string) string {
	switch network {
	case "local":
		return "0x534e5f4d41494e" // SN_MAIN
	case "testnet":
		return "0x534e5f474f45524c49" // SN_GOERLI
	case "mainnet":
		return "0x534e5f4d41494e" // SN_MAIN
	default:
		return "0x534e5f4d41494e"
	}
}

// ValidateConfig validates the configuration
func (c *Config) ValidateConfig() error {
	// Validate network configuration
	if c.Network.RPCURL == "" {
		return fmt.Errorf("network RPC URL is required")
	}

	// Validate deployer configuration
	if c.Deployer.Address == "" || c.Deployer.PrivateKey == "" || c.Deployer.PublicKey == "" {
		return fmt.Errorf("deployer configuration is incomplete")
	}

	// Validate contract file paths
	if c.Contracts.Ethrx.SierraPath == "" || c.Contracts.Ethrx.CasmPath == "" {
		return fmt.Errorf("contract file paths are required")
	}

	return nil
}

// GetRPCURL returns the RPC URL for the configured network
func (c *Config) GetRPCURL() string {
	return c.Network.RPCURL
}

// IsVerbose returns whether verbose logging is enabled
func (c *Config) IsVerbose() bool {
	return c.Logging.Verbose
}

// GetLogLevel returns the configured log level
func (c *Config) GetLogLevel() logrus.Level {
	switch strings.ToLower(c.Logging.Level) {
	case "debug":
		return logrus.DebugLevel
	case "info":
		return logrus.InfoLevel
	case "warn":
		return logrus.WarnLevel
	case "error":
		return logrus.ErrorLevel
	default:
		return logrus.InfoLevel
	}
}
