package main

import (
	"fmt"
	"os"

	"github.com/sirupsen/logrus"

	"github.com/NovemberFork/etheracts/integration/pkg/config"
	"github.com/NovemberFork/etheracts/integration/pkg/contracts"
	"github.com/NovemberFork/etheracts/integration/pkg/deploy"
)

func main() {
	// Load configuration
	cfg, err := config.LoadConfig()
	if err != nil {
		fmt.Printf("❌ Failed to load configuration: %s\n", err)
		os.Exit(1)
	}

	// Validate configuration
	if err := cfg.ValidateConfig(); err != nil {
		fmt.Printf("❌ Configuration validation failed: %s\n", err)
		os.Exit(1)
	}

	// Setup logging
	logger := setupLogger(cfg)
	logger.Info("🚀 NovemberFork Deployment Tool")
	logger.Info("================================")

	// Print configuration summary
	printConfigSummary(cfg, logger)

	// Create deployer
	deployer, err := deploy.NewDeployer(
		cfg.GetRPCURL(),
		cfg.Network.Name,
		cfg.Deployer.Address,
		cfg.Deployer.PrivateKey,
		cfg.Deployer.PublicKey,
		logger,
	)
	if err != nil {
		logger.Fatalf("❌ Failed to create deployer: %s", err)
	}

	logger.Info("✅ Connected to Starknet RPC")

	// Determine which contract to deploy
	contractType := getContractType()

	switch contractType {
	case "ethrx":
		deployEthrx(deployer, cfg, logger)
	default:
		logger.Fatalf("❌ Unknown contract type: %s", contractType)
	}
}

func setupLogger(cfg *config.Config) *logrus.Logger {
	logger := logrus.New()
	logger.SetLevel(cfg.GetLogLevel())

	// Set formatter
	if cfg.IsVerbose() {
		logger.SetFormatter(&logrus.TextFormatter{
			FullTimestamp: true,
			ForceColors:   true,
		})
	} else {
		logger.SetFormatter(&logrus.TextFormatter{
			DisableTimestamp: true,
			ForceColors:      true,
		})
	}

	return logger
}

func printConfigSummary(cfg *config.Config, logger *logrus.Logger) {
	logger.Infof("📋 Network: %s", cfg.Network.Name)
	logger.Infof("📋 RPC URL: %s", cfg.Network.RPCURL)
	logger.Infof("📋 Account: %s", cfg.Deployer.Address)

	if cfg.IsVerbose() {
		logger.Debugf("📋 Ethrx Configuration:")
		logger.Debugf("   Owner: %s", cfg.Contracts.Ethrx.Owner)
		logger.Debugf("   Name: %s", cfg.Contracts.Ethrx.Name)
		logger.Debugf("   Symbol: %s", cfg.Contracts.Ethrx.Symbol)
		logger.Debugf("   Base URI: %s", cfg.Contracts.Ethrx.BaseURI)
		logger.Debugf("   Contract URI: %s", cfg.Contracts.Ethrx.ContractURI)
		logger.Debugf("   Mint Token: %s", cfg.Contracts.Ethrx.MintToken)
		logger.Debugf("   Mint Price: %s", cfg.Contracts.Ethrx.MintPrice)
		logger.Debugf("   Max Supply: %s", cfg.Contracts.Ethrx.MaxSupply)
		logger.Debugf("   Sierra Path: %s", cfg.Contracts.Ethrx.SierraPath)
		logger.Debugf("   Casm Path: %s", cfg.Contracts.Ethrx.CasmPath)
	}
}

func getContractType() string {
	if len(os.Args) < 2 {
		return "ethrx" // default contract
	}
	return os.Args[1]
}

func deployEthrx(deployer *deploy.Deployer, cfg *config.Config, logger *logrus.Logger) {
	// Create Ethrx deployer
	ethrxDeployer := contracts.NewEthrxDeployer(deployer, &cfg.Contracts.Ethrx, logger)

	// Validate configuration
	if err := ethrxDeployer.ValidateConfig(); err != nil {
		logger.Fatalf("❌ Ethrx configuration validation failed: %s", err)
	}

	// Deploy the contract
	result, err := ethrxDeployer.Deploy()
	if err != nil {
		logger.Fatalf("❌ Ethrx deployment failed: %s", err)
	}

	// Log deployment to history file
	history := deploy.NewDeploymentHistory()
	if err := history.LogDeployment(result); err != nil {
		logger.Warnf("⚠️  Failed to log deployment to history: %s", err)
	} else {
		logger.Info("📝 Deployment logged to history file")
	}

	// Print final summary
	logger.Info("🎉 Deployment completed successfully!")
	logger.Info("📋 Final Summary:")
	logger.Infof("   Contract: %s", result.ContractName)
	logger.Infof("   Network: %s", result.Network)
	logger.Infof("   Class Hash: %s", result.ClassHash)
	logger.Infof("   Deployed Address: %s", result.DeployedAddress)
	logger.Infof("   Transaction Hash: %s", result.TransactionHash)
	logger.Infof("   Deployment Time: %s", result.DeploymentTime.Format("2006-01-02 15:04:05"))
}
