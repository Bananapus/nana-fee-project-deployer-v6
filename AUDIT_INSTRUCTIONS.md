# Audit Instructions -- nana-fee-project-deployer-v6

You are auditing the deployment script for Juicebox V6's fee project (project #1). This is the NANA revnet -- the project that receives the 2.5% protocol fee from all Juicebox V6 terminal operations. The repo contains a single Forge/Sphinx deployment script with no runtime contracts. The entire audit surface is parameter correctness and deployment logic. Read [RISKS.md](./RISKS.md) first -- it documents all known risks and trust assumptions. Then come back here.

## Scope

**In scope:**
```
script/Deploy.s.sol    # Sphinx deployment script (~223 lines)
```

**Out of scope:** All dependencies (nana-core, revnet-core, nana-suckers, nana-router-terminal, Sphinx plugin), node_modules, test files, forge-std. There is no `src/` directory -- this repo exists solely to deploy project #1.

## Architecture

### DeployScript

A Forge `Script` that also inherits `Sphinx` for multi-chain atomic deployment coordination. The script:

1. Reads existing deployment addresses from npm package artifacts (core, suckers, revnet, router-terminal)
2. Configures the NANA fee project as a revnet with specific parameters
3. Approves the `REVDeployer` for project #1
4. Calls `REVDeployer.deployFor(projectId=1, ...)` to configure the project

### Deployment Flow

```
Sphinx proposal -> run()
  -> Read CoreDeployment, SuckerDeployment, RevnetCoreDeployment, RouterTerminalDeployment
  -> Set OPERATOR = safeAddress() (Sphinx multisig)
  -> deploy() [sphinx modifier]
    -> Configure accounting contexts (native token, 18 decimals)
    -> Configure terminals (JBMultiTerminal + JBRouterTerminal)
    -> Define splits (100% to OPERATOR)
    -> Define auto-issuances (4 chains)
    -> Define single stage (62% split, 38% issuance cut, 10% cashout tax)
    -> Define sucker deployments (OP, Base, Arbitrum)
    -> core.projects.approve(REVDeployer, projectId=1)
    -> revnet.basic_deployer.deployFor(projectId=1, config, terminals, suckers)
```

### Hardcoded Parameters

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `FEE_PROJECT_ID` | `1` | Must be the first project deployed |
| `ERC20_SALT` | `"_NANA_ERC20_SALTV6__"` | Salt for deterministic ERC-20 token deployment |
| `SUCKER_SALT` | `"_NANA_SUCKER_SALTV6__"` | Salt for deterministic sucker deployment |
| `NAME` | `"Bananapus (Juicebox V6)"` | Token name |
| `SYMBOL` | `"NANA"` | Token symbol |
| `PROJECT_URI` | `"ipfs://QmWCgCaryf..."` | Project metadata URI |
| `NANA_START_TIME` | `1740089444` | Unix timestamp for stage start |
| `splitPercent` | `6200` (62%) | Percent of issuance routed to splits |
| `issuanceCutPercent` | `380000000` (38%) | Issuance decay per cut frequency |
| `issuanceCutFrequency` | `360 days` | How often issuance decays |
| `cashOutTaxRate` | `1000` (10%) | Tax on cashouts |
| `initialIssuance` | `10000 * 10^18` | Tokens per ETH at launch |
| `extraMetadata` | `4` | Allows adding suckers (bit flag) |

### Auto-Issuance Amounts (pre-minted to OPERATOR)

| Chain | Amount | Chain ID |
|-------|--------|----------|
| Ethereum mainnet | `34,614,774,622,547,324,824,200` | 1 |
| Base | `1,604,412,323,715,200,204,800` | 8453 |
| Optimism | `6,266,215,368,602,910,600` | 10 |
| Arbitrum | `105,160,496,145,000,000` | 42161 |

### Cross-Chain Sucker Strategy

- **On Ethereum (chainId 1 or 11155111):** Deploys 3 suckers (to OP, Base, Arbitrum)
- **On L2s:** Deploys 1 sucker back to mainnet, auto-selecting the correct deployer (OP > Base > Arbitrum priority)
- **Reverts** if no L2 sucker deployer is configured

## Priority Audit Areas

### 1. Parameter Correctness (Highest Priority)

This is a deployment script -- once executed, the revnet parameters are immutable. Every hardcoded value must be verified:

- **`splitPercent = 6200`**: Is 62% the intended operator split? This means 62% of all newly issued tokens go to the OPERATOR (Sphinx multisig) via the splits mechanism.
- **`issuanceCutPercent = 380000000`**: Revnet issuance cut uses 9-decimal precision (`MAX_WEIGHT_CUT_PERCENT = 1,000,000,000`). 380,000,000 / 1,000,000,000 = 38%. Verify the denominator assumption matches `REVDeployer`'s expectation.
- **`cashOutTaxRate = 1000`**: The max is 10,000 (basis points). 1000 / 10,000 = 10%. Verify this is the intended cashout tax.
- **`initialIssuance = uint112(10_000 * DECIMAL_MULTIPLIER)`**: 10,000 tokens per ETH. Verify the `uint112` cast does not truncate (10,000 * 10^18 = 10^22, which fits in uint112 max of ~5.19 * 10^33).
- **`NANA_START_TIME = 1740089444`**: This is February 20, 2025 at ~22:30 UTC. Verify this is the intended launch timestamp.
- **Auto-issuance amounts**: Verify these match the expected token distribution across chains. The mainnet amount (~34.6 trillion wei-scale tokens) is far larger than the L2 amounts.

### 2. Splits Configuration

```solidity
splits[0] = JBSplit({
    percent: JBConstants.SPLITS_TOTAL_PERCENT,  // 1,000,000,000 = 100%
    projectId: 0,
    beneficiary: payable(OPERATOR),
    preferAddToBalance: false,
    lockedUntil: 0,
    hook: IJBSplitHook(address(0))
});
```

- 100% of split distributions go to `OPERATOR` (the Sphinx safe).
- `lockedUntil = 0`: the split is not locked -- the revnet's split operator can change it.
- `preferAddToBalance = false`: tokens are transferred directly, not added to a project balance.
- Verify that `OPERATOR = safeAddress()` returns the correct multisig address for each chain.

### 3. Terminal Configuration

```solidity
terminalConfigurations[0] = JBTerminalConfig({
    terminal: core.terminal,
    accountingContextsToAccept: [native token, 18 decimals, NATIVE_CURRENCY]
});
terminalConfigurations[1] = JBTerminalConfig({
    terminal: IJBTerminal(address(routerTerminal.registry)),
    accountingContextsToAccept: []  // empty
});
```

- The first terminal accepts native tokens (ETH).
- The second terminal is the router terminal registry with no accounting contexts. Verify this is correct -- the router terminal typically handles token routing without directly accepting deposits.
- Verify that `core.terminal` is the `JBMultiTerminal` contract and `routerTerminal.registry` is the `JBRouterTerminalRegistry` contract.

### 4. Cross-Chain Sucker Logic

The L2 deployer selection logic:
```solidity
suckers.optimismDeployer != address(0)
    ? suckers.optimismDeployer
    : suckers.baseDeployer != address(0)
        ? suckers.baseDeployer
        : suckers.arbitrumDeployer
```

- On an L2, this selects the first non-zero deployer in priority order: OP > Base > Arbitrum.
- If all three are `address(0)`, the `arbitrumDeployer` (zero address) is used, and the subsequent check reverts: `"L2 > L1 Sucker is not configured"`.
- Verify this logic is correct for each target L2. On Base, `suckers.optimismDeployer` would be `address(0)` and `suckers.baseDeployer` would be non-zero, so Base correctly uses `baseDeployer`.
- Verify that the `tokenMappings` (native token to native token, `minGas: 200_000`) are correct for all bridge types.

### 5. Project #1 Approval Flow

```solidity
core.projects.approve(address(revnet.basic_deployer), FEE_PROJECT_ID);
revnet.basic_deployer.deployFor(FEE_PROJECT_ID, ...);
```

- The script approves `REVDeployer` to manage the project NFT for project #1.
- Verify that `core.projects.approve()` grants the ERC-721 approval needed by `REVDeployer.deployFor()`.
- Verify that the Sphinx safe owns project #1 at the time of execution (otherwise `approve` fails).

### 6. Deployment Artifact Integrity

The script reads deployment addresses from npm packages via environment variables with defaults:
```solidity
CoreDeploymentLib.getDeployment(vm.envOr("NANA_CORE_DEPLOYMENT_PATH", "node_modules/@bananapus/core-v6/deployments/"))
```

- If the npm packages contain incorrect addresses, the script will deploy against the wrong contracts.
- Verify that the deployment libraries resolve the correct addresses per chain.
- Verify that version pinning in `package.json` prevents accidental upgrades to incompatible dependency versions.

## Invariants to Verify

1. **Project #1 identity**: The script must deploy configuration for `FEE_PROJECT_ID = 1`. Verify no other project ID is used.
2. **Single stage**: Exactly one `REVStageConfig` is configured. Verify it contains all intended parameters.
3. **Operator consistency**: `OPERATOR` is set to `safeAddress()` everywhere it appears (splits beneficiary, auto-issuance beneficiary, split operator).
4. **Token configuration**: Native token (`0x000000000000000000000000000000000000EEEe`), 18 decimals, native currency accounting context.
5. **Chain-correct suckers**: On mainnet, 3 suckers (OP, Base, Arbitrum). On each L2, 1 sucker back to mainnet using the correct bridge deployer.

## Testing Setup

The repo includes 3 test files (2,364 lines total, 75 test functions):

| Test File | Tests | Lines | What It Covers |
|-----------|-------|-------|----------------|
| `TestFeeProjectDeployer.sol` | 67 | 1,059 | Unit tests for deployment parameter correctness, split configuration, terminal wiring, sucker strategy, and auto-issuance amounts |
| `FeeProjectEdgeCases.t.sol` | 4 | 753 | Edge cases: zero-address handling, chain-specific sucker selection, project #1 approval flow |
| `FeeProjectDeployerFork.t.sol` | 4 | 552 | Fork tests: end-to-end deployment on forked mainnet, post-deployment state verification |

```bash
cd nana-fee-project-deployer-v6
npm install
forge build
forge test -vvv
```

The deployment script also undergoes validation through Sphinx's simulation and multi-chain proposal process.

## Verification Commands

After deployment, verify key state on-chain:

```bash
# Verify project #1 exists and is owned by the expected safe
cast call $PROJECTS "ownerOf(uint256)" 1 --rpc-url $RPC_URL

# Verify the revnet deployer is the controller
cast call $DIRECTORY "controllerOf(uint256)" 1 --rpc-url $RPC_URL

# Verify terminal is registered
cast call $DIRECTORY "terminalsOf(uint256)" 1 --rpc-url $RPC_URL

# Verify the ERC-20 token was deployed with correct name/symbol
cast call $TOKENS "tokenOf(uint256)" 1 --rpc-url $RPC_URL
# Then: cast call $TOKEN_ADDRESS "name()" --rpc-url $RPC_URL
# Expected: "Bananapus (Juicebox V6)"
# And: cast call $TOKEN_ADDRESS "symbol()" --rpc-url $RPC_URL
# Expected: "NANA"

# Verify the current ruleset has expected parameters
cast call $CONTROLLER "currentRulesetOf(uint256)" 1 --rpc-url $RPC_URL
```

## Auto-Issuance Amounts Explained

Auto-issuance amounts represent pre-minted token allocations to the OPERATOR (Sphinx safe). These are claimed once per stage per beneficiary via `REVDeployer.autoIssueFor()`. The amounts differ per chain because the NANA revnet is deployed cross-chain via suckers, and each chain's allocation reflects its expected share of protocol activity:

- **Ethereum mainnet** (~34.6T wei-tokens): Largest allocation, primary deployment chain.
- **Base** (~1.6T wei-tokens): Second-largest L2 ecosystem.
- **Optimism** (~6.3B wei-tokens): Smaller but established L2.
- **Arbitrum** (~105M wei-tokens): Smallest initial allocation.

All amounts are in 18-decimal precision (multiply by 10^-18 for human-readable token counts).

## Previous Audit Findings

No prior formal audit has been conducted on this deployment script. The script is validated through Sphinx's simulation process and manual parameter review.

## Compiler and Version Info

- **Solidity**: 0.8.28
- **EVM target**: Cancun
- **Optimizer**: via-IR, 200 runs
- **Framework**: Foundry + Sphinx
- **Build**: `forge build`

Go break it.
