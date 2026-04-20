# Fee Project Deployer Risk Register

This file focuses on the risks around project `#1`, the protocol fee sink. Because every other project depends on it, configuration and deployment mistakes here have outsized ecosystem impact.

## How to use this file

- Read `Priority risks` first; they highlight why project `#1` deserves stricter operational treatment than a normal deployment.
- Use the detailed sections for configuration, significance, and post-deployment reasoning.
- Treat `Invariants to Verify` as ecosystem-level checks, not local niceties.

## Priority risks

| Priority | Risk | Why it matters | Primary controls |
|----------|------|----------------|------------------|
| P0 | Misconfigured project `#1` rollout | Every fee path in the ecosystem points here; a bad deployment can break fee collection or distort token economics globally. | Deterministic deploy review, chain parity checks, and post-deploy verification of terminals, hooks, and project ID. |
| P1 | Post-deploy liveness degradation | If project `#1` cannot accept or process fees cleanly, downstream repos often continue operating while fee economics silently degrade. | Monitoring, smoke tests, and explicit routing or fallback review after deployment. |
| P1 | Governance or ownership irreversibility mistakes | The fee project's ownership and revnet wiring are intentionally opinionated; mistakes are hard to unwind. | Careful one-shot configuration review and dedicated operator runbooks. |


## 1. Trust Assumptions

- **Sphinx Deployment.** Uses Sphinx for multi-chain atomic deployment. Sphinx proposal process controls execution.
- **Operator Multisig.** The `safeAddress()` (Sphinx safe) receives operator role and split payouts. Compromise of the multisig = control of the fee project's splits and operations.
- **Existing Deployments.** Script reads deployment addresses from other repos' deployment artifacts. If those artifacts are corrupted, deployment uses wrong addresses.
- **Router-terminal artifact is a hard dependency.** The script always inserts `routerTerminal.registry` as the second accepted terminal for project `#1`. Unlike `deploy-all-v6`, this repo does not branch around chains without router-terminal support. If the router-terminal deployment artifact is missing, zero, or stale for a chain, fee-project deployment can revert or wire the wrong terminal.
- **REVDeployer.** Fee project is deployed as a revnet. All revnet trust assumptions apply (immutable stages, data hook behavior).
- **Project #1 Approval.** The script calls `core.projects.approve(revnet.basic_deployer, FEE_PROJECT_ID)` to authorize the deployer. If the wrong deployer address is approved, it could configure the fee project maliciously.

## 2. Configuration Risks

- **Hardcoded parameters.** Stage configuration (issuance, splits, tax rate, start time) is hardcoded in the script. Any error is permanent once deployed. Parameters must be reviewed exhaustively before deployment.
- **Auto-issuance amounts.** Pre-minted token amounts per chain are hardcoded constants (NANA_MAINNET_AUTO_ISSUANCE, etc.). Calculated to match expected distribution.
- **Start time.** `NANA_START_TIME` is hardcoded. If deployment occurs after this timestamp, the revnet stage starts retroactively.
- **L2 sucker deployer fallback chain.** On L2s, the script falls back through `optimismDeployer > baseDeployer > arbitrumDeployer`. If the wrong deployer is selected, suckers connect to the wrong L1 endpoint. Reverts if no deployer is found.
- **Single operator.** All splits direct 100% of payouts to one operator address (the multisig).
- **Terminal selection is configured, not locked.** The deploy script configures both the main terminal and the router-terminal registry as accepted terminals, but it does not lock terminal routing in the directory. A later directory-owner or permissioned-terminal change can silently redirect fee-project payments.
- **Router terminal support is not optional in this script.** `terminalConfigurations` is always length 2 and always includes the router-terminal registry as the second terminal. Bad router-terminal deployment metadata is therefore not just a soft feature loss here; it changes or blocks the canonical fee-project deployment shape.
- **splitPercent sensitivity.** The fee project uses `splitPercent: 6200` (62% of tokens go to reserved splits). If this value is wrong by even 100 basis points, the fee revenue distribution is permanently affected across the entire protocol. At $10M annual fee revenue, a 1% error redistributes ~$100k/year to wrong recipients. The split is set in `_makeRulesetConfigurations` and verified by the revnet deployer's stage validation — but the validation only checks format, not intent.
- **cashOutTaxRate sensitivity.** The fee project uses `cashOutTaxRate: 1000` (10%). This determines how much surplus is retained when token holders cash out. At 10%, cashing out 1M NANA tokens with 10M ETH surplus returns ~900k ETH equivalent. If the rate were accidentally set to 100 (1%), retention drops to ~10k ETH — a 90x difference in protocol surplus retention per cash-out.
- **Cross-reference: deploy-all-v6.** The fee project is ALSO configured in `deploy-all-v6`. The two scripts share the same economic parameters (splitPercent, cashOutTaxRate, issuanceCutFrequency, auto-issuance amounts) but intentionally differ in operator address: this script uses the Sphinx safe (`safeAddress()`), while `deploy-all-v6` uses a hardcoded multisig address. Only the economic parameters need to match between scripts. See [deploy-all-v6 RISKS.md](../deploy-all-v6/RISKS.md) section 5 for the full parameter risk analysis.

## 3. Project #1 Significance

This IS the fee project -- all protocol fees across the Juicebox ecosystem flow here. Maximum scrutiny on deployment parameters is warranted. This is a one-time deployment.

## 4. Post-Deployment Risks

Once deployed, the fee project's stage parameters are immutable (revnet design). Ongoing risks:

- **Terminal availability.** If the fee project's primary terminal is removed or becomes unavailable, all protocol fee payments (`_processFee` in `JBMultiTerminal`) fail. The try-catch in `_processFee` returns fees to originating projects — fees are silently forgiven, not lost. But sustained terminal unavailability means the protocol collects zero fees.
- **Terminal redirection risk persists after deployment.** Because the deploy script does not lock the fee project's terminal configuration, a later privileged directory change can redirect where ecosystem fees are paid without changing any downstream protocol code.
- **Sucker bridge liveness.** Cross-chain bridging via suckers depends on the fee project having a functioning sucker pair on each chain. A deprecated or bricked sucker on one chain isolates that chain's fee token holders.
- **Issuance decay compounding.** With 38% cut every 360 days, the fee project's issuance weight drops to ~1% of initial after ~10 years. Late contributors receive orders of magnitude fewer tokens per ETH. This is by design (early contributor premium) but means the fee project's token distribution is heavily front-loaded.
- **Split operator responsibility.** The operator (Sphinx Safe multisig) controls payout distribution. If the multisig loses quorum (key loss, signer unavailability), payouts cannot be triggered. Reserved tokens continue accumulating but cannot be distributed until the operator acts.

## 5. Accepted Behaviors

### 5.1 Historical stage anchoring is intentional

`NANA_START_TIME` is hardcoded and may already be in the past at deployment time, which means the first stage can
start retroactively and issuance decay can already be underway at launch. This is accepted because the fee project is
intended to share one canonical issuance schedule across chains rather than grant each deployment a fresh local epoch.
The tradeoff is that late deployments intentionally inherit the already-decaying schedule instead of restarting it.

## 6. Invariants to Verify

- Project #1 is owned by the REVDeployer (data hook pattern).
- All stage parameters match the intended configuration.
- Sucker pairs connect the correct chains.
- Auto-issuance amounts match expected per-chain distribution.
- Operator address is the Sphinx safe, not an individual.
- Fee project economic parameters match `deploy-all-v6` (splitPercent, cashOutTaxRate, issuanceCutFrequency, auto-issuance amounts). Operator addresses intentionally differ between scripts.
- The fee project's primary terminal accepts NATIVE_TOKEN on every deployed chain.
- The router-terminal registry address used during deployment is non-zero, resolves to deployed code, and is the second configured terminal for project `#1`.
- The intended router-terminal path is present and, if required by operations policy, terminal routing has been explicitly locked after deployment.
- After deployment, the fee project NFT is owned by REVDeployer (not the Sphinx Safe or any EOA).
