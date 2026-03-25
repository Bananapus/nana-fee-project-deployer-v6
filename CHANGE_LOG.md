# nana-fee-project-deployer-v6 Changelog (v5 → v6)

This document describes all changes between `nana-fee-project-deployer` (v5) and `nana-fee-project-deployer-v6` (v6).

## Summary

- **Simplified deploy script**: Reduced from 6 deployment libraries to 4 — buyback hook, 721 hook, and loan configuration all removed from the deploy flow.
- **Swap terminal → Router terminal**: `SwapTerminalDeploymentLib` replaced by `RouterTerminalDeploymentLib`, reflecting the swap terminal's replacement by the more general router terminal.
- **Cross-VM support**: `JBTokenMapping.remoteToken` changed from `address` to `bytes32` for Solana/SVM compatibility.
- **Test suite added**: First test coverage for the fee project deployer (~900 lines covering revnet config, chain-specific suckers, and deployment flow).

---

## 1. Breaking Changes

### Solidity version bump
- **v5:** `pragma solidity 0.8.23`
- **v6:** `pragma solidity 0.8.28`

### EVM target change
- **v5:** `vm_version = 'paris'` (pre-Cancun, required for L2 compatibility at the time)
- **v6:** `evm_version = 'cancun'` (enables transient storage, blob transactions)

### Buyback hook removed from deploy
- **v5:** Imported `BuybackDeploymentLib`, `REVBuybackHookConfig`, `REVBuybackPoolConfig`, and configured a Uniswap V4 TWAP-based buyback hook with a 10,000 fee tier and 2-day TWAP window.
- **v6:** All buyback hook references removed entirely. The `BuybackDeployment` state variable, its deployment library import, and the `REVBuybackHookConfig`/`REVBuybackPoolConfig` structs are gone. The `deployFor` call no longer passes a `buybackHookConfiguration` argument.

> **Why removed**: Buyback pools are now auto-initialized by `revnet-core-v6` via an immutable `BUYBACK_HOOK` registry during deployment. The fee project deployer no longer needs to configure them manually — this eliminates a deployment-time configuration step and ensures all revnets get consistent buyback behavior.

### 721 hook deployment removed
- **v5:** Imported `Hook721DeploymentLib` and loaded `Hook721Deployment hook` from on-chain deployment artifacts.
- **v6:** No 721 hook deployment library is imported or loaded. (The `@bananapus/721-hook-v6` dependency remains in `package.json` but is only used in the test file, not the deploy script.)

> **Why removed**: The omnichain deployer (`nana-omnichain-deployers-v6`) now automatically deploys a default 721 hook for every project, even without tiers configured. The fee project deployer no longer needs to handle this independently.

### Swap terminal replaced by router terminal
- **v5:** Used `SwapTerminalDeploymentLib` with `SwapTerminalDeployment swapTerminal`. The second terminal was configured as `IJBTerminal(address(swapTerminal.registry))`.
- **v6:** Uses `RouterTerminalDeploymentLib` with `RouterTerminalDeployment routerTerminal`. The second terminal is configured as `IJBTerminal(address(routerTerminal.registry))`. This reflects the swap terminal being superseded by the more general router terminal.

### Loan configuration removed from `REVConfig`
- **v5:** `REVConfig` included `loanSources` (an array of `REVLoanSource`) and `loans` (address of `revnet.loans`). A single loan source was configured for native token via `core.terminal`.
- **v6:** `REVConfig` no longer has `loanSources` or `loans` fields. Loans are now configured separately from the revnet deployment.

> **Why removed**: Loans are now managed via a single immutable `LOANS` address on the `REVDeployer`, with fund access limits derived automatically from terminal configurations. Per-revnet loan source configuration was unnecessary complexity.

### `JBTokenMapping.remoteToken` type changed
- **v5:** `remoteToken` was `address` -- set directly to `JBConstants.NATIVE_TOKEN`.
- **v6:** `remoteToken` is `bytes32` -- set to `bytes32(uint256(uint160(JBConstants.NATIVE_TOKEN)))`. This change supports non-EVM remote chains (e.g., Solana/SVM) where addresses are not 20 bytes.

### `FeeProjectConfig` struct removed
- **v5:** Defined a top-level `FeeProjectConfig` struct bundling `REVConfig`, `JBTerminalConfig[]`, `REVBuybackHookConfig`, and `REVSuckerDeploymentConfig`. Configuration was built in `getNANARevnetConfig()`, stored in state, and passed through to `deploy()`.
- **v6:** No intermediate struct. All configuration is built inline within the `deploy()` function. The `getNANARevnetConfig()` helper function is removed entirely.

### `deployFor` call signature changed
- **v5:** `revnet.basic_deployer.deployFor` accepted 5 named arguments: `revnetId`, `configuration`, `terminalConfigurations`, `buybackHookConfiguration`, `suckerDeploymentConfiguration`.
- **v6:** `revnet.basic_deployer.deployFor` accepts 4 named arguments: `revnetId`, `configuration`, `terminalConfigurations`, `suckerDeploymentConfiguration`. The `buybackHookConfiguration` parameter is removed.

### Trusted forwarder removed
- **v5:** `TRUSTED_FORWARDER` was set to `core.controller.trustedForwarder()` during `run()`.
- **v6:** `TRUSTED_FORWARDER` variable removed entirely. ERC-2771 trusted forwarder is no longer referenced in the deploy script.

### Sphinx import path changed
- **v5:** `import {Sphinx} from "@sphinx-labs/contracts/SphinxPlugin.sol";`
- **v6:** `import {Sphinx} from "@sphinx-labs/contracts/contracts/foundry/SphinxPlugin.sol";`

---

## 2. New Features

### Test suite added
- **v5:** No test directory or test files.
- **v6:** Adds `test/TestFeeProjectDeployer.sol` (~900 lines) with comprehensive coverage:
  - Mock contracts for `REVDeployer`, `JBProjects`, `JBController`, `JBMultiTerminal`, `JBSuckerDeployer`, and `RouterTerminalRegistry`.
  - Tests for revnet configuration correctness (description, base currency, split operator, stages, auto-issuances, splits, sucker deployment).
  - Chain-specific tests for Ethereum mainnet (3 sucker deployer configs) vs. L2 chains (1 sucker deployer config each for Optimism, Base, Arbitrum).
  - Verification that `core.projects.approve` is called before `deployFor`.
  - Tests for the revert case when no L2 sucker deployer is configured.
  - Named argument style used throughout for `core.projects.approve` calls: `approve({to: ..., tokenId: ...})`.

### npm test script added
- **v5:** Only `deploy:mainnets` and `deploy:testnets` scripts.
- **v6:** Adds `"test": "forge test"` and `"coverage": "forge coverage ..."` npm scripts.

---

## 3. Implementation Changes

### Code structure simplified
- **v5:** Two-phase pattern: `run()` loaded all deployments and called `getNANARevnetConfig()` to build a `FeeProjectConfig`, which was stored in contract state. `deploy()` then read from state. Six deployment libraries loaded (core, suckers, revnet, 721 hook, buyback hook, swap terminal).
- **v6:** Single-phase pattern: `run()` loads four deployment libraries (core, suckers, revnet, router terminal) and calls `deploy()` directly. `deploy()` builds all configuration inline. No intermediate struct, no config helper function, no contract-level state beyond deployment references.

### Deployment library count reduced
- **v5:** 6 deployment libraries: `CoreDeploymentLib`, `Hook721DeploymentLib`, `SuckerDeploymentLib`, `RevnetCoreDeploymentLib`, `BuybackDeploymentLib`, `SwapTerminalDeploymentLib`.
- **v6:** 4 deployment libraries: `CoreDeploymentLib`, `SuckerDeploymentLib`, `RevnetCoreDeploymentLib`, `RouterTerminalDeploymentLib`.

### Salt and name constants updated
- `ERC20_SALT`: `"_NANA_ERC20_SALT__"` → `"_NANA_ERC20_SALTV6__"`
- `SUCKER_SALT`: `"_NANA_SUCKER_SALT__"` → `"_NANA_SUCKER_SALTV6__"`
- `NAME`: `"Bananapus (Juicebox V5)"` → `"Bananapus (Juicebox V6)"`

### Auto-issuance variable naming cleaned up
- **v5:** Trailing underscore: `NANA_MAINNET_AUTO_ISSUANCE_`, `NANA_BASE_AUTO_ISSUANCE_`, `NANA_OP_AUTO_ISSUANCE_`, `NANA_ARB_AUTO_ISSUANCE_`.
- **v6:** No trailing underscore: `NANA_MAINNET_AUTO_ISSUANCE`, `NANA_BASE_AUTO_ISSUANCE`, `NANA_OP_AUTO_ISSUANCE`, `NANA_ARB_AUTO_ISSUANCE`.
- Values are identical across both versions.

### `REVDescription` uses named arguments
- **v5:** Positional: `REVDescription(NAME, SYMBOL, PROJECT_URI, ERC20_SALT)`
- **v6:** Named: `REVDescription({name: NAME, ticker: SYMBOL, uri: PROJECT_URI, salt: ERC20_SALT})`

### `core.projects.approve` uses named arguments
- **v5:** `core.projects.approve(address(revnet.basic_deployer), FEE_PROJECT_ID)`
- **v6:** `core.projects.approve({to: address(revnet.basic_deployer), tokenId: FEE_PROJECT_ID})`

### Unused imports removed
- **v5:** Imported `REVCroptopAllowedPost` and `REVLoanSource` structs that were used only for loans.
- **v6:** Only imports structs that are actively used. `REVBuybackHookConfig`, `REVBuybackPoolConfig`, `REVCroptopAllowedPost`, and `REVLoanSource` are all removed.

### Optimizer runs reduced
- **v5:** `optimizer_runs = 100000000` (100M, aggressive size-over-gas tradeoff) with `via_ir = true`.
- **v6:** `optimizer_runs = 200` (Foundry default). `via_ir` not specified (defaults to false).

### Revnet configuration values unchanged
All economic parameters remain identical:
- `splitPercent`: 6200 (62%)
- `initialIssuance`: 10,000 tokens
- `issuanceCutFrequency`: 360 days
- `issuanceCutPercent`: 380,000,000 (38%)
- `cashOutTaxRate`: 1000 (10%)
- `extraMetadata`: 4 (allow adding suckers)
- `NANA_START_TIME`: 1,740,089,444
- All four chain auto-issuance amounts unchanged
- Split: 100% to OPERATOR, no lock
- Token mappings: native-to-native, 200k minGas, 0.01 ETH minBridgeAmount
- Sucker deployer logic: 3 deployers on mainnet/sepolia, 1 on L2s

---

## 4. Migration Table

| Aspect | v5 | v6 |
|---|---|---|
| Solidity version | `0.8.23` | `0.8.28` |
| EVM target | `paris` | `cancun` |
| Optimizer runs | 100,000,000 | 200 |
| Deploy script file | `script/Deploy.s.sol` | `script/Deploy.s.sol` |
| Test file | (none) | `test/TestFeeProjectDeployer.sol` |
| Config struct | `FeeProjectConfig` (top-level) | Inline in `deploy()` |
| Config helper | `getNANARevnetConfig()` | (removed) |
| Buyback hook | `BuybackDeploymentLib` + `REVBuybackHookConfig` | Removed |
| 721 hook | `Hook721DeploymentLib` | Removed from deploy |
| Swap terminal | `SwapTerminalDeploymentLib` | Replaced by `RouterTerminalDeploymentLib` |
| Loan sources | `REVLoanSource[]` + `revnet.loans` in `REVConfig` | Removed from `REVConfig` |
| Trusted forwarder | `TRUSTED_FORWARDER` variable | Removed |
| `remoteToken` type | `address` | `bytes32` |
| `deployFor` args | 5 (incl. `buybackHookConfiguration`) | 4 |
| ERC20 salt | `"_NANA_ERC20_SALT__"` | `"_NANA_ERC20_SALTV6__"` |
| Sucker salt | `"_NANA_SUCKER_SALT__"` | `"_NANA_SUCKER_SALTV6__"` |
| Project name | `"Bananapus (Juicebox V5)"` | `"Bananapus (Juicebox V6)"` |
| Sphinx import | `@sphinx-labs/contracts/SphinxPlugin.sol` | `@sphinx-labs/contracts/contracts/foundry/SphinxPlugin.sol` |
| Sphinx project name | `"nana-core-v5"` | `"nana-core-v6"` |
| Deployment libs count | 6 | 4 |
| Dependencies count | 7 + 1 dev | 7 + 1 dev |
