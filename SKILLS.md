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
| `PROJECT_URI` | `"ipfs://QmWCgCaryfs..."` | IPFS metadata URI for the project |
| `NANA_START_TIME` | `1_740_089_444` | Revnet stage start timestamp |
| `NATIVE_CURRENCY` | `uint32(uint160(NATIVE_TOKEN))` | Accounting context currency for native token |
| `ETH_CURRENCY` | `JBCurrencyIds.ETH` | Base currency for the revnet config |
| `DECIMALS` | `18` | Token decimals |
| `NANA_MAINNET_AUTO_ISSUANCE` | `34_614_774_622_547_324_824_200` | Auto-issued NANA tokens on Ethereum mainnet |
| `NANA_BASE_AUTO_ISSUANCE` | `1_604_412_323_715_200_204_800` | Auto-issued NANA tokens on Base |
| `NANA_OP_AUTO_ISSUANCE` | `6_266_215_368_602_910_600` | Auto-issued NANA tokens on Optimism |
| `NANA_ARB_AUTO_ISSUANCE` | `105_160_496_145_000_000` | Auto-issued NANA tokens on Arbitrum |

## REVStageConfig Field Reference

The deployment configures a single stage. Each field is documented below:

| Field | Type | Value Used | Meaning |
|-------|------|------------|---------|
| `startsAtOrAfter` | `uint48` | `1_740_089_444` | Unix timestamp when the stage becomes active. |
| `autoIssuances` | `REVAutoIssuance[]` | 4 entries | Token mints granted per chain when the stage starts. Each entry specifies `chainId`, `count` (wei-scale token amount), and `beneficiary` (the operator). |
| `splitPercent` | `uint16` | `6200` | 62% of newly issued tokens go to reserved splits (the operator). Out of 10,000 (basis points). |
| `splits` | `JBSplit[]` | 1 entry (100% to operator) | Reserved token distribution: 100% of the split goes to the operator address. |
| `initialIssuance` | `uint112` | `10_000 * 1e18` | 10,000 NANA tokens issued per 1 ETH paid. 18-decimal fixed point. |
| `issuanceCutFrequency` | `uint32` | `360 days` | Issuance decays every 360 days. |
| `issuanceCutPercent` | `uint32` | `380_000_000` | 38% issuance reduction per period. Out of 1,000,000,000 (`MAX_WEIGHT_CUT_PERCENT`). |
| `cashOutTaxRate` | `uint16` | `1000` | 10% cash-out tax. Out of 10,000 (`MAX_CASH_OUT_TAX_RATE`). |
| `extraMetadata` | `uint16` | `4` | Bit flags for hooks. See below. |

### `extraMetadata = 4` Explained

The `extraMetadata` field is a 16-bit value stored in the ruleset metadata. `REVDeployer` reads individual bits to gate certain operations:

- **Bit 2 (value `4`)**: Allows deploying new suckers via `deploySuckersFor()`. The check in `REVDeployer` is: `((metadata.metadata >> 2) & 1) == 1`. Without this bit set, calling `deploySuckersFor()` reverts with `REVDeployer_RulesetDoesNotAllowDeployingSuckers()`.

Setting `extraMetadata = 4` enables the split operator to add cross-chain suckers after the initial deployment.

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
| `REVAutoIssuance` | `chainId` (uint32), `count` (uint104), `beneficiary` (address) | 4 entries: mainnet, Base, OP, Arbitrum -- all to `operator` |
| `JBTerminalConfig` | `terminal`, `accountingContextsToAccept` | Two terminals: multi terminal (native currency) and router terminal (empty contexts) |
| `REVSuckerDeploymentConfig` | `deployerConfigurations`, `salt` | Cross-chain sucker deployment instructions |

## Errors

Errors that can occur during the deployment or from the underlying contracts:

| Error | Source | Trigger |
|-------|--------|---------|
| `revert("L2 > L1 Sucker is not configured")` | `Deploy.s.sol` | On an L2 chain, none of `optimismDeployer`, `baseDeployer`, or `arbitrumDeployer` are set in the sucker deployment artifacts. |
| `REVDeployer_StagesRequired()` | `REVDeployer` | `stageConfigurations` array is empty. |
| `REVDeployer_StageTimesMustIncrease()` | `REVDeployer` | Stage `startsAtOrAfter` timestamps are not strictly increasing (relevant when multiple stages are configured). |
| `REVDeployer_CashOutsCantBeTurnedOffCompletely()` | `REVDeployer` | `cashOutTaxRate` equals `MAX_CASH_OUT_TAX_RATE` (10,000), which would block all cash-outs. |
| `REVDeployer_MustHaveSplits()` | `REVDeployer` | `splitPercent > 0` but `splits` array is empty. |
| `REVDeployer_AutoIssuanceBeneficiaryZeroAddress()` | `REVDeployer` | An `autoIssuances` entry has `beneficiary = address(0)`. |
| `REVDeployer_RulesetDoesNotAllowDeployingSuckers()` | `REVDeployer` | `deploySuckersFor()` called but `extraMetadata` bit 2 is not set (value `4`). |
| ERC-721 `approve` revert | `JBProjects` | Caller is not the project owner when calling `core.projects.approve()`. |

## Events

Key events emitted during a successful deployment (for verification and indexing):

| Event | Contract | When |
|-------|----------|------|
| `DeployRevnet(revnetId, configuration, terminalConfigurations, suckerDeploymentConfiguration, ...)` | `REVDeployer` | Emitted at the end of `deployFor()`. Contains the full revnet config. |
| `DeploySuckers(revnetId, suckerDeploymentConfiguration, caller)` | `REVDeployer` | Emitted when cross-chain suckers are deployed as part of `deployFor()`. |
| `StoreAutoIssuanceAmount(revnetId, stageId, beneficiary, count)` | `REVDeployer` | Emitted for each auto-issuance entry stored during stage setup. |
| `Approval(owner, approved, tokenId)` | `JBProjects` (ERC-721) | Emitted when the project owner approves `REVBasicDeployer` to operate on project #1. |

## Execution

### Environment Variables

| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `NANA_CORE_DEPLOYMENT_PATH` | No | `node_modules/@bananapus/core-v6/deployments/` | Path to core deployment artifacts |
| `REVNET_CORE_DEPLOYMENT_PATH` | No | `node_modules/@rev-net/core-v6/deployments/` | Path to revnet deployment artifacts |
| `NANA_SUCKERS_DEPLOYMENT_PATH` | No | `node_modules/@bananapus/suckers-v6/deployments/` | Path to sucker deployment artifacts |
| `NANA_ROUTER_TERMINAL_DEPLOYMENT_PATH` | No | `node_modules/@bananapus/router-terminal-v6/deployments/` | Path to router terminal deployment artifacts |
| `RPC_ETHEREUM_MAINNET` | Yes (for fork tests) | -- | Ethereum mainnet RPC URL (used by `foundry.toml` `[rpc_endpoints]`) |
| `.env` file | Yes (for deployment) | -- | Sourced by `npm run deploy:*` scripts. Should contain Sphinx API keys and RPC URLs. |

### Commands

```bash
# Install dependencies
npm install

# Run unit tests (no fork required)
forge test --no-match-path "test/FeeProject*.t.sol"

# Run fork tests (requires RPC_ETHEREUM_MAINNET in .env or env)
forge test --match-path "test/FeeProject*.t.sol" --fork-url $RPC_ETHEREUM_MAINNET

# Propose deployment to all mainnets via Sphinx
npm run deploy:mainnets

# Propose deployment to all testnets via Sphinx
npm run deploy:testnets
```

### Deployment Chains

Configured in `configureSphinx()`:

- **Mainnets**: Ethereum, Optimism, Base, Arbitrum
- **Testnets**: Ethereum Sepolia, Optimism Sepolia, Base Sepolia, Arbitrum Sepolia

## Gotchas

- This repo has no `src/` directory -- it is purely a deployment script.
- The script reads deployment artifact paths from environment variables with npm package defaults (e.g., `NANA_CORE_DEPLOYMENT_PATH`).
- Cross-chain strategy differs by chain: on Ethereum mainnet (or Sepolia), deploys 3 suckers (to OP, Base, Arbitrum). On L2s, deploys 1 sucker back to mainnet. Reverts if no L2 sucker deployer is configured.
- `operator` is set to `safeAddress()` (the Sphinx multisig), which receives split payouts and auto-issuances.
- `feeProjectId` is hardcoded to `1` -- this must be the first project deployed.
- The router terminal is added with empty `accountingContextsToAccept` (it accepts all tokens dynamically).
- `extraMetadata` is set to `4` on the stage config (bit 2) to allow the split operator to deploy suckers later. See the `extraMetadata = 4 Explained` section above.
- The `deploy()` function is guarded by the `sphinx` modifier, meaning it runs through Sphinx's multi-chain proposal system rather than broadcasting directly.
- Fork tests in `FeeProjectDeployerFork.t.sol` and `FeeProjectEdgeCases.t.sol` require an Ethereum mainnet RPC (they fork at block 21,700,000 to ensure Uniswap V4 PoolManager is live).
- Auto-issuance amounts differ significantly per chain (mainnet gets ~34.6T tokens, Arbitrum gets ~0.1T tokens), reflecting expected activity distribution.
