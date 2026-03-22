# Juicebox Fee Project Deployer

Deployment script for Juicebox project #1 -- the protocol fee recipient. Every Juicebox project on every chain pays a 2.5% fee on payouts and cash-outs, and all of those fees flow to project #1. This makes it the single most important project in the ecosystem: it funds protocol development, aligns incentives across participants, and underpins the NANA token economy. This repo configures project #1 as a Revnet with a router terminal and cross-chain suckers.

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

## Risks

- **Stage parameters are permanent.** The Revnet's issuance rate, issuance cut percent, split configuration, and cash-out tax rate are all locked into the stage at deploy time. If the script is executed with wrong values, there is no mechanism to amend them -- a new fee project deployment would be needed, and all existing protocol contracts reference project #1.
- **Auto-issuance amounts are fixed at deploy time.** The pre-minted NANA token counts per chain (`NANA_MAINNET_AUTO_ISSUANCE`, `NANA_BASE_AUTO_ISSUANCE`, etc.) are hardcoded constants. If the intended token distribution needs to change after deployment, a new fee project deployment would be required.
- **Fee project must be deployed first.** The fee project must exist before any other protocol operation that charges fees. `JBMultiTerminal` hardcodes `_FEE_BENEFICIARY_PROJECT_ID = 1`, so if project #1 is not configured when fees are collected, those fees have nowhere to route.

## Repository Layout

```
nana-fee-project-deployer-v6/
├── script/
│   └── Deploy.s.sol            # Forge + Sphinx deployment script (the only source file)
├── test/
│   ├── TestFeeProjectDeployer.sol      # Shared test setup and helpers
│   ├── FeeProjectDeployerFork.t.sol    # Fork tests against live deployments
│   └── FeeProjectEdgeCases.t.sol       # Edge case coverage
├── lib/
│   └── forge-std/              # Forge standard library (submodule)
├── .github/workflows/
│   ├── test.yml                # CI test workflow
│   ├── lint.yml                # CI lint workflow
│   └── publish.yml             # npm publish workflow
├── foundry.toml                # Foundry configuration
├── package.json                # npm package configuration
└── remappings.txt              # Solidity import remappings
```

## Install

```bash
npm install
```

## Develop

| Command | Description |
|---------|-------------|
| `forge build` | Compile contracts |
| `forge test` | Run tests |
| `npm run deploy:mainnets` | Propose mainnet deployment via Sphinx |
| `npm run deploy:testnets` | Propose testnet deployment via Sphinx |
