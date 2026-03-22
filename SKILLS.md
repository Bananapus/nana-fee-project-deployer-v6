# Juicebox Fee Project Deployer

## Purpose

Forge deployment script that configures Juicebox project #1 -- the protocol fee recipient -- as a Revnet with a router terminal and cross-chain suckers.

## Contracts

| Contract | Role |
|----------|------|
| `DeployScript` | Forge `Script` + Sphinx deployment script in `script/Deploy.s.sol`. No runtime contracts in `src/`. |

## Key Functions

| Function | Contract | What it does |
|----------|----------|--------------|
| `run()` | `DeployScript` | Main entry point: reads deployment addresses from npm packages, sets the operator to `safeAddress()`, calls `deploy()`. |
| `deploy()` | `DeployScript` | Sphinx-guarded: builds terminal configs (multi terminal + router terminal), revnet stage config, sucker config, approves `revnet.basic_deployer` for project #1, then calls `revnet.basic_deployer.deployFor()`. |

## Storage

| Variable | Type | Purpose |
|----------|------|---------|
| `core` | `CoreDeployment` | Core contract addresses (`projects`, `terminal`, `controller`) |
| `revnet` | `RevnetCoreDeployment` | Revnet contract addresses (`basic_deployer`, `loans`) |
| `suckers` | `SuckerDeployment` | Sucker deployer addresses (Optimism, Base, Arbitrum) |
| `routerTerminal` | `RouterTerminalDeployment` | Router terminal address (`registry`) |
| `operator` | `address` | Set to `safeAddress()` (Sphinx multisig), receives split payouts and auto-issuances |

## Constants

| Name | Value | Purpose |
|------|-------|---------|
| `ERC20_SALT` | `"_NANA_ERC20_SALTV6__"` | Salt for deterministic ERC-20 deployment |
| `SUCKER_SALT` | `"_NANA_SUCKER_SALTV6__"` | Salt for deterministic sucker deployment |
| `NAME` | `"Bananapus (Juicebox V6)"` | Project token name |
| `SYMBOL` | `"NANA"` | Project token symbol |
| `NANA_START_TIME` | `1_740_089_444` | Revnet stage start timestamp |
| `NATIVE_CURRENCY` | `uint32(uint160(NATIVE_TOKEN))` | Accounting context currency for native token |
| `ETH_CURRENCY` | `JBCurrencyIds.ETH` | Base currency for the revnet config |

## Integration Points

| Dependency | Import | Used For |
|------------|--------|----------|
| `nana-core-v6` | `CoreDeploymentLib` | Reading `JBProjects`, `JBMultiTerminal`, `JBController` addresses |
| `revnet-core-v6` | `RevnetCoreDeploymentLib` | Reading `REVBasicDeployer` (`basic_deployer`), `REVLoans` addresses |
| `nana-suckers-v6` | `SuckerDeploymentLib` | Reading sucker deployers (Optimism, Base, Arbitrum) |
| `nana-router-terminal-v6` | `RouterTerminalDeploymentLib` | Reading `JBRouterTerminal` registry address |
| `@sphinx-labs/plugins` | `Sphinx` | Multi-chain deployment coordination with team approval |

## Key Types

| Struct/Enum | Key Fields | Used In |
|-------------|------------|---------|
| `REVConfig` | `description`, `baseCurrency`, `splitOperator`, `stageConfigurations` | Passed to `revnet.basic_deployer.deployFor()` |
| `REVStageConfig` | `startsAtOrAfter`, `autoIssuances`, `splitPercent`, `splits`, `initialIssuance`, `issuanceCutFrequency`, `issuanceCutPercent`, `cashOutTaxRate`, `extraMetadata` | Single stage with 62% split, 38% issuance cut per 360 days, 10% cashout tax |
| `REVAutoIssuance` | `chainId`, `count`, `beneficiary` | 4 entries: mainnet, Base, OP, Arbitrum -- all to `operator` |
| `JBTerminalConfig` | `terminal`, `accountingContextsToAccept` | Two terminals: multi terminal (native currency) and router terminal (empty contexts) |
| `REVSuckerDeploymentConfig` | `deployerConfigurations`, `salt` | Cross-chain sucker deployment instructions |

## Gotchas

- This repo has no `src/` directory -- it is purely a deployment script.
- The script reads deployment artifact paths from environment variables with npm package defaults (e.g., `NANA_CORE_DEPLOYMENT_PATH`).
- Cross-chain strategy differs by chain: on Ethereum mainnet (or Sepolia), deploys 3 suckers (to OP, Base, Arbitrum). On L2s, deploys 1 sucker back to mainnet. Reverts if no L2 sucker deployer is configured.
- `operator` is set to `safeAddress()` (the Sphinx multisig), which receives split payouts and auto-issuances.
- `feeProjectId` is hardcoded to `1` -- this must be the first project deployed.
- The router terminal is added with empty `accountingContextsToAccept` (it accepts all tokens dynamically).
- `extraMetadata` is set to `4` on the stage config to allow adding suckers.

## Example Integration

This repo is not imported by other contracts. It is executed as a deployment script:

```bash
# Propose deployment to all mainnets via Sphinx
npm run deploy:mainnets

# Propose deployment to all testnets via Sphinx
npm run deploy:testnets
```
