# Juicebox Fee Project Deployer

Deployment script for the Juicebox fee project (project #1). Configures the protocol fee recipient as a Revnet with router terminal and cross-chain suckers.

## Architecture

| File | Description |
|------|-------------|
| `script/Deploy.s.sol` | Forge + Sphinx deployment script. No `src/` contracts -- this repo is purely a deployment script. |

### What It Deploys

Project #1 is a Revnet that receives all Juicebox ecosystem fees (referenced by `JBMultiTerminal._FEE_BENEFICIARY_PROJECT_ID`). The script configures:

- **Token**: NANA (`$NANA`)
- **Terminals**: `JBMultiTerminal` (native token) + `JBRouterTerminal` (accepts any token, routes to native)
- **Revnet stage**: 10,000 NANA per native token initial issuance, 38% issuance cut every 360 days, 62% split percent, 0.1 cash-out tax rate
- **Auto-issuances**: Pre-minted tokens distributed across Ethereum mainnet, Base, Optimism, and Arbitrum
- **Cross-chain suckers**: Native token mapped across Ethereum, Optimism, Base, and Arbitrum (3 suckers from mainnet, 1 sucker from each L2 back to mainnet)

### Deployment Flow

1. Reads deployment addresses for core, suckers, revnet, and router terminal from npm packages.
2. Approves `REVBasicDeployer` to configure project #1.
3. Calls `basic_deployer.deployFor()` with the full Revnet configuration.

## Install

```bash
npm install
```

## Develop

| Command | Description |
|---------|-------------|
| `forge build` | Compile contracts |
| `npm run deploy:mainnets` | Propose mainnet deployment via Sphinx |
| `npm run deploy:testnets` | Propose testnet deployment via Sphinx |
