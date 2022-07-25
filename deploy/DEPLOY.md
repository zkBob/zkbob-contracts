# Deployment is managed through Foundry solidity scripts

## Environment

All sensitive parameters, such as rpc urls and deployer private keys are managed through `.env` file in this directory.

Make sure to copy an `.env.example` and modify each required from it.

## Configuration

Deployed contracts configuration parameters are supplied in scripts as private constants at the top of a file.
Any necessary changes to those parameters should be made in these scripts, prior to executing them.

## Running scripts

Before running any of the below commands, make sure to source your env file with sensitive settings to your shell session.

```shell
source ./deploy/.env
```

###  Deploy BobToken
This command will simulate deployment of the token contract in the local fork.
It will also check any post-deployment constraints specified in the script.
```shell
forge script --fork-url $GC_URL --private-key $PRIVATE_KEY -vvv ./deploy/scripts/BobToken.s.sol:DeployBobToken
```
If deployment simulation succeeded, you will see the total gas used, expected total gas payment.
Detailed list of all simulated transactions can be found in the printed path at `./broadcast` directory.

If everything looks good, you can re-run the same command with the `--broadcast` flag, this will eventually send transactions on-chain.
```shell
forge script --fork-url $GC_URL --private-key $PRIVATE_KEY -vvv ./deploy/scripts/BobToken.s.sol:DeployBobToken --broadcast
```

You will see the deployment status, transaction hashes and their receipts in the `./broadcast` directory.
