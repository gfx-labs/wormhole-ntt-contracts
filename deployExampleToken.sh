#!/bin/bash

source .env

# Default configuration
VERBOSITY="-vvvv"
SENDER="0x7EA57D754a845808c1f640271A46df98F8e75894"
SCRIPT_PATH="script/deployNttToken.s.sol:NttTokenDeploy"

export BURNING_TOKEN_NAME="Token"
export BURNING_TOKEN_SYMBOL="T"

# Read CSV and deploy
if [ -n "$NTT_FACTORY" ]; then
    echo "Deploying token with $NTT_FACTORY" 

    while IFS=, read -r network _ _ _
    do
        # Skip header
        if [ "$network" != "network" ]; then
            echo "Deploying token to $network"

            forge script $SCRIPT_PATH \
                --broadcast \
                --sender $SENDER \
                -vv \
                --via-ir \
                --verify \
                --rpc-url $network 
        fi
    done < addresses.csv
else
    echo "NTT_FACTORY not defined"
fi