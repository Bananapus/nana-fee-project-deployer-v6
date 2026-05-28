# Invariants of `nana-fee-project-deployer-v6`

Scope: the single deploy script in `script/Deploy.s.sol` plus the canonical-shape verification helpers it contains. The package has no production Solidity contracts of its own — it is a Foundry/Sphinx deployment script that calls `REVDeployer.deployFor` once per chain to launch Juicebox project `#1` as the canonical NANA fee revnet. Once `run()` completes, no surface in this repo retains live runtime authority; all subsequent behaviour lives in the composed packages (`nana-core-v6`, `revnet-core-v6`, `nana-router-terminal-v6`, `nana-suckers-v6`).

This file is the per-repo scoped invariants doc. The ecosystem-wide guarantees for project `#1` after deployment live in [`../INVARIANTS.md`](../INVARIANTS.md) (Sections A–F cover NANA as revnet 1 alongside revnets 2–7). This document covers only what the deploy script structurally guarantees about the shape it puts on chain and the idempotence/canonical-replay checks that gate a second run.

---

# Section A — Guarantees to Users / Downstream Consumers

The "users" of this package are downstream consumers that route protocol fees to project `#1`: every `JBMultiTerminal` deployed by `nana-core-v6` (which sends 28-day-held fees to project 1), `REVOwner.afterCashOutRecordedWith` (which forwards rev fees), `JBReferralSplitHook` (which is bound to `FEE_PROJECT_ID == 1`), Defifa's `fulfillCommitmentsOf`, and every operator who relies on the fee project existing in the expected shape.

## A.1 Project identity

- **A.1.1 Project ID is `1`, full stop.** The script hardcodes `uint256 feeProjectId = 1` at `script/Deploy.s.sol:100`. There is no path through this script that deploys the fee revnet at any other project ID. The whole ecosystem assumes project `#1` is the fee sink (`JBMultiTerminal._FEE_BENEFICIARY_PROJECT_ID`, `REVDeployer.FEE_REVNET_ID`, `JBReferralSplitHook.FEE_PROJECT_ID`); this script puts the canonical NANA shape onto that exact slot.
- **A.1.2 Canonical name, symbol, URI, ERC-20 salt.** `NAME = "Bananapus (Juicebox V6)"`, `SYMBOL = "NANA"`, `PROJECT_URI = "ipfs://QmWCgCaryfsJYBu5LczFuBz3UKK5VEU3BZFYp2mHJTLeRQ"`, `ERC20_SALT = "_NANA_ERC20_SALTV6__"` (`script/Deploy.s.sol:46–50`). The ERC-20 deployment salt is mixed with `address(this) == REVDeployer` by the deployer, so the resulting ERC-20 address is CREATE2-deterministic across chains for this name/symbol/salt tuple.
- **A.1.3 Operator is the canonical NANA multisig.** `operator = 0x80a8F7a4bD75b539CE26937016Df607fdC9ABeb5` is hardcoded at `script/Deploy.s.sol:93`. This address receives the full reserved-token split, is the auto-issuance beneficiary on every supported chain, and becomes the revnet's per-revnet operator under `REVOwner._operatorPermissionIndexesOf` (see `../INVARIANTS.md` B.1).
- **A.1.4 Single accepted token: chain-native ETH.** The only accounting context written is `{token: NATIVE_TOKEN, decimals: 18, currency: NATIVE_CURRENCY}` (`script/Deploy.s.sol:106–107`). NANA accepts only native ETH on every supported chain; no ERC-20 payment surface is configured.

## A.2 Economic configuration (one stage, frozen at deploy)

- **A.2.1 One stage only.** `stageConfigurations` has length 1 (`script/Deploy.s.sol:140`). The whole ruleset for the life of NANA is the single `REVStageConfig` defined at `script/Deploy.s.sol:141–152`. No queued successor; the stage cycles indefinitely under the revnet's queueing logic (which this repo does NOT carry — see `../INVARIANTS.md` C.7 and Section D Cross-Cutting #13: rulesets are frozen post-deploy because no address retains `LAUNCH_RULESETS` / `QUEUE_RULESETS`).
- **A.2.2 Stage parameters are exact.**
  - `startsAtOrAfter = NANA_START_TIME = 1_740_089_444` (Feb 20 2025 — already in the past at deploy, intentional cross-chain anchor; see `RISKS.md` §5.1).
  - `splitPercent = 6200` → 62.00% of issuance reserved.
  - `initialIssuance = 10_000 × 10**18` tokens per ETH (the stage's `weight`).
  - `issuanceCutFrequency = 360 days`.
  - `issuanceCutPercent = 380_000_000` → 38% weight cut per cycle (in 9-decimal basis, i.e. `MAX_WEIGHT_CUT_PERCENT = 1e9` → 38%).
  - `cashOutTaxRate = 1000` → 10% cash-out tax (against `MAX_CASH_OUT_TAX_RATE = 10_000`).
  - `extraMetadata = 4` → bit 2 set, which is `allowsDeployingSuckers = true` (so the operator can extend bridging post-deploy via `REVDeployer.deploySuckersFor`).
- **A.2.3 Single reserved-token split, 100% to operator.** `splits[0] = {percent: SPLITS_TOTAL_PERCENT, projectId: 0, beneficiary: operator, preferAddToBalance: false, lockedUntil: 0, hook: address(0)}` (`script/Deploy.s.sol:110–117`). Reserved tokens are minted in full to the operator address on `sendReservedTokensToSplitsOf`. No hook, no project-routing, no lock.
- **A.2.4 Cross-chain auto-issuance is fixed at four entries.** Always exactly four `REVAutoIssuance` rows (`script/Deploy.s.sol:124–138`), one per chain in the supported set (Ethereum / Base / Optimism / Arbitrum), each beneficiary is `operator`, amounts hardcoded:
  - mainnet/sepolia: `34_614_774_622_547_324_824_200`
  - base/base-sepolia: `1_604_412_323_715_200_204_800`
  - optimism/optimism-sepolia: `6_266_215_368_602_910_600`
  - arbitrum/arbitrum-sepolia: `105_160_496_145_000_000`
  
  Every chain in a set writes the *same* four entries so the encoded-configuration hash matches across chains (`script/Deploy.s.sol:119–123, 253–300`). This is load-bearing for `REVDeployer.deployFor`'s cross-chain configuration check.
- **A.2.5 `scopeCashOutsToLocalBalances = false`.** `script/Deploy.s.sol:159`. Cash-outs and REVLoans aggregate supply/surplus across all sucker-connected chains. This is the deliberate choice for the fee revnet (and revnets 1–7 generally) — see `../INVARIANTS.md` D2.7 for the arbitrage-equilibration rationale.
- **A.2.6 Base currency is ETH.** `baseCurrency = ETH_CURRENCY = JBCurrencyIds.ETH` (`script/Deploy.s.sol:157`). NANA is ETH-denominated; no Chainlink dependency for payment or cashout.

## A.3 Bridge configuration (suckers)

- **A.3.1 Mainnet hub fans out to three L2s.** On chain `1` (mainnet) or `11_155_111` (sepolia), the script writes three `JBSuckerDeployerConfig` entries: OP, Base, Arbitrum deployers (`script/Deploy.s.sol:172–182`). Mainnet is the hub topology.
- **A.3.2 L2 spokes target mainnet.** On every other supported chain, the script writes a single sucker deployer entry that prefers OP, falls back to Base, then Arbitrum — whichever has a non-zero deployer address in the loaded sucker artifacts (`script/Deploy.s.sol:184–197`). Explicit revert `"L2 > L1 Sucker is not configured"` if no L2→L1 deployer is available; the script cannot silently ship without bridge connectivity.
- **A.3.3 Single token mapping: native ↔ native.** Always one `JBTokenMapping` with `localToken = NATIVE_TOKEN`, `remoteToken = bytes32(uint256(uint160(NATIVE_TOKEN)))`, `minGas = 200_000` (`script/Deploy.s.sol:164–169`). NANA bridges native ETH only; no ERC-20 lane. Once the outbox tree has entries, this mapping is immutable per `../INVARIANTS.md` sucker invariants (can only be disabled, never remapped).
- **A.3.4 Shared sucker salt across chains.** `SUCKER_SALT = "_NANA_SUCKER_SALTV6__"` (`script/Deploy.s.sol:47`). Combined with the deployer's address-mixing, this makes sucker pair addresses deterministic across chains for matched deployments.
- **A.3.5 `peer = bytes32(0)` (resolve at deploy).** All `JBSuckerDeployerConfig` entries pass `peer: bytes32(0)`, meaning the sucker deployer computes the peer address from the salt and the chain-specific deployer; no externally-supplied peer is trusted in.

## A.4 Terminal wiring

- **A.4.1 Multi-terminal accepts native ETH.** `accountingContextsToAccept[0]` registers `JBMultiTerminal` (the chain's `core.terminal`) for `NATIVE_TOKEN` (`script/Deploy.s.sol:103–107`). This is the canonical pay/cashout terminal for the fee project.
- **A.4.2 Router-terminal registry is added as a terminal.** Via `revnet.basicDeployer.deployFor`, `REVDeployer` registers the router-terminal-registry surface alongside the multi-terminal. The canonical check `_nativeTerminalConfigIsCanonical` (`script/Deploy.s.sol:327–343`) asserts `core.terminal` is the primary terminal for native ETH AND `routerTerminal.registry` is also a terminal of the project. Both must be present.
- **A.4.3 Terminal locking is not part of this script.** The router-terminal registry's `lockTerminalFor` is a separate post-deploy operational action (see `nana-router-terminal-v6/src/JBRouterTerminalRegistry.sol`). This script wires the routing surface but does not lock it; the operator may later lock it under their `SET_ROUTER_TERMINAL` permission (granted to `operator` by `REVOwner._operatorPermissionIndexesOf`).

---

# Section B — Guarantees About the Deploy Script Itself

## B.1 Idempotence and replay safety

- **B.1.1 Pre-existing fee project must match canonical shape or revert.** If `DIRECTORY.controllerOf(feeProjectId) != address(0)` (a controller is already registered for project 1), the script calls `_feeProjectIsCanonical` (`script/Deploy.s.sol:206–213`). On mismatch it reverts `DeployScript_FeeProjectNotCanonical(feeProjectId)`; on match it returns without touching anything. This is the only path that exits without launching.
- **B.1.2 Canonical match checks nine independent properties** (`script/Deploy.s.sol:228–251`):
  1. `core.projects.ownerOf(1) == address(revnet.basicDeployer)` — the project NFT is held by `REVDeployer` (so it can drive ruleset queueing on extension).
  2. `DIRECTORY.controllerOf(1) == address(core.controller)` — `JBController` is the registered controller.
  3. `revnet.basicDeployer.FEE_REVNET_ID() == 1` — the REVDeployer immutable that hardcodes fee-revnet identity matches.
  4. `revnet.basicDeployer.hashedEncodedConfigurationOf(1) == _encodedConfigurationHashOf(revnetConfiguration)` — the on-chain stored REVConfig hash matches the script's expected hash (locks every field in A.2 and A.2.4).
  5. `revnet.owner.isOperatorOf(1, operator) == true` — REVOwner records the canonical multisig as the project-1 operator.
  6. `core.tokens.tokenOf(1).symbol() == "NANA"` (via low-level staticcall + decode at `script/Deploy.s.sol:345–353`).
  7. `core.controller.uriOf(1) == PROJECT_URI` — exact byte-equal IPFS pointer match.
  8. `_reservedSplitIsCanonical(1, operator) == true` — exactly one reserved-tokens split, `100%` to operator, `projectId=0`, `preferAddToBalance=false`, `lockedUntil=0`, `hook=address(0)` (`script/Deploy.s.sol:302–325`).
  9. `_nativeTerminalConfigIsCanonical(1) == true` — primary terminal is `core.terminal`, router-terminal-registry is also a terminal, accounting context `{NATIVE_TOKEN, 18 decimals, NATIVE_CURRENCY}` (`script/Deploy.s.sol:327–343`).
- **B.1.3 Encoded-configuration hash is order-deterministic.** `_encodedConfigurationHashOf` (`script/Deploy.s.sol:253–300`) walks `stageConfigurations` in order, then `autoIssuances` in order, and `abi.encode`-folds each non-zero auto-issuance into the running buffer. Stage start-time monotonicity is enforced (`if (i > 0 && effectiveStart <= previousStageStart) return bytes32(0)` returns the zero hash to guarantee mismatch). The exact same hash function lives in `REVDeployer`; this script implements the mirror so it can compare hashes without trusting the live state.
- **B.1.4 Zero-amount auto-issuances are skipped in the hash.** Inside the stage loop, `if (autoIssuance.count != 0) encodedConfiguration = abi.encode(...)` (`script/Deploy.s.sol:285`). A zero-count entry produces the same hash as a missing entry. The script always writes non-zero counts (A.2.4), so this is forward compatibility, not an operational concern for NANA.
- **B.1.5 Replay-after-launch is a pure no-op.** When the canonical check succeeds, the script returns at `script/Deploy.s.sol:212` BEFORE calling `core.projects.approve` or `revnet.basicDeployer.deployFor`. No state mutation, no event emission, no gas spent on the REVDeployer side.

## B.2 First-run authority handoff

- **B.2.1 Script approves `REVDeployer` to spend the project NFT just-in-time.** `core.projects.approve(revnet.basicDeployer, feeProjectId)` runs only on the first-launch path (`script/Deploy.s.sol:216`), right before `deployFor`. The Sphinx safe (the script's `msg.sender` under Sphinx execution) is expected to currently hold project NFT `#1`; on a fresh chain, the Sphinx safe inherits it from `JBProjects.createFor` invoked transitively during one of the earlier deployment scripts in the chain's setup sequence (see `deploy-all-v6` orchestration for the project-1 mint path).
- **B.2.2 `REVDeployer.deployFor` takes custody of the project NFT.** After `deployFor` completes, `JBProjects.ownerOf(1)` reads as `address(revnet.basicDeployer)` — that is canonical-shape property B.1.2 (1). The Sphinx safe loses ownership of project `#1` permanently. From this point forward, the only address that can act as the "project owner" of NANA is `REVDeployer`, which exposes a constrained surface (extending suckers, queueing operator-permitted actions through `REVOwner`).
- **B.2.3 No live authority on the script after `run()` returns.** The deploy script holds no storage. Once `run()` finishes, the script contract has no continued role. All operational power passes to `REVOwner` (operator-rotatable, see `../INVARIANTS.md` B.1) and the per-chain Sphinx safe / `_CRITICAL_INFRA_OWNER` (for infra-level concerns).

## B.3 Cross-chain consistency

- **B.3.1 Chain set is fixed by Sphinx config.** `configureSphinx` declares mainnets `[ethereum, optimism, base, arbitrum]` and testnets `[ethereum_sepolia, optimism_sepolia, base_sepolia, arbitrum_sepolia]` (`script/Deploy.s.sol:63–68`). Sphinx orchestration determines which chains the script runs on; any chain not in these arrays cannot be reached by `npm run deploy:mainnets` / `npm run deploy:testnets`.
- **B.3.2 Testnet/mainnet branching uses `block.chainid` only for chain-ID substitution.** `isTestnet` (`script/Deploy.s.sol:121–123`) picks WHICH chain IDs go into the `REVAutoIssuance.chainId` field, but does NOT change auto-issuance amounts, splits, stage parameters, or any other policy field. Every chain in a set therefore produces an identical encoded-configuration hash. This is the load-bearing cross-chain parity invariant.
- **B.3.3 The hash collision check would surface drift.** If a future maintainer accidentally diverged one chain's parameters, that chain's `_encodedConfigurationHashOf` would diverge from the others; replays on that chain would either succeed (writing the wrong shape) or, on chains that match, fail the canonical-replay check on the diverged chain. The hash check is the structural guardrail; there is no separate per-chain runtime consistency check.

---

# Section C — Per-File Operation Inventory

`script/Deploy.s.sol` is the only Solidity file in `script/`. Tests in `test/` exercise the configuration logic (`TestFeeProjectDeployer.sol`), fork the live deployment (`FeeProjectDeployerFork.t.sol`), edge-case the parameters (`FeeProjectEdgeCases.t.sol`, `test/audit/`), and lock the canonical-replay surface against regression (`test/regression/`).

## C.1 `DeployScript` — `script/Deploy.s.sol`

Inherits `forge-std/Script.sol` and Sphinx's `Sphinx`. Has no storage other than four `*Deployment` struct slots populated by `run()` for use inside `deploy()`.

### Constants (`script/Deploy.s.sol:46–60`)

All `constant` — burned into bytecode, not mutable across deployments. The list is the authoritative source of NANA's configuration:

- `ERC20_SALT = "_NANA_ERC20_SALTV6__"`
- `SUCKER_SALT = "_NANA_SUCKER_SALTV6__"`
- `NAME = "Bananapus (Juicebox V6)"`
- `SYMBOL = "NANA"`
- `PROJECT_URI = "ipfs://QmWCgCaryfsJYBu5LczFuBz3UKK5VEU3BZFYp2mHJTLeRQ"`
- `NATIVE_CURRENCY = uint32(uint160(JBConstants.NATIVE_TOKEN))`
- `ETH_CURRENCY = JBCurrencyIds.ETH`
- `DECIMALS = 18`, `DECIMAL_MULTIPLIER = 10**18`
- `NANA_START_TIME = 1_740_089_444`
- `NANA_MAINNET_AUTO_ISSUANCE = 34_614_774_622_547_324_824_200`
- `NANA_BASE_AUTO_ISSUANCE = 1_604_412_323_715_200_204_800`
- `NANA_OP_AUTO_ISSUANCE = 6_266_215_368_602_910_600`
- `NANA_ARB_AUTO_ISSUANCE = 105_160_496_145_000_000`

Changing any of these constants in a future revision and re-running on a chain that already has canonical NANA would revert with `DeployScript_FeeProjectNotCanonical(1)` (B.1.1).

### State

- **`address operator`** (`script/Deploy.s.sol:61`) — populated by `run()` from a hardcoded value (`0x80a8F7a4bD75b539CE26937016Df607fdC9ABeb5`, A.1.3). Never written elsewhere.
- **`CoreDeployment core`**, **`RevnetCoreDeployment revnet`**, **`SuckerDeployment suckers`**, **`RouterTerminalDeployment routerTerminal`** (`script/Deploy.s.sol:38–44`) — populated by `run()` from sibling-package deployment JSONs (paths overridable via env vars). All four are required.

### Public entrypoints

- **`configureSphinx() public override`** (`script/Deploy.s.sol:63–68`) — Sphinx hook. Declares project name `"nana-fee-project"` and the chain sets (B.3.1). Reads no chain state, writes no storage.
- **`run() public`** (`script/Deploy.s.sol:70–97`) — Forge entrypoint. Loads the four `*Deployment` structs from the configured JSON paths, sets `operator`, calls `deploy()`. Reading the JSONs is outside the `sphinx` modifier intentionally (Sphinx executes only the `deploy()` body as on-chain transactions; off-chain reads must run in plain forge context first).
- **`deploy() public sphinx`** (`script/Deploy.s.sol:99–226`) — the deploy transaction body, wrapped by Sphinx's `sphinx` modifier (so all calls inside route through the Sphinx Safe).
  - Builds `accountingContextsToAccept`, `splits`, `issuanceConfs`, `stageConfigurations`, `revnetConfiguration`, `tokenMappings`, `suckerDeployerConfigurations`, `suckerDeploymentConfiguration` from the constants above and the loaded deployment artifacts (`script/Deploy.s.sol:102–201`).
  - Computes `expectedConfigurationHash` via `_encodedConfigurationHashOf` (`script/Deploy.s.sol:203`).
  - **Idempotence branch**: if a controller is already registered for project 1, verifies canonical shape and returns or reverts (B.1.1–B.1.5; `script/Deploy.s.sol:205–213`).
  - **First-launch branch**: `core.projects.approve(revnet.basicDeployer, feeProjectId)` then `revnet.basicDeployer.deployFor({revnetId: 1, configuration, accountingContextsToAccept, suckerDeploymentConfiguration})` (`script/Deploy.s.sol:215–225`).
  - **Invariants:** A.1–A.4, B.1, B.2.1–B.2.2, B.3.

### Internal helpers

- **`_feeProjectIsCanonical(uint256 feeProjectId, bytes32 expectedConfigurationHash, address expectedOperator) internal view returns (bool)`** (`script/Deploy.s.sol:228–251`) — the nine-property canonical-replay check (B.1.2). All nine must pass; any one failing returns `false` and causes the caller to revert with the explicit error.
- **`_encodedConfigurationHashOf(REVConfig configuration) internal view returns (bytes32)`** (`script/Deploy.s.sol:253–300`) — mirrors `REVDeployer`'s storage hash function so the script can compare without trusting downstream state. Stage start-time monotonicity violation returns `bytes32(0)` instead of reverting, guaranteeing a comparison mismatch (B.1.3).
- **`_reservedSplitIsCanonical(uint256 projectId, address payable expectedBeneficiary) internal view returns (bool)`** (`script/Deploy.s.sol:302–325`) — fetches reserved-token splits for the current ruleset; passes only if `[{percent: SPLITS_TOTAL_PERCENT, projectId: 0, beneficiary: expectedBeneficiary, preferAddToBalance: false, lockedUntil: 0, hook: address(0)}]`. Any non-canonical reserved split — extra entries, different beneficiary, percent mismatch, hook present, lock present, project routing — fails the check.
- **`_nativeTerminalConfigIsCanonical(uint256 projectId) internal view returns (bool)`** (`script/Deploy.s.sol:327–343`) — verifies the directory's `primaryTerminalOf(projectId, NATIVE_TOKEN) == core.terminal` AND `isTerminalOf(projectId, routerTerminal.registry) == true` AND the multi-terminal's accounting context matches `{NATIVE_TOKEN, 18 decimals, NATIVE_CURRENCY}`. Other terminals may additionally be configured without failing this check, but the two canonical surfaces MUST be present in the expected roles.
- **`_projectTokenSymbolIs(uint256 projectId, string memory expectedSymbol) internal view returns (bool)`** (`script/Deploy.s.sol:345–353`) — pulls the project's ERC-20 address via `core.tokens.tokenOf(projectId)`, returns `false` if zero (no ERC-20 deployed yet), else low-level `staticcall("symbol()")` and `keccak256` compares against the expected symbol. Uses staticcall instead of an interface call because the return-type `string` can fail safely on a non-ERC-20 contract address.

### Errors

- **`DeployScript_FeeProjectNotCanonical(uint256 projectId)`** (`script/Deploy.s.sol:35`) — the single revert this script can throw on its own behalf. Surfaces a non-canonical pre-existing project 1; cannot be muted or recovered without making the on-chain state match the script's expectations.

## C.2 Tests under `test/`

- **`test/TestFeeProjectDeployer.sol`** — `FeeProjectConfigBuilder` mirrors the script's configuration logic (without Sphinx / deployment-artifact reads) and exercises it against `MockREVDeployer` to assert the exact `REVConfig`, accounting contexts, and sucker deployer configuration that get passed to `REVDeployer.deployFor`. Locks A.1, A.2, A.3, A.4 against silent regression.
- **`test/FeeProjectEdgeCases.t.sol`** — Stands up the full core + 721 hook + buyback + suckers + Croptop + revnet stack in-memory (no fork) and pushes the canonical NANA deployment through it. Exercises end-to-end behaviour against the same constants the production script uses; identifies edge cases like missing native-ETH price feeds (see `test/audit/CodexNemesisMissingNativeEthFeed.t.sol`).
- **`test/FeeProjectDeployerFork.t.sol`** — Fork tests against live RPC endpoints; verifies the deployment shape holds on actually-deployed chains.
- **`test/regression/LateStartTime.t.sol`** — Locks A.2.1 / RISKS §5.1 (historical start-time anchoring is intentional, even when `NANA_START_TIME` is in the past at deploy time).
- **`test/regression/RegressionCanonicalGuard.t.sol`** — Locks B.1.1–B.1.4 (each canonical-replay property fails independently when violated).
- **`test/regression/RegressionDeployment.t.sol`** — Locks the first-launch path's expected calldata into `REVDeployer.deployFor`.
- **`test/regression/RegressionProjectOneSquat.t.sol`** — Adversarial: someone deploys a non-canonical project as project `#1` before this script runs. Asserts the script reverts `DeployScript_FeeProjectNotCanonical(1)` and does not silently accept the squatter.

## C.3 `script/Deploy.s.sol` does NOT contain

- A surface that mints NANA tokens directly.
- A surface that can change a deployed NANA ruleset, splits, terminals, accounting contexts, or operator. Those flow through `REVOwner` (operator-rotated permission set) or are structurally frozen (rulesets, see `../INVARIANTS.md` D.13).
- A surface that locks the router-terminal binding (`lockTerminalFor` is a separate operational call against `JBRouterTerminalRegistry`; see A.4.3).
- A pause / kill switch / upgrade hook. Nothing in this repo can disable NANA after launch.
- A read of the operator-side multisig configuration. The script trusts `0x80a8F7a4bD75b539CE26937016Df607fdC9ABeb5` as a constant; auditing whether that address is in fact controlled by the intended parties is an out-of-script verification.

---

# Section D — Cross-Cutting Invariants

- **D.1 The constants ARE the policy.** Every behaviour-shaping decision is a `constant` at `script/Deploy.s.sol:46–60`. Reviewing this deployment is reviewing those constants, the `REVStageConfig` block at lines 141–152, and the canonical-replay properties at 228–251. There is no runtime configuration to inspect — the script's outputs are a pure function of its constants and the loaded deployment artifacts.
- **D.2 Cross-chain parity is hash-enforced, not check-enforced.** Every chain produces an identical `_encodedConfigurationHashOf(revnetConfiguration)` because every chain executes the same constants (B.3.2). Drift on one chain would surface as a hash mismatch against `REVDeployer.hashedEncodedConfigurationOf(1)` on a subsequent replay or on cross-chain sucker reconciliation; there is no second consistency rail.
- **D.3 Canonical-replay rejects every plausible "near match."** The nine-property check (B.1.2) covers ownership, controller registration, stored config hash, operator, symbol, URI, reserved split shape, native primary terminal, router-terminal registration. A would-be squatter who deployed project `#1` with a slightly different reserved-split beneficiary, a different operator, a different URI, or a missing router-terminal would fail. The test `test/regression/RegressionProjectOneSquat.t.sol` locks this.
- **D.4 The deploy script holds no runtime authority.** After `run()` returns, the script contract is inert. The remaining operational surface is: `REVDeployer` (custodian of the project NFT, can be invoked to extend suckers to new chains via `deploySuckersFor`), `REVOwner` (operator rotation, operator's per-revnet permission set), the operator multisig (rotating splits, buyback pool, router terminal, suckers within its permission set), and `_CRITICAL_INFRA_OWNER` (infra-level concerns, see `../INVARIANTS.md` Section E).
- **D.5 Historical start-time is intentional.** `NANA_START_TIME = 1_740_089_444` is fixed in the past so every chain shares one canonical issuance schedule. The encoded-configuration hash includes `stageConfiguration.startsAtOrAfter` directly (`script/Deploy.s.sol:274`), so this constant participates in the cross-chain hash. Re-running the script with a different `NANA_START_TIME` on a fresh chain after others have launched would produce a hash mismatch and break cross-chain parity. See `RISKS.md` §5.1.
- **D.6 Sucker hub topology is enforced by `block.chainid` switch.** Mainnet gets three outbound sucker deployers (one per L2); each L2 gets one inbound sucker deployer pointing back at mainnet (`script/Deploy.s.sol:172–197`). The explicit revert at line 195 prevents shipping an L2 without a return path to L1. There is no L2↔L2 direct bridge wiring in this script.
- **D.7 Single accepted token, single token mapping.** NANA accepts only native ETH and bridges only native ETH (A.1.4, A.3.3). Adding an ERC-20 accounting context or sucker mapping after deployment would require operator-controlled paths — not this script — and would also break canonical-replay for the multi-terminal accounting context check (B.1.2 #9 via `_nativeTerminalConfigIsCanonical`'s `accountingContext.token == NATIVE_TOKEN` assertion).
- **D.8 Fee project's economic shape is single-stage and load-bearing for the whole ecosystem.** Because NANA is the fee receiver, its `splitPercent = 6200` (62% reserved) and `cashOutTaxRate = 1000` (10%) determine how protocol fees are credited (62% reserved to operator on every fee receipt, plus the 10% tax retained on cash-outs by holders). These constants are exact (A.2.2) and frozen post-deploy.

---

# Section E — Centralization Caveats

This script's centralization posture is the *intersection* of the trust placed in (a) the Sphinx project safe that executes `deploy()`, (b) the constants the script hardcodes, and (c) the downstream packages it composes.

- **The Sphinx safe** executes `deploy()` and transiently holds project NFT `#1` between `JBProjects.createFor` (run earlier in the broader deployment) and `revnet.basicDeployer.deployFor` (here). Once `deployFor` completes, the Sphinx safe loses ownership of `#1` permanently — the NFT moves to `REVDeployer`. Pre-launch, the Sphinx safe could in principle deploy a non-canonical shape; that would either succeed (writing the wrong NANA) or fail the canonical-replay guard if attempted twice. Auditors should treat the Sphinx safe as a deploy-time trust point but NOT a runtime one.
- **The operator multisig `0x80a8F7a4bD75b539CE26937016Df607fdC9ABeb5`** is the canonical NANA operator (A.1.3). Its post-deploy powers are listed in `../INVARIANTS.md` B.1: rotate splits, rotate buyback pool / TWAP, rotate operator via `REVOwner.setOperatorOf`, set router-terminal, trigger sucker safety paths / deprecation. It CANNOT mint NANA, change the cash-out tax rate, change the weight, change the reserved-percent, replace the controller, or take the project NFT off `REVDeployer`. Cosmetic-and-routing surface only.
- **The `_CRITICAL_INFRA_OWNER` Safe** owns `JBProjects`, `JBDirectory`, `JBPrices`, `JBFeelessAddresses`, `JBSuckerRegistry`, `JBRouterTerminalRegistry`, etc. Its impact on NANA specifically is bounded — it cannot mint NANA tokens, cannot redirect NANA's project NFT, cannot change NANA's ruleset. It CAN affect the wider environment in which NANA operates (e.g., disallowing a sucker deployer would prevent NANA from extending bridging via `REVDeployer.deploySuckersFor`). See `../INVARIANTS.md` Section E.
- **`REVDeployer`** holds NANA's project NFT after `deployFor` completes (B.2.2). This is the canonical-shape property B.1.2 (1). `REVDeployer`'s on-chain surface for project `#1` is `deploySuckersFor` (operator-only via `REVOwner` permission resolution) and the data-hook callbacks routed through `REVOwner`. It has no general "transfer NANA NFT to a different controller" path.
- **The Sphinx framework itself** — see `sphinx.lock` and the Sphinx ops Safe. This is the trust assumption that wraps every `sphinx`-modifier'd `deploy()` body.

This script does NOT introduce new global admins beyond the ones already documented in `../INVARIANTS.md` Section E. Its centralization contribution is "the constants the script writes are the canonical NANA shape and any other shape on project `#1` is non-canonical and will reject on replay."

---

# Section F — Key Code References

| Invariant | File:lines |
|---|---|
| A.1.1 (project ID is 1) | `script/Deploy.s.sol:100` |
| A.1.2 (canonical name/symbol/URI/salt) | `script/Deploy.s.sol:46–50` |
| A.1.3 (canonical operator address) | `script/Deploy.s.sol:93` |
| A.1.4 (single accepted token = native ETH) | `script/Deploy.s.sol:103–107` |
| A.2.1, A.2.2 (single stage + exact parameters) | `script/Deploy.s.sol:140–152` |
| A.2.3 (single 100%-operator reserved split) | `script/Deploy.s.sol:109–117` |
| A.2.4 (cross-chain auto-issuance entries) | `script/Deploy.s.sol:56–59, 124–138` |
| A.2.5 (`scopeCashOutsToLocalBalances=false`) | `script/Deploy.s.sol:159` |
| A.2.6 (base currency = ETH) | `script/Deploy.s.sol:157` |
| A.3.1 (mainnet hub: three L2 sucker deployers) | `script/Deploy.s.sol:172–182` |
| A.3.2 (L2 spoke: single L1 sucker deployer + explicit revert) | `script/Deploy.s.sol:184–197` |
| A.3.3 (single native↔native token mapping, minGas 200k) | `script/Deploy.s.sol:164–169` |
| A.3.4 (shared sucker salt) | `script/Deploy.s.sol:47` |
| A.3.5 (`peer = bytes32(0)`) | `script/Deploy.s.sol:176, 179, 182, 190` |
| A.4.1 (multi-terminal native accounting context) | `script/Deploy.s.sol:103–107` |
| A.4.2 (router-terminal registry is also a terminal) | `script/Deploy.s.sol:331–334` |
| A.4.3 (terminal locking is out of scope) | this file; see `nana-router-terminal-v6/src/JBRouterTerminalRegistry.sol` |
| B.1.1 (canonical-replay revert path) | `script/Deploy.s.sol:35, 206–213` |
| B.1.2 (nine canonical-shape properties) | `script/Deploy.s.sol:228–251` |
| B.1.3 (encoded-configuration hash) | `script/Deploy.s.sol:253–300` |
| B.1.4 (zero-amount auto-issuance skipped) | `script/Deploy.s.sol:285` |
| B.1.5 (replay no-op early-return) | `script/Deploy.s.sol:212` |
| B.2.1 (just-in-time NFT approve) | `script/Deploy.s.sol:215–216` |
| B.2.2 (REVDeployer takes NFT custody) | `script/Deploy.s.sol:219–225, 237` |
| B.2.3 (no live authority post-`run`) | structural — script holds no storage |
| B.3.1 (Sphinx chain sets) | `script/Deploy.s.sol:63–68` |
| B.3.2 (`isTestnet` only swaps chain IDs) | `script/Deploy.s.sol:121–138` |
| B.3.3 (cross-chain hash parity guardrail) | `script/Deploy.s.sol:240` ↔ `revnet-core-v6/src/REVDeployer.sol` (sibling) |
| C.1 constants list | `script/Deploy.s.sol:46–60` |
| C.1 `_feeProjectIsCanonical` | `script/Deploy.s.sol:228–251` |
| C.1 `_encodedConfigurationHashOf` | `script/Deploy.s.sol:253–300` |
| C.1 `_reservedSplitIsCanonical` | `script/Deploy.s.sol:302–325` |
| C.1 `_nativeTerminalConfigIsCanonical` | `script/Deploy.s.sol:327–343` |
| C.1 `_projectTokenSymbolIs` | `script/Deploy.s.sol:345–353` |
| C.2 regression tests | `test/regression/RegressionCanonicalGuard.t.sol`, `RegressionDeployment.t.sol`, `RegressionProjectOneSquat.t.sol`, `LateStartTime.t.sol` |
| D.5 (historical start-time anchoring) | `script/Deploy.s.sol:55, 142`; `RISKS.md` §5.1 |
| D.6 (sucker hub topology revert) | `script/Deploy.s.sol:194–196` |
| E (REVDeployer post-launch NFT custody) | `script/Deploy.s.sol:237`; `revnet-core-v6/src/REVDeployer.sol` |
| E (operator permission set) | `revnet-core-v6/src/REVOwner.sol:806–815` |
