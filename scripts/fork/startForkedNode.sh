#!/bin/bash

# Script to start Hardhat forked node for Base mainnet
# This allows Remix IDE and other tools to connect

echo "🚀 Starting Hardhat forked Base mainnet node..."
echo ""

# Check if FORKING is set, if not set it
if [ -z "$FORKING" ]; then
    export FORKING=true
fi

# Use BASE_RPC_URL from .env or default
if [ -z "$BASE_RPC_URL" ]; then
    export BASE_RPC_URL=${BASE_RPC_URL:-https://mainnet.base.org}
fi

echo "📡 Using RPC: $BASE_RPC_URL"
echo "🔗 Forking Base mainnet (Chain ID: 8453)"
echo ""
echo "💡 The node will start on http://127.0.0.1:8545"
echo "💡 You can connect Remix IDE using 'localhost' network"
echo ""
echo "Press Ctrl+C to stop the node"
echo ""

# Start Hardhat node with config-based forking
FORKING=true BASE_RPC_URL=$BASE_RPC_URL npx hardhat node \
    --hostname 127.0.0.1 \
    --port 8545

