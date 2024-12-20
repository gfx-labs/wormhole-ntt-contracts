#!/bin/bash

source .env

# Default configuration
VERBOSITY="-vvvv"
SENDER="0x7EA57D754a845808c1f640271A46df98F8e75894"
SCRIPT_PATH="script/NttFactory.s.sol:NttFactoryDeploy"

# Read CSV and deploy
while IFS=, read -r network addr1 addr2 addr3
do
    # Skip header
    if [ "$network" != "network" ]; then
        echo "Deploying to $network"

        export WORMHOLE_CORE_BRIDGE=$addr1
        export WORMHOLE_RELAYER=$addr2
        export SPECIAL_RELAYER=$addr3
        
        forge script $SCRIPT_PATH \
            --broadcast \
            --sender $SENDER \
            -vv \
            --via-ir \
            --verify \
            --rpc-url $network 
    fi
done < addresses.csv