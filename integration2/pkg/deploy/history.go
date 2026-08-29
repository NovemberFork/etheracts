package deploy

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// DeploymentHistory handles logging deployment history to markdown files
type DeploymentHistory struct {
	exportsDir string
}

// NewDeploymentHistory creates a new deployment history logger
func NewDeploymentHistory() *DeploymentHistory {
	return &DeploymentHistory{
		exportsDir: "exports",
	}
}

// LogDeployment logs a deployment result to the appropriate network markdown file
func (dh *DeploymentHistory) LogDeployment(result *DeploymentResult) error {
	// Ensure exports directory exists
	if err := os.MkdirAll(dh.exportsDir, 0755); err != nil {
		return fmt.Errorf("failed to create exports directory: %w", err)
	}

	// Create filename based on network
	filename := fmt.Sprintf("%s.md", result.Network)
	filepath := filepath.Join(dh.exportsDir, filename)

	// Create or append to the file
	return dh.appendToFile(filepath, result)
}

// appendToFile appends deployment information to the markdown file
func (dh *DeploymentHistory) appendToFile(filepath string, result *DeploymentResult) error {
	// Check if file exists to determine if we need to add header
	fileExists := true
	if _, err := os.Stat(filepath); os.IsNotExist(err) {
		fileExists = false
	}

	// Open file for appending
	file, err := os.OpenFile(filepath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("failed to open file %s: %w", filepath, err)
	}
	defer file.Close()

	// Add header if file doesn't exist
	if !fileExists {
		header := dh.getHeader(result.Network)
		if _, err := file.WriteString(header); err != nil {
			return fmt.Errorf("failed to write header: %w", err)
		}
	}

	// Add deployment entry
	entry := dh.formatDeploymentEntry(result)
	if _, err := file.WriteString(entry); err != nil {
		return fmt.Errorf("failed to write deployment entry: %w", err)
	}

	return nil
}

// getHeader returns the markdown header for the network
func (dh *DeploymentHistory) getHeader(network string) string {
	networkTitle := strings.Title(network)
	if network == "local" {
		networkTitle = "Local"
	}
	
	return fmt.Sprintf("# %s Deployment History\n\n", networkTitle)
}

// formatDeploymentEntry formats a deployment result as a markdown entry
func (dh *DeploymentHistory) formatDeploymentEntry(result *DeploymentResult) string {
	timestamp := result.DeploymentTime.Format("2006-01-02 15:04:05")
	
	return fmt.Sprintf(`## Deployment - %s

- **Contract**: %s
- **Class Hash**: `+"`%s`"+`
- **Deployed Address**: `+"`%s`"+`
- **Transaction Hash**: `+"`%s`"+`
- **Timestamp**: %s

---

`, timestamp, result.ContractName, result.ClassHash, result.DeployedAddress, result.TransactionHash, timestamp)
}
