# nana-fee-project-deployer-v5

Deployment script for the Juicebox fee project (project #1). Configures the protocol fee recipient as a Revnet with buyback hooks, swap terminal, and cross-chain suckers.

## Architecture

| File | Description |
|---|---|
| `script/Deploy.s.sol` | Forge + Sphinx deployment script. No `src/` contracts. |

### What It Deploys

Project #1 is a Revnet that receives all Juicebox ecosystem fees (referenced by `JBMultiTerminal._FEE_BENEFICIARY_PROJECT_ID`). The script configures:

- **Token**: NANA (`$NANA`)
- **Terminals**: `JBMultiTerminal` (native token) + `JBSwapTerminal` (accepts any token, swaps to native)
- **Revnet stage**: 10,000 NANA per native token initial issuance, 38% issuance cut every 360 days, 62% split percent, 0.1 cash-out tax rate
- **Auto-issuances**: Pre-minted tokens distributed across Ethereum mainnet, Base, Optimism, and Arbitrum
- **Buyback hook**: 1% fee Uniswap pool, 2-day TWAP window
- **Cross-chain suckers**: Native token mapped across Ethereum, Optimism, Base, and Arbitrum

### Deployment Flow

1. Reads deployment addresses for core, suckers, revnet, 721 hook, buyback hook, and swap terminal from npm packages.
2. Approves `REVBasicDeployer` to configure project #1.
3. Calls `basic_deployer.deployFor()` with the full Revnet configuration.

## Install

```bash
npm install @bananapus/fee-project-deployer
```

## Develop

```bash
npm ci && forge install
forge build
```

Deployments are managed with [Sphinx](https://www.sphinx.dev):

```bash
npm run deploy:mainnets  # Propose mainnet deployments
npm run deploy:testnets  # Propose testnet deployments
```
