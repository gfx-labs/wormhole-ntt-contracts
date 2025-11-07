#!/bin/bash

source .env

# Default configuration
VERBOSITY="-vvvv"
SENDER="0x7EA57D754a845808c1f640271A46df98F8e75894"
SCRIPT_PATH="script/deployNttFactory.s.sol:NttFactoryDeploy"

# Read CSV and deploy
if [ -n "$VERSION" ]; then
    echo "Deploying new factories with version: $VERSION"
    
    # TODO: Update CSV format once relayers are fully removed
    # For now, reading all columns but only using coreBridge (addr1)
    while IFS=, read -r network addr1
    do
        # Skip header
        if [ "$network" != "network" ]; then
            echo "Deploying to $network"

            export WORMHOLE_CORE_BRIDGE=$addr1
            # Relayers are deprecated and set to address(0) in the script
            
            forge script $SCRIPT_PATH \
                --broadcast \
                --sender $SENDER \
                -vv \
                --via-ir \
                --verify \
                --optimize \
                --rpc-url $network 
        fi
    done < addresses.csv
else
    echo "Env variable VERSION not defined"
fi