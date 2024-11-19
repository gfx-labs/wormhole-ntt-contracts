#!/bin/bash


# Load environment variables
source .env

# Default configuration
SENDER="0x7EA57D754a845808c1f640271A46df98F8e75894"
VERBOSITY="-vvvv"

deploy_ntt() {
    local network=$1
    echo "Deploying NttDeployAndCall to $network..."
    
    forge script script/NttDeployAndCall.s.sol:NttDeployAndCall \
        --broadcast \
        --sender "$SENDER" \
        --via-ir \
        $VERBOSITY \
        --rpc-url "$network" \
        --verify
}

deploy_factory() {
    local network=$1
    echo "Deploying NttFactory to $network..."
    
    forge script script/NttFactory.s.sol:NttFactoryDeploy \
        --broadcast \
        --sender "$SENDER" \
        --via-ir \
        $VERBOSITY \
        --rpc-url "$network" \
        --verify
}

deploy_all_factories() {
    local networks=("$@")
    for network in "${networks[@]}"; do
        deploy_factory "$network"

        echo "Deployment to $network completed"
    done
}

deploy_all_tokens() {
    local networks=("$@")
    for network in "${networks[@]}"; do
        deploy_ntt "$network"

        echo "Deployment to $network completed"
    done
}

# Usage example:
# deploy_all "base-sepolia" "sepolia"