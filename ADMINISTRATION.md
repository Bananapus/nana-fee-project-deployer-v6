# Administration

Admin privileges and their scope in nana-fee-project-deployer-v6.

## Roles

| Role | Who | How Assigned |
|------|-----|-------------|
| Deployer | Anyone who runs the Sphinx deployment script | Executes `Deploy.s.sol` via Sphinx proposal process |
| Project #1 Owner (on-chain) | `REVDeployer` contract | Project NFT transferred to `REVDeployer` during `deployFor()` -- permanent and irreversible |
| Split Operator | Sphinx safe multisig (`safeAddress()`) | Set as `splitOperator` in `REVConfig` at deploy time |

The Sphinx safe multisig is the `OPERATOR` in the deployment script. It receives split payouts, auto-issuances, and the split operator role for project #1.

## Privileged Functions

This repo contains no runtime contracts (`src/` does not exist). All privileged functions below are on `REVDeployer`, which becomes the permanent owner of project #1 after deployment.

### DeployScript (script/Deploy.s.sol)

| Function | Required Role | Permission ID | Scope | What It Does |
|----------|--------------|---------------|-------|-------------|
| `deploy()` | Sphinx safe signer(s) | N/A (Sphinx `sphinx` modifier) | One-time | Approves `REVDeployer` for project #1 NFT, calls `REVDeployer.deployFor()` with full revnet configuration |

### REVDeployer (post-deployment, acting as project #1 owner)

| Function | Required Role | Permission ID | Scope | What It Does |
|----------|--------------|---------------|-------|-------------|
| `setSplitOperatorOf()` | Current split operator | `SET_SPLIT_GROUPS`, `SET_BUYBACK_POOL`, `SET_BUYBACK_TWAP`, `SET_PROJECT_URI`, `ADD_PRICE_FEED`, `SUCKER_SAFETY`, `ADD_SWAP_TERMINAL_POOL`, `SET_BUYBACK_HOOK`, `SET_SWAP_TERMINAL` (all 9 checked) | Project #1 | Transfers split operator role to a new address |
| `deploySuckersFor()` | Split operator | Same 9 permissions (checked via `isSplitOperatorOf`) | Project #1 | Deploys new cross-chain suckers; only works if `extraMetadata` bit 2 is set (it is: value `4`) |
| `autoIssueFor()` | Anyone | None | Per-stage, per-beneficiary | Mints pre-configured auto-issuance tokens for a beneficiary once a stage starts; one-time per stage per beneficiary |
| `burnHeldTokensOf()` | Anyone | None | Project #1 | Burns any project tokens held by the `REVDeployer` contract (from reserved token distribution leftovers) |

## Deployment Configuration

The following parameters are hardcoded in `Deploy.s.sol` and become immutable once deployed:

| Parameter | Value | Notes |
|-----------|-------|-------|
| Project ID | `1` | Hardcoded as `FEE_PROJECT_ID = 1` -- must be the first project deployed |
| Token name | `Bananapus (Juicebox V6)` | ERC-20 name |
| Token symbol | `NANA` | ERC-20 ticker |
| Base currency | ETH (`JBCurrencyIds.ETH`) | Issuance denominated in ETH |
| Initial issuance | 10,000 NANA per ETH | `uint112(10_000 * 10^18)` |
| Issuance cut | 38% every 360 days | `issuanceCutPercent: 380_000_000` over `issuanceCutFrequency: 360 days` |
| Split percent | 62% | Reserved tokens split to operator |
| Cash-out tax rate | 10% | `cashOutTaxRate: 1000` (out of 10,000) |
| Extra metadata | `4` (binary `100`) | Bit 2 set: allows deploying new suckers |
| Start time | `1_740_089_444` (Unix timestamp) | Stage start time |
| Terminals | `JBMultiTerminal` (native token) + `JBRouterTerminal` | Two terminals configured |
| Chains | Ethereum, Optimism, Base, Arbitrum | Suckers deployed for cross-chain bridging |
| Split beneficiary | Sphinx safe multisig | 100% of reserved token splits go to `OPERATOR` |
| Auto-issuances | ~34,614 NANA (mainnet), ~1,604 NANA (Base), ~6.27 NANA (OP), ~0.105 NANA (Arb) | Pre-minted to `OPERATOR` per chain |

## Post-Deployment Administration

The split operator (Sphinx safe multisig) can perform the following ongoing operations:

1. **Set split groups** (`SET_SPLIT_GROUPS`) -- Change how reserved tokens are distributed among recipients.
2. **Set buyback pool** (`SET_BUYBACK_POOL`) -- Configure Uniswap pool parameters for the buyback hook.
3. **Set buyback TWAP** (`SET_BUYBACK_TWAP`) -- Adjust the TWAP window for buyback price calculations.
4. **Set project URI** (`SET_PROJECT_URI`) -- Update the project's metadata URI.
5. **Add price feed** (`ADD_PRICE_FEED`) -- Add price feeds for currency conversions.
6. **Sucker safety** (`SUCKER_SAFETY`) -- Manage sucker safety settings (emergency hatch, deprecation).
7. **Add swap terminal pool** (`ADD_SWAP_TERMINAL_POOL`) -- Add new swap pools to the router terminal.
8. **Set buyback hook** (`SET_BUYBACK_HOOK`) -- Configure the buyback hook.
9. **Set swap terminal** (`SET_SWAP_TERMINAL`) -- Configure the swap terminal.
10. **Deploy new suckers** -- Deploy additional cross-chain suckers (enabled by `extraMetadata` bit 2).
11. **Transfer split operator role** -- Hand off the split operator role to a new address via `setSplitOperatorOf()`.

Anyone can call:
- `autoIssueFor()` -- Trigger pre-configured auto-issuance mints once a stage has started (one-time per beneficiary per stage).
- `burnHeldTokensOf()` -- Burn any project tokens stuck in the `REVDeployer` contract.

## Admin Boundaries

What admins CANNOT do:

- **Change stage parameters** -- Issuance rate, issuance cut, cash-out tax rate, split percent, and start time are immutable once deployed (revnet design).
- **Add new stages** -- The revnet's stage configuration is set at deployment and cannot be extended.
- **Mint arbitrary tokens** -- Only the `REVDeployer` (as data hook) can authorize minting, and only for suckers, the buyback hook, and the loans contract.
- **Access project funds directly** -- No payout limits are configured (the `fundAccessLimitGroups` for the loan contract provide surplus allowances, not payout limits). The split operator cannot withdraw funds from the treasury.
- **Transfer project ownership** -- The project NFT is permanently held by `REVDeployer`. There is no mechanism to transfer it out.
- **Pause payments or cash-outs** -- The revnet ruleset flags are set at deployment and cannot be changed.
- **Override the cash-out tax rate** -- The 10% tax is baked into the stage configuration.
- **Change the fee rate** -- The 2.5% protocol fee is a constant in `REVDeployer` (`FEE = 25`), not configurable.
- **Upgrade contracts** -- There is no proxy pattern or upgrade mechanism. All contracts are immutable.
