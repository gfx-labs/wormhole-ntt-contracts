if ! command -v jq &> /dev/null; then
  echo "jq command is not available."
  exit 1
fi

if [ ! -f "out/NttManager.sol/NttManager.json" ]; then
  echo "NttManager artifact does not exist. Run forge build first."
  exit 1
fi


if [ ! -f "out/WormholeTransceiver.sol/WormholeTransceiver.json" ]; then
  echo "WormholeTransceiver artifact does not exist. Run forge build first."
  exit 1
fi


jq '.bytecode.object' out/NttManager.sol/NttManager.json > managerBytecode.txt
jq '.bytecode.object' out/WormholeTransceiver.sol/WormholeTransceiver.json > transceiverBytecode.txt