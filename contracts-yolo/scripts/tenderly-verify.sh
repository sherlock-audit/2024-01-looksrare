CONTRACT_NAME="YoloV2"
COMPILER_VERSION="v0.8.23+commit.f704f362"
NUM_OF_OPTIMIZATIONS=888888

source .env

VALID_CHAIN_IDS=("11155111" "421614")

read -p "Please input the chain ID: " CHAIN_ID

if [[ "${VALID_CHAIN_IDS[@]}" =~ "$CHAIN_ID" ]]; then
  VERIFIER_URL="https://api.tenderly.co/api/v1/account/LooksRareNFT/project/yolo-v2/etherscan/verify/network/$CHAIN_ID"

  DEPLOYMENTS=`cat broadcast/Deployment.s.sol/$CHAIN_ID/run-latest.json | jq .transactions | jq ".[] | select(.transactionType == \"CREATE\")"`

  YOLO_JSON=`echo $DEPLOYMENTS | jq "select(.contractName == \"$CONTRACT_NAME\")"`

  YOLO=`echo $YOLO_JSON | jq .contractAddress`
  YOLO=("${YOLO//\"/}")

  YOLO_ARGS=`echo $YOLO_JSON | jq '.arguments | @sh'`
  YOLO_ARGS=("${YOLO_ARGS[@]//\'/}")
  YOLO_ARGS=("${YOLO_ARGS[@]//\"/}")

  forge verify-contract $YOLO \
    contracts/$CONTRACT_NAME.sol:$CONTRACT_NAME \
    --compiler-version $COMPILER_VERSION \
    --constructor-args $(cast abi-encode "constructor((address,address,uint40,uint40,uint96,address,uint16,uint16,bytes32,uint64,address,address,address,address,address,uint40,address))" "$YOLO_ARGS") \
    --chain-id $CHAIN_ID \
    --num-of-optimizations $NUM_OF_OPTIMIZATIONS \
    --verifier-url $VERIFIER_URL \
    --watch \
    --etherscan-api-key $TENDERLY_API_KEY
else
    echo "Invalid chain ID."
fi
