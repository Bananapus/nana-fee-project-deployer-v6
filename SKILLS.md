# Juicebox Fee Project Deployer

## Purpose

Forge deployment script that configures Juicebox project #1 -- the protocol fee recipient -- as a Revnet with buyback hooks, a swap terminal, and cross-chain suckers.

## Contracts

| Contract | Role |
|----------|------|
| `DeployScript` | Forge `Script` + Sphinx deployment script in `script/Deploy.s.sol`. No runtime contracts in `src/`. |

## Key Functions

| Function | Contract | What it does |
|----------|----------|--------------|
| `run()` | `DeployScript` | Main entry point: reads deployment addresses from npm packages, builds config, calls `deploy()`. |
| `deploy()` | `DeployScript` | Sphinx-guarded: approves `REVBasicDeployer` for project #1, calls `basic_deployer.deployFor()`. |
| `getNANARevnetConfig()` | `DeployScript` | Builds the complete `FeeProjectConfig` with terminals, revnet stages, buyback hook, and sucker configuration. |

## Integration Points

| Dependency | Import | Used For |
|------------|--------|----------|
| `nana-core-v5` | `CoreDeploymentLib` | Reading `JBProjects`, `JBMultiTerminal`, `JBController` addresses |
| `revnet-core-v5` | `RevnetCoreDeploymentLib` | Reading `REVBasicDeployer`, `REVLoans` addresses |
| `nana-suckers-v5` | `SuckerDeploymentLib` | Reading sucker deployers (Optimism, Base, Arbitrum) |
| `nana-buyback-hook-v5` | `BuybackDeploymentLib` | Reading `JBBuybackHook` registry and hook |
| `nana-swap-terminal-v5` | `SwapTerminalDeploymentLib` | Reading `JBSwapTerminal` registry |
| `nana-721-hook-v5` | `Hook721DeploymentLib` | Reading 721 hook deployment addresses |
| `@sphinx-labs/plugins` | `Sphinx` | Multi-chain deployment coordination with team approval |

## Key Types

| Struct/Enum | Key Fields | Used In |
|-------------|------------|---------|
| `FeeProjectConfig` | `REVConfig configuration`, `JBTerminalConfig[] terminalConfigurations`, `REVBuybackHookConfig`, `REVSuckerDeploymentConfig` | Defined inline in `Deploy.s.sol`, passed to `basic_deployer.deployFor()` |

## Gotchas

- This repo has no `src/` directory -- it is purely a deployment script.
- The script reads deployment artifact paths from environment variables with npm package defaults (e.g., `NANA_CORE_DEPLOYMENT_PATH`).
- Cross-chain strategy differs by chain: on Ethereum mainnet, deploys 3 suckers (to OP, Base, Arbitrum). On L2s, deploys 1 sucker back to mainnet. Reverts if no L2 sucker deployer is configured.
- `OPERATOR` is set to `safeAddress()` (the Sphinx multisig), which receives split payouts and auto-issuances.
- `FEE_PROJECT_ID` is hardcoded to `1` -- this must be the first project deployed.

## Example Integration

This repo is not imported by other contracts. It is executed as a deployment script:

```bash
# Propose deployment to all mainnets via Sphinx
npm run deploy:mainnets

# Propose deployment to all testnets via Sphinx
npm run deploy:testnets
```
