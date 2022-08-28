#!/bin/bash

set -e

source ./script/.env

forge script -vvv \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  $@
