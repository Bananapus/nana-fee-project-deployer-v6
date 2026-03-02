# nana-fee-project-deployer-v5 — AI Reference

## Purpose

Forge deployment script that configures Juicebox project #1 -- the protocol fee recipient. All Juicebox ecosystem fees flow to this project. It is deployed as a Revnet with buyback hooks, a swap terminal, and cross-chain suckers.

## Contracts

### DeployScript (script/Deploy.s.sol)
Forge `Script` + Sphinx deployment script. No runtime contracts in `src/`.

**Key constants:**
- `NAME = "Bananapus (Juicebox V5)"`, `SYMBOL = "NANA"`
- `PROJECT_URI = "ipfs://QmWCgCaryfsJYBu5LczFuBz3UKK5VEU3BZFYp2mHJTLeRQ"`
- `NANA_START_TIME = 1_740_089_444` (Unix timestamp)
- `FEE_PROJECT_ID = 1`

**Auto-issuance amounts per chain:**
- Ethereum mainnet: ~34,614 NANA (scaled)
- Base: ~1,604 NANA (scaled)
- Optimism: ~6.27 NANA (scaled)
- Arbitrum: ~0.105 NANA (scaled)

## Entry Points

```solidity
function run() public        // Main entry: reads deployments, builds config, calls deploy()
function deploy() public sphinx  // Sphinx-guarded: approves deployer, calls basic_deployer.deployFor()
function getNANARevnetConfig() internal view returns (FeeProjectConfig memory)
```

## Integration Points

- **CoreDeploymentLib**: Reads `JBProjects`, `JBMultiTerminal`, `JBController` addresses.
- **RevnetCoreDeploymentLib**: Reads `REVBasicDeployer` address.
- **SuckerDeploymentLib**: Reads sucker deployers (Optimism, Base, Arbitrum).
- **BuybackDeploymentLib**: Reads `JBBuybackHook` registry and hook.
- **SwapTerminalDeploymentLib**: Reads `JBSwapTerminal` registry.
- **Hook721DeploymentLib**: Reads 721 hook deployment (available but not used in current config).
- **Sphinx**: Multi-chain deployment coordination with team approval via Sphinx UI.

## Key Patterns

- **Revnet configuration**: Single stage with 62% split percent, 38% issuance cut every 360 days, 0.1 cash-out tax rate. Initial issuance of 10,000 NANA per native token.
- **Cross-chain strategy**: On Ethereum mainnet, deploys 3 suckers (to OP, Base, Arbitrum). On L2s, deploys 1 sucker (back to mainnet). Salt-based deterministic addressing for cross-chain sucker pairs.
- **Buyback hook**: Configured for the 1% fee Uniswap pool (NANA/wrapped native token) with a 2-day TWAP window.
- **Two terminals**: `JBMultiTerminal` accepts native token directly. `JBSwapTerminal` accepts any other token and swaps it to native.
- **No src/ contracts**: This repo is purely a deployment script. The `FeeProjectConfig` struct is defined inline in the script file.
- **Deployment dependency chain**: Reads addresses from npm-installed deployment artifacts of 6 other repos.
