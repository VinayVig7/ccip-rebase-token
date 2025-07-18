#!/bin/bash

# Define constants 
AMOUNT=100000


ARBI_REGISTRY_MODULE_OWNER_CUSTOM="0xE625f0b8b0Ac86946035a7729Aba124c8A64cf69"
ARBI_TOKEN_ADMIN_REGISTRY="0x8126bE56454B628a88C17849B9ED99dd5a11Bd2f"
ARBI_ROUTER="0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165"
ARBI_RNM_PROXY_ADDRESS="0x9527E2d01A3064ef6b50c1Da1C0cC523803BCFF2"
ARBI_CHAIN_SELECTOR="3478487238524512106"
ARBI_LINK_ADDRESS="0xb1D4538B4571d411F07960EF2838Ce337FE1E80E"

SEPOLIA_REGISTRY_MODULE_OWNER_CUSTOM="0x62e731218d0D47305aba2BE3751E7EE9E5520790"
SEPOLIA_TOKEN_ADMIN_REGISTRY="0x95F29FEE11c5C55d26cCcf1DB6772DE953B37B82"
SEPOLIA_ROUTER="0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59"
SEPOLIA_RNM_PROXY_ADDRESS="0xba3f6251de62dED61Ff98590cB2fDf6871FbB991"
SEPOLIA_CHAIN_SELECTOR="16015286601757825753"
SEPOLIA_LINK_ADDRESS="0x779877A7B0D9E8603169DdbD7836e478b4624789"

# Compile and deploy the Rebase Token contract
source .env
forge build

# Deploy pool contract
echo "Deploying pool contract on Arbitrum Sepolia..."
output=$(forge script ./script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url ${ARB_SEPOLIA_RPC_URL} --account myWallet --broadcast)
ARBITRUM_REBASE_TOKEN_ADDRESS=$(echo "$output" | grep 'token: contract RebaseToken' | awk '{print $4}')
ARBITRUM_POOL_ADDRESS=$(echo "$output" | grep 'pool: contract RebaseTokenPool' | awk '{print $4}')
echo "Sepolia rebase token address: $ARBITRUM_REBASE_TOKEN_ADDRESS"
echo "Sepolia pool address: $ARBITRUM_POOL_ADDRESS"


# Deploy on Sepolia
echo "Deploying on Sepolia using Deployer.s.sol..."
output=$(forge script ./script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url ${SEPOLIA_RPC_URL} --account myWallet --broadcast)
SEPOLIA_REBASE_TOKEN_ADDRESS=$(echo "$output" | grep 'token: contract RebaseToken' | awk '{print $4}')
SEPOLIA_POOL_ADDRESS=$(echo "$output" | grep 'pool: contract RebaseTokenPool' | awk '{print $4}')
echo "Sepolia rebase token address: $SEPOLIA_REBASE_TOKEN_ADDRESS"
echo "Sepolia pool address: $SEPOLIA_POOL_ADDRESS"

# Deploy vault on Sepolia
VAULT_ADDRESS=$(forge script ./script/Deployer.s.sol:VaultDeployer --rpc-url ${SEPOLIA_RPC_URL} --account myWallet --broadcast --sig "run(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} | grep 'vault: contract Vault' | awk '{print $NF}')
echo "Vault address: $VAULT_ADDRESS"

# Configure Sepolia pool
forge script ./script/ConfigurePool.s.sol:ConfigurePoolScript --rpc-url ${SEPOLIA_RPC_URL} --account myWallet --broadcast --sig "run(address,uint64,bool,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${SEPOLIA_POOL_ADDRESS} ${ARBI_CHAIN_SELECTOR} true ${ARBITRUM_POOL_ADDRESS} ${ARBITRUM_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0

# Deposit to vault
cast send ${VAULT_ADDRESS} --value ${AMOUNT} --rpc-url ${SEPOLIA_RPC_URL} --account myWallet "deposit()"

# Configure pool on Arbitrum Sepolia
echo "Configuring Arbitrum Sepolia pool..."
forge script ./script/ConfigurePool.s.sol:ConfigurePoolScript --rpc-url ${ARB_SEPOLIA_RPC_URL} --account myWallet --broadcast --sig "run(address,uint64,bool,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${ARBITRUM_POOL_ADDRESS} ${SEPOLIA_CHAIN_SELECTOR} true ${SEPOLIA_POOL_ADDRESS} ${SEPOLIA_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0

# Bridge tokens from Sepolia to Arbitrum Sepolia
SEPOLIA_BALANCE_BEFORE=$(cast balance $(cast wallet address --account myWallet) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance before bridge: $SEPOLIA_BALANCE_BEFORE"
forge script ./script/BridgeTokens.s.sol:BridgeTokensScript --rpc-url ${SEPOLIA_RPC_URL} --account myWallet --broadcast --sig "run(address,uint64,address,uint256,address,address)" $(cast wallet address --account myWallet) ${ARBI_CHAIN_SELECTOR} ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${AMOUNT} ${SEPOLIA_LINK_ADDRESS} ${SEPOLIA_ROUTER}
SEPOLIA_BALANCE_AFTER=$(cast balance $(cast wallet address --account myWallet) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance after bridge: $SEPOLIA_BALANCE_AFTER"
