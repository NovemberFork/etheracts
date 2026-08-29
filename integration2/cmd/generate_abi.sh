#!/bin/bash

# Get the script directory and navigate to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"

# Change to project root directory
cd "$PROJECT_ROOT" || {
  echo "Failed to change to project root directory"
  exit 1
}

# Define contracts and their file paths
# Add contracts here as "contract_name:abi_name"
contracts=(
  "Ethrx:ethrx"
)

echo "Running scarb build..."
scarb build || {
  echo "Failed to build contracts"
  exit 1
}

# Create ABI output directory if it doesn't exist
mkdir -p integration/exports/abi

# Generate ABIs
for contract in "${contracts[@]}"; do
  IFS=':' read -r contract_name abi_name <<<"$contract"
  json_file="target/dev/etheracts_${contract_name}.contract_class.json"
  abi_file="integration/exports/abi/${abi_name}.ts"

  echo "Generating ABI for ${contract_name}..."
  npx abi-wan-kanabi --input "$json_file" --output "$abi_file"
done

echo "✅ ABI generation completed!"
