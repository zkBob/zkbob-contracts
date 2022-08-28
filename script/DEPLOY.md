# Deployment is managed through Foundry solidity scripts

## Environment

All sensitive parameters, such as rpc urls and deployer private keys are managed through `.env` file in this directory.

Make sure to copy an `.env.example` and modify each required parameter from it.

## Configuration

Deployed contracts configuration parameters are supplied in the `./script/scripts/Env.s.sol` file.
Any necessary changes to those parameters should be made there, prior to executing scripts.

## Running scripts

###  Deploy BobToken
This command will simulate deployment of the token contract in the local fork.
It will also check any post-deployment constraints specified in the script.
```shell
./script/deploy.sh ./script/scripts/BobToken.s.sol
```
If deployment simulation succeeded, you will see the total gas used, expected total gas payment.
Detailed list of all simulated transactions can be found in the printed path at `./broadcast` directory.

If everything looks good, you can re-run the same command with the `--broadcast` flag, this will eventually send transactions on-chain.
```shell
./script/deploy.sh ./script/scripts/BobToken.s.sol --broadcast 
```

When deploying to public chain, contracts may be automatically verified in Etherscan, add `--verify` flag for that.
```shell
./script/deploy.sh ./script/scripts/BobToken.s.sol --broadcast --verify 
```

You will see the deployment status, transaction hashes and their receipts in the `./broadcast` directory.
