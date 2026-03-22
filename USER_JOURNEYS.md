# User Journeys -- nana-fee-project-deployer-v6

All user paths through the NANA fee project deployment. For each journey: entry point, key parameters, state changes, events, and edge cases.

Since this repo contains only a deployment script (no runtime contracts), these journeys describe the deployment process and the resulting on-chain state.

---

## Journey 1: Deploy the NANA Fee Project (Full Deployment)

**Entry point**: `DeployScript.run()` executed via Sphinx multi-chain deployment proposal.

**Who can call**: The Sphinx multisig signers. The `deploy()` function uses the `sphinx` modifier, so only an approved Sphinx proposal can execute the deployment transactions.

**Actor**: Protocol team via Sphinx multi-chain deployment.

**Goal**: Deploy and configure project #1 as the NANA revnet -- the protocol fee recipient across all Juicebox V6 operations.

### Preconditions

- All core infrastructure is already deployed on each target chain: `JBProjects`, `JBMultiTerminal`, `JBController`, `REVDeployer`, sucker deployers, and `JBRouterTerminalRegistry`.
- The Sphinx safe owns project #1 (the ERC-721 NFT).
- Deployment artifact paths are correct (either via npm packages or environment variable overrides).

### Parameters

| Parameter | Value | Notes |
|---|---|---|
| `feeProjectId` | `1` | Hardcoded in `deploy()` |
| `NAME` | `"Bananapus (Juicebox V6)"` | ERC-20 token name |
| `SYMBOL` | `"NANA"` | ERC-20 token ticker |
| `PROJECT_URI` | `"ipfs://QmWCgCaryfsJYBu5LczFuBz3UKK5VEU3BZFYp2mHJTLeRQ"` | Project metadata |
| `ERC20_SALT` | `"_NANA_ERC20_SALTV6__"` | Deterministic ERC-20 address |
| `SUCKER_SALT` | `"_NANA_SUCKER_SALTV6__"` | Deterministic sucker addresses |
| `NANA_START_TIME` | `1740089444` | Stage start timestamp |
| `initialIssuance` | `10,000 * 10^18` | 10,000 NANA per ETH |
| `issuanceCutFrequency` | `360 days` | Decay period |
| `issuanceCutPercent` | `380,000,000` | 38% decay per period |
| `cashOutTaxRate` | `1000` | 10% tax on cashouts |
| `splitPercent` | `6200` | 62% of issuance to splits |
| `extraMetadata` | `4` | Allow adding suckers |
| `minGas` | `200,000` | Minimum gas for bridge operations |
| `minBridgeAmount` | `0.01 ether` | Dust prevention threshold |

**Auto-issuance amounts** (pre-minted tokens per chain):

| Chain | Chain ID | Amount |
|---|---|---|
| Ethereum | 1 | ~34,614,774 * 10^18 |
| Base | 8453 | ~1,604,412 * 10^18 |
| Optimism | 10 | ~6,266 * 10^18 |
| Arbitrum | 42161 | ~105 * 10^18 |

### State Changes

1. `run()` loads deployment artifacts from `CoreDeploymentLib`, `SuckerDeploymentLib`, `RevnetCoreDeploymentLib`, and `RouterTerminalDeploymentLib` for the current chain.
2. `operator` is set to `safeAddress()` (the Sphinx multisig on the current chain).
3. `deploy()` executes under the `sphinx` modifier:
   1. **Configure terminals**: Terminal 1 is `core.terminal` (JBMultiTerminal) accepting native token (ETH, 18 decimals). Terminal 2 is `routerTerminal.registry` (JBRouterTerminalRegistry) with no accounting contexts.
   2. **Configure splits**: Single split -- 100% (`SPLITS_TOTAL_PERCENT`) to `OPERATOR`, no lock, no hook, no project redirect.
   3. **Configure auto-issuances**: 4 entries (one per chain, amounts above).
   4. **Configure revnet stage**: Single immutable stage with the parameters listed above.
   5. **Configure sucker deployments**: On Ethereum -- 3 suckers (OP, Base, Arbitrum deployers). On L2s -- 1 sucker back to mainnet (auto-selects correct deployer). Token mapping: native token to native token.
   6. **Approve**: `core.projects.approve(revnet.basic_deployer, 1)` -- gives `REVDeployer` ERC-721 approval for project #1.
   7. **Deploy**: `revnet.basic_deployer.deployFor(1, revnetConfiguration, terminalConfigurations, suckerDeploymentConfiguration)` -- configures the revnet, which internally queues rulesets, sets terminals, deploys the ERC-20 token, mints auto-issuance tokens, and deploys suckers.

### Events

No events are emitted directly by `DeployScript`. The downstream contracts called during `deployFor` emit their own events, including (but not limited to):

- `LaunchProject` (from `JBController`) -- ruleset configuration
- `QueueRulesets` / `RulesetQueued` (from `JBController` / `JBRulesets`) -- stage encoding
- `MintTokens` (from `JBController`) -- auto-issuance minting
- `DeployERC20` (from `JBController`) -- NANA token deployment
- `Approval` (from `JBProjects` ERC-721) -- granting `REVDeployer` approval
- `SuckerDeployedFor` (from sucker deployers) -- sucker contract creation

### Edge Cases

- If the L2 has no valid sucker deployer configured (all three deployer addresses are `address(0)`), the script reverts with `"L2 > L1 Sucker is not configured"`.
- `feeProjectId = 1` is hardcoded. If a different project ID were needed, the script would require modification.
- The `sphinx` modifier ensures all transactions execute atomically within the Sphinx proposal -- partial deployment is not possible.
- Auto-issuance amounts are `uint104` constants -- they cannot overflow but must sum to the intended total NANA supply across all chains.

### What to Verify

- `FEE_PROJECT_ID` is `1`. The entire Juicebox fee system routes to project #1 -- using any other ID would mean fees go to the wrong project.
- The `OPERATOR` address is the correct multisig on each chain. Since `safeAddress()` returns the Sphinx-managed safe, verify the safe configuration.
- Auto-issuance amounts sum to the intended total NANA supply across all chains.
- The revnet stage parameters match the intended economic design (10,000 NANA/ETH initial issuance, 38% decay per 360 days, 10% cashout tax, 62% split).
- On mainnet, all 3 suckers are deployed. On each L2, the correct bridge deployer is selected.
- `extraMetadata = 4` correctly enables the "add suckers" permission in the revnet configuration.

---

## Journey 2: Protocol Fees Flow to Project #1

**Entry point**: `JBMultiTerminal.pay(...)` / `JBMultiTerminal.cashOutTokensOf(...)` / `JBMultiTerminal.sendPayoutsOf(...)` on any Juicebox V6 project.

**Who can call**: Anyone. Fee collection is automatic -- any user interacting with any Juicebox V6 project triggers fee accrual when applicable.

**Actor**: Any user paying into, cashing out of, or triggering payouts from any Juicebox V6 project.

**Goal**: Understand how protocol fees reach the NANA fee project after deployment.

### Preconditions

- Project #1 is deployed and configured (Journey 1 complete).
- A user interacts with any Juicebox V6 project's terminal in a fee-eligible operation.

### State Changes

1. **User interacts with project N via `JBMultiTerminal`**: `JBMultiTerminal` charges a 2.5% fee on payouts and cashouts (unless the address is feeless via `JBFeelessAddresses`). Fees are held for 28 days (`_FEE_HOLDING_SECONDS = 2,419,200`), then processed.
2. **Fees are processed and routed to project #1**: `JBMultiTerminal` pays the fee amount to project #1 via the fee project's terminal. This triggers a payment into the NANA revnet.
3. **NANA tokens are minted**: Project #1's revnet mints NANA tokens to the fee payer at the current issuance rate. 62% of newly minted tokens go to the OPERATOR (multisig) via the configured split. The remaining 38% goes to the fee payer.
4. **Surplus grows**: As fees flow in, the project's surplus increases. The issuance rate decays by 38% every 360 days, reducing new token minting over time. Token holders can cash out at a 10% tax rate.

### Events

No events are emitted by this deployment script. The fee flow events are emitted by `JBMultiTerminal` and `JBController` in nana-core-v6:

- `Pay(rulesetId, rulesetCycleNumber, projectId=1, ...)` -- when the fee payment lands in project #1
- `MintTokens(...)` -- when NANA tokens are minted from the fee payment
- `HeldFeeProcessed(...)` -- when held fees are released after the 28-day hold

### Edge Cases

- The fee routing in `JBMultiTerminal` targets `FEE_BENEFICIARY_PROJECT_ID = 1` (defined in nana-core, not in this script). If that constant were different, fees would route elsewhere.
- The terminal configured for project #1 must accept the same tokens that other terminals charge fees in (native token). If a project charges fees in a token that project #1's terminal does not accept, the fee payment will fail (try-catch in `JBMultiTerminal` catches this and holds the fee).
- The auto-issuance tokens represent a bootstrap allocation that dilutes future fee payers. Verify the amounts are proportionate to the intended economics.
- When `cashOutTaxRate == 0` on the paying project, fees on cashouts only apply up to the project's unconsumed fee-free surplus (`_feeFreeSurplusOf`).

---

## Journey 3: Cross-Chain Bridging via Suckers

**Entry point**: `JBSucker.prepare(...)` on the source chain, followed by `JBSucker.claim(...)` on the destination chain (specific function names vary by sucker implementation).

**Who can call**: Any NANA token holder. The sucker contracts are permissionless for bridging operations.

**Actor**: NANA token holder on any supported chain.

**Goal**: Bridge NANA tokens between chains using the sucker infrastructure deployed by this script.

### Preconditions

- Project #1 is deployed on multiple chains with suckers connecting them (Journey 1 complete on all target chains).
- User holds NANA tokens on the source chain (purchased via payments to project #1 or bridged from another chain).

### Parameters

| Parameter | Value | Notes |
|---|---|---|
| `localToken` | `JBConstants.NATIVE_TOKEN` | Source chain token |
| `remoteToken` | `bytes32(uint256(uint160(JBConstants.NATIVE_TOKEN)))` | Destination chain token |
| `minGas` | `200,000` | Minimum gas for bridge operation |
| `minBridgeAmount` | `0.01 ether` | Dust prevention; amounts below this cannot be bridged |
| `salt` | `"_NANA_SUCKER_SALTV6__"` | Deterministic sucker addresses across chains |

### State Changes

1. **User initiates bridge on source chain**: Tokens are deposited into the sucker's outbox merkle tree. The sucker burns the user's NANA tokens (or locks equivalent value).
2. **Bridge message is relayed**: The bridge-specific mechanism (Optimism bridge, Arbitrum bridge, or CCIP) relays the merkle root to the destination chain.
3. **User claims on destination chain**: The destination sucker verifies the merkle proof and mints equivalent NANA tokens to the user on the destination chain.

### Events

No events are emitted by this deployment script. The bridging events are emitted by the sucker contracts in nana-suckers-v6:

- `InsertToOutboxTree(...)` -- when tokens enter the outbox on the source chain
- `Claimed(...)` -- when tokens are claimed on the destination chain

### Edge Cases

- Token mappings are native-to-native only. If additional tokens need bridging, new mappings would need to be configured (requires `MAP_SUCKER_TOKEN` permission).
- The `minBridgeAmount = 0.01 ether` prevents dust-amount bridges that would be uneconomical relative to bridge gas costs.
- The `minGas = 200,000` must be sufficient for the bridge operation on each target chain. Insufficient gas causes the bridge message to fail on the destination chain.
- The sucker salt (`"_NANA_SUCKER_SALTV6__"`) produces deterministic addresses via CREATE2, ensuring consistency across chains for peer discovery.
- On Ethereum, 3 suckers are deployed (one per L2). On each L2, only 1 sucker is deployed (back to mainnet). Direct L2-to-L2 bridging is not supported; tokens must route through mainnet.
- Token mappings are immutable once the outbox tree has entries -- they can only be disabled, not remapped (see sucker deprecation lifecycle: `ENABLED` -> `DEPRECATION_PENDING` -> `SENDING_DISABLED` -> `DEPRECATED`).

### What to Verify

- Token mappings are correct: native token on both sides, with the remote token encoded as `bytes32(uint256(uint160(JBConstants.NATIVE_TOKEN)))`.
- The `minBridgeAmount = 0.01 ether` prevents dust-amount bridges that would be uneconomical.
- The `minGas = 200,000` is sufficient for the bridge operation on each target chain.
- The sucker salt (`"_NANA_SUCKER_SALTV6__"`) produces deterministic addresses that are consistent across chains.
- On each L2, the correct bridge deployer is auto-selected (Optimism deployer on OP, Base deployer on Base, Arbitrum deployer on Arbitrum).
