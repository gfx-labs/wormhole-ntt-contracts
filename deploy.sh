#!/bin/bash


# Load environment variables
source .env

# Default configuration
VERBOSITY="-vvvv"
SENDER="0x7EA57D754a845808c1f640271A46df98F8e75894"
SCRIPT_PATH="script/NttFactory.s.sol:NttFactoryDeploy"

for network in sepolia arbitrum_sepolia base_sepolia optimism_sepolia; do
    echo "\nDeploying to $network..."
    forge script $SCRIPT_PATH \
        --broadcast \
        --sender $SENDER \
        -vv \
        --via-ir \
        --verify \
        --rpc-url $network
done