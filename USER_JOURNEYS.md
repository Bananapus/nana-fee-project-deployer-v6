# User Journeys -- nana-fee-project-deployer-v6

All user paths through the NANA fee project deployment. For each journey: entry point, key parameters, state changes, events, and edge cases.

Since this repo contains only a deployment script (no runtime contracts), these journeys describe the deployment process and the resulting on-chain state.

---

## Journey 1: Deploy the NANA Fee Project (Full Deployment)

**Entry point**: `DeployScript.run()` executed via Sphinx multi-chain deployment proposal. Internally calls `deploy()` which is guarded by the `sphinx` modifier.

**Who can call**: Sphinx multisig signers only. The `deploy()` function uses the `sphinx` modifier, so only an approved Sphinx proposal can execute the deployment transactions.

**Parameters**:

- `feeProjectId` -- Hardcoded to `1`; the protocol fee recipient project
- `NAME` -- `"Bananapus (Juicebox V6)"`; ERC-20 token name
- `SYMBOL` -- `"NANA"`; ERC-20 token ticker
- `PROJECT_URI` -- `"ipfs://QmWCgCaryfsJYBu5LczFuBz3UKK5VEU3BZFYp2mHJTLeRQ"`; project metadata
- `ERC20_SALT` -- `"_NANA_ERC20_SALTV6__"`; deterministic ERC-20 address via CREATE2
- `SUCKER_SALT` -- `"_NANA_SUCKER_SALTV6__"`; deterministic sucker addresses via CREATE2
- `NANA_START_TIME` -- `1740089444`; revnet stage start timestamp (Unix)
- `initialIssuance` -- `10,000 * 10^18`; 10,000 NANA tokens per 1 ETH
- `issuanceCutFrequency` -- `360 days`; issuance decay period
- `issuanceCutPercent` -- `380,000,000`; 38% decay per period (out of `MAX_WEIGHT_CUT_PERCENT = 1,000,000,000`)
- `cashOutTaxRate` -- `1000`; 10% tax on cashouts (out of `MAX_CASH_OUT_TAX_RATE = 10,000`)
- `splitPercent` -- `6200`; 62% of issuance to reserved splits (basis points)
- `extraMetadata` -- `4`; bit 2 set to allow deploying suckers via `deploySuckersFor()`
- `minGas` -- `200,000`; minimum gas for bridge operations

**Auto-issuance amounts** (pre-minted tokens per chain, all to `operator`):

| Chain | Chain ID | Amount (wei-scale) |
|---|---|---|
| Ethereum | 1 | `34_614_774_622_547_324_824_200` |
| Base | 8453 | `1_604_412_323_715_200_204_800` |
| Optimism | 10 | `6_266_215_368_602_910_600` |
| Arbitrum | 42161 | `105_160_496_145_000_000` |

### Preconditions

- All core infrastructure is already deployed on each target chain: `JBProjects`, `JBMultiTerminal`, `JBController`, `REVDeployer`, sucker deployers, and `JBRouterTerminalRegistry`.
- The Sphinx safe owns project #1 (the ERC-721 NFT).
- Deployment artifact paths are correct (either via npm packages or environment variable overrides).

### State Changes

1. `DeployScript.core` -- loaded from `CoreDeploymentLib.getDeployment()` with `terminal`, `projects`, `controller` addresses for the current chain
2. `DeployScript.suckers` -- loaded from `SuckerDeploymentLib.getDeployment()` with `optimismDeployer`, `baseDeployer`, `arbitrumDeployer` addresses
3. `DeployScript.revnet` -- loaded from `RevnetCoreDeploymentLib.getDeployment()` with `basic_deployer` address
4. `DeployScript.routerTerminal` -- loaded from `RouterTerminalDeploymentLib.getDeployment()` with `registry` address
5. `DeployScript.operator = safeAddress()` -- set to the Sphinx multisig on the current chain
6. `JBProjects.approve(revnet.basic_deployer, 1)` -- grants `REVDeployer` ERC-721 approval for project #1
7. `revnet.basic_deployer.deployFor(1, revnetConfiguration, terminalConfigurations, suckerDeploymentConfiguration)` triggers internally:
   - `JBDirectory.controllerOf[1]` -- set to `JBController`
   - `JBDirectory.terminalsOf(1)` -- set to `[JBMultiTerminal, JBRouterTerminalRegistry]`
   - `JBMultiTerminal.accountingContextForTokenOf(1, NATIVE_TOKEN)` -- registered with 18 decimals
   - `JBRulesets` -- ruleset queued with encoded stage parameters (weight, duration, metadata)
   - `JBSplits.splitsOf(1, rulesetId, groupId)` -- 100% split to `operator`
   - `JBTokens` -- NANA ERC-20 deployed via CREATE2 with `ERC20_SALT`
   - `REVDeployer.amountToAutoIssue[1][stageId][operator]` -- stored for each chain's auto-issuance entry
   - `JBSuckerRegistry` -- suckers deployed and registered (3 on mainnet, 1 on L2s)

### Events

No events are emitted directly by `DeployScript`. The downstream contracts called during `deployFor` emit:

- `Approval(address indexed owner, address indexed approved, uint256 indexed tokenId)` -- from `JBProjects` (ERC-721) when the script approves `REVDeployer` for project #1
- `RulesetQueued(uint256 indexed rulesetId, uint256 indexed projectId, uint256 duration, uint256 weight, uint256 weightCutPercent, IJBRulesetApprovalHook approvalHook, uint256 metadata, uint256 mustStartAtOrAfter, address caller)` -- from `JBRulesets` for each queued ruleset
- `LaunchRulesets(uint256 rulesetId, uint256 projectId, string memo, address caller)` -- from `JBController` when rulesets are launched for the existing project
- `DeployERC20(uint256 indexed projectId, address indexed deployer, bytes32 salt, bytes32 saltHash, address caller)` -- from `JBController` when the NANA token is deployed
- `DeployERC20(uint256 indexed projectId, IJBToken indexed token, string name, string symbol, bytes32 salt, address caller)` -- from `JBTokens` when the ERC-20 clone is created and stored
- `StoreAutoIssuanceAmount(uint256 indexed revnetId, uint256 indexed stageId, address indexed beneficiary, uint256 count, address caller)` -- from `REVDeployer` for each auto-issuance entry (4 per deployment)
- `DeployRevnet(uint256 indexed revnetId, REVConfig configuration, JBTerminalConfig[] terminalConfigurations, REVSuckerDeploymentConfig suckerDeploymentConfiguration, JBRulesetConfig[] rulesetConfigurations, bytes32 encodedConfigurationHash, address caller)` -- from `REVDeployer` at the end of `deployFor()`
- `DeploySuckers(uint256 indexed revnetId, bytes32 encodedConfigurationHash, REVSuckerDeploymentConfig suckerDeploymentConfiguration, address caller)` -- from `REVDeployer` when cross-chain suckers are deployed
- `SuckerDeployedFor(uint256 projectId, address sucker, JBSuckerDeployerConfig configuration, address caller)` -- from `JBSuckerRegistry` for each individual sucker contract created

### Edge Cases

- If the L2 has no valid sucker deployer configured (all three deployer addresses are `address(0)`), the script reverts with `"L2 > L1 Sucker is not configured"`.
- `feeProjectId = 1` is hardcoded. If a different project ID were needed, the script would require modification.
- The `sphinx` modifier ensures all transactions execute atomically within the Sphinx proposal -- partial deployment is not possible.
- Auto-issuance amounts are `uint104` constants -- they cannot overflow but must sum to the intended total NANA supply across all chains.
- The router terminal is added with empty `accountingContextsToAccept` (it accepts all tokens dynamically).
- `configureSphinx()` sets `projectName = "nana-fee-project-deployer-v6"` and targets Ethereum, Optimism, Base, Arbitrum (mainnets and testnets).

### What to Verify

- `FEE_PROJECT_ID` is `1`. The entire Juicebox fee system routes to project #1 -- using any other ID would mean fees go to the wrong project.
- The `OPERATOR` address is the correct multisig on each chain. Since `safeAddress()` returns the Sphinx-managed safe, verify the safe configuration.
- Auto-issuance amounts sum to the intended total NANA supply across all chains.
- The revnet stage parameters match the intended economic design (10,000 NANA/ETH initial issuance, 38% decay per 360 days, 10% cashout tax, 62% split).
- On mainnet, all 3 suckers are deployed. On each L2, the correct bridge deployer is selected.
- `extraMetadata = 4` correctly enables the "add suckers" permission in the revnet configuration.

---

## Journey 2: Protocol Fees Flow to Project #1

**Entry point**: Fees are triggered by `JBMultiTerminal.sendPayoutsOf(uint256 projectId, address token, uint256 amount, uint256 currency, uint256 minTokensPaidOut)` and `JBMultiTerminal.cashOutTokensOf(address holder, uint256 projectId, uint256 cashOutCount, address tokenToReclaim, uint256 minTokensReclaimed, address payable beneficiary, bytes metadata)` on any Juicebox V6 project. Fees are then paid to project #1 via `JBMultiTerminal.pay(...)`.

**Who can call**: Anyone. Fee collection is automatic -- any user interacting with any Juicebox V6 project triggers fee accrual when applicable.

**Parameters**:

- `FEE` -- `25` (2.5% fee, as a fraction of `MAX_FEE = 1000`); defined in `JBMultiTerminal`, not in this script
- `_FEE_HOLDING_SECONDS` -- `2,419,200` (28 days); held fees cannot be processed until this period elapses
- `_FEE_BENEFICIARY_PROJECT_ID` -- `1`; hardcoded in `JBMultiTerminal` to route all fees to project #1

### Preconditions

- Project #1 is deployed and configured (Journey 1 complete).
- A user interacts with any Juicebox V6 project's terminal in a fee-eligible operation (payout or cashout).

### State Changes

1. `JBMultiTerminal._heldFeesOf[projectId][token]` -- fee amount appended when a payout or cashout is processed on project N (held for 28 days)
2. `JBTerminalStore.balanceOf[terminal][1][NATIVE_TOKEN]` -- incremented when the held fee is processed and paid to project #1
3. `JBController.pendingReservedTokenBalanceOf[1]` -- incremented by 62% of newly minted NANA (the reserved portion)
4. `JBTokens.creditBalanceOf[feePayer][1]` or `NANA_ERC20.balanceOf[feePayer]` -- 38% of newly minted NANA goes to the fee payer (the original project's beneficiary)
5. `JBTokens.creditBalanceOf[operator][1]` or `NANA_ERC20.balanceOf[operator]` -- 62% of newly minted NANA goes to the OPERATOR (multisig) when `sendReservedTokensToSplitsOf(1)` is called

### Events

No events are emitted by this deployment script. The fee flow events are emitted by `JBMultiTerminal`, `JBController`, and `JBTokens` in nana-core-v6:

- `HoldFee(uint256 indexed projectId, address indexed token, uint256 indexed amount, uint256 fee, address beneficiary, address caller)` -- from `JBMultiTerminal` when a fee is held for 28 days on project N
- `ProcessFee(uint256 indexed projectId, address indexed token, uint256 indexed amount, bool wasHeld, address beneficiary, address caller)` -- from `JBMultiTerminal` when the held fee is processed and paid to project #1
- `Pay(uint256 indexed rulesetId, uint256 indexed rulesetCycleNumber, uint256 indexed projectId, address payer, address beneficiary, uint256 amount, uint256 newlyIssuedTokenCount, string memo, bytes metadata, address caller)` -- from `JBMultiTerminal` when the fee payment lands in project #1 (`projectId = 1`)
- `MintTokens(address indexed beneficiary, uint256 indexed projectId, uint256 tokenCount, uint256 beneficiaryTokenCount, string memo, uint256 reservedPercent, address caller)` -- from `JBController` when NANA tokens are minted from the fee payment
- `SendReservedTokensToSplits(uint256 indexed rulesetId, uint256 indexed rulesetCycleNumber, uint256 indexed projectId, address owner, uint256 tokenCount, uint256 leftoverAmount, address caller)` -- from `JBController` when reserved NANA tokens are distributed to splits
- `FeeReverted(uint256 indexed projectId, address indexed token, uint256 indexed feeProjectId, uint256 amount, bytes reason, address caller)` -- from `JBMultiTerminal` if the fee payment to project #1 fails (fee amount returned to originating project's balance)

### Edge Cases

- The fee routing in `JBMultiTerminal` targets `_FEE_BENEFICIARY_PROJECT_ID = 1` (defined in nana-core, not in this script). If that constant were different, fees would route elsewhere.
- The terminal configured for project #1 must accept the same tokens that other terminals charge fees in (native token). If a project charges fees in a token that project #1's terminal does not accept, the fee payment will fail (try-catch in `JBMultiTerminal` catches this -- `FeeReverted` is emitted and the fee amount is returned to the originating project's balance).
- The auto-issuance tokens represent a bootstrap allocation that dilutes future fee payers. Verify the amounts are proportionate to the intended economics.
- When `cashOutTaxRate == 0` on the paying project, fees on cashouts only apply up to the project's unconsumed fee-free surplus (`_feeFreeSurplusOf`).
- Recursive fees: when a user cashes out from project #1 itself, the 2.5% fee is paid back to project #1. The terminal's try-catch prevents infinite loops -- the recursive fee payment mints additional NANA tokens to the fee payer.

---

## Journey 3: Cross-Chain Bridging via Suckers

**Entry point**: `JBSucker.prepare(...)` on the source chain to insert tokens into the outbox merkle tree, then `JBSucker.toRemote(token)` to send the outbox root and bridged assets to the remote chain, followed by `JBSucker.claim(...)` on the destination chain. The `prepare()` function has the same signature across all sucker implementations; only `toRemote` contains implementation-specific bridge logic (`JBOptimismSucker`, `JBBaseSucker`, `JBArbitrumSucker`, etc.).

**Who can call**: Any NANA token holder. The sucker contracts are permissionless for bridging operations.

**Parameters**:

- `localToken` -- `JBConstants.NATIVE_TOKEN` (`0x000000000000000000000000000000000000EEEe`); the source chain token
- `remoteToken` -- `bytes32(uint256(uint160(JBConstants.NATIVE_TOKEN)))`; the destination chain token (encoded as bytes32)
- `minGas` -- `200,000`; minimum gas for the bridge relay operation
- `salt` -- `"_NANA_SUCKER_SALTV6__"`; deterministic sucker addresses across chains via CREATE2

### Preconditions

- Project #1 is deployed on multiple chains with suckers connecting them (Journey 1 complete on all target chains).
- User holds NANA tokens on the source chain (purchased via payments to project #1 or bridged from another chain).

### State Changes

1. `JBSucker._outboxOf[NATIVE_TOKEN].tree.count` -- incremented when user's tokens are deposited into the outbox merkle tree on the source chain
2. `JBTokens.totalBalanceOf(user, 1)` -- decremented on the source chain (tokens burned or locked)
3. `JBSucker._inboxOf[NATIVE_TOKEN]` -- updated with the new merkle root on the destination chain when the bridge message arrives
4. `JBTokens.totalBalanceOf(user, 1)` -- incremented on the destination chain when the user claims with a valid merkle proof

### Events

No events are emitted by this deployment script. The bridging events are emitted by the sucker contracts in nana-suckers-v6:

- `InsertToOutboxTree(bytes32 indexed beneficiary, address indexed token, bytes32 hashed, uint256 index, bytes32 root, uint256 projectTokenCount, uint256 terminalTokenAmount, address caller)` -- from `JBSucker` when tokens enter the outbox on the source chain
- `RootToRemote(bytes32 indexed root, address indexed token, uint256 index, uint64 nonce, address caller)` -- from `JBSucker` when the outbox root is sent to the remote chain
- `NewInboxTreeRoot(address indexed token, uint64 nonce, bytes32 root, address caller)` -- from `JBSucker` when the destination chain receives the inbox root
- `Claimed(bytes32 beneficiary, address token, uint256 projectTokenCount, uint256 terminalTokenAmount, uint256 index, address caller)` -- from `JBSucker` when tokens are claimed on the destination chain

### Edge Cases

- Token mappings are native-to-native only. If additional tokens need bridging, new mappings would need to be configured (requires `MAP_SUCKER_TOKEN` permission).
- Anti-spam is handled by the global `toRemoteFee` on every `toRemote()` call, paid to the fee project, rather than a per-token minimum bridge amount.
- The `minGas = 200,000` must be sufficient for the bridge operation on each target chain. Insufficient gas causes the bridge message to fail on the destination chain.
- The sucker salt (`"_NANA_SUCKER_SALTV6__"`) produces deterministic addresses via CREATE2, ensuring consistency across chains for peer discovery.
- On Ethereum, 3 suckers are deployed (one per L2). On each L2, only 1 sucker is deployed (back to mainnet). Direct L2-to-L2 bridging is not supported; tokens must route through mainnet.
- Token mappings are immutable once the outbox tree has entries -- they can only be disabled, not remapped (see sucker deprecation lifecycle: `ENABLED` -> `DEPRECATION_PENDING` -> `SENDING_DISABLED` -> `DEPRECATED`).
- A stale merkle root from a previous bridge round is rejected on the destination chain with `StaleRootRejected(token, receivedNonce, currentNonce)`.
