# RISKS.md -- nana-fee-project-deployer-v6

## 1. Trust Assumptions

- **Sphinx Deployment.** Uses Sphinx for multi-chain atomic deployment. Sphinx proposal process controls execution.
- **Operator Multisig.** The `safeAddress()` (Sphinx safe) receives operator role and split payouts. Compromise of the multisig = control of the fee project's splits and operations.
- **Existing Deployments.** Script reads deployment addresses from other repos' deployment artifacts. If those artifacts are corrupted, deployment uses wrong addresses.
- **REVDeployer.** Fee project is deployed as a revnet. All revnet trust assumptions apply (immutable stages, data hook behavior).
- **Project #1 Approval.** The script calls `core.projects.approve(revnet.basic_deployer, FEE_PROJECT_ID)` to authorize the deployer. If the wrong deployer address is approved, it could configure the fee project maliciously.

## 2. Configuration Risks

- **Hardcoded parameters.** Stage configuration (issuance, splits, tax rate, start time) is hardcoded in the script. Any error is permanent once deployed. Parameters must be reviewed exhaustively before deployment.
- **Auto-issuance amounts.** Pre-minted token amounts per chain are hardcoded constants (NANA_MAINNET_AUTO_ISSUANCE, etc.). Calculated to match expected distribution.
- **Start time.** `NANA_START_TIME` is hardcoded. If deployment occurs after this timestamp, the revnet stage starts retroactively.
- **L2 sucker deployer fallback chain.** On L2s, the script falls back through `optimismDeployer > baseDeployer > arbitrumDeployer`. If the wrong deployer is selected, suckers connect to the wrong L1 endpoint. Reverts if no deployer is found.
- **Single operator.** All splits direct 100% of payouts to one operator address (the multisig).

## 3. Project #1 Significance

This IS the fee project -- all protocol fees across the Juicebox ecosystem flow here. Maximum scrutiny on deployment parameters is warranted. This is a one-time deployment.

## 4. Post-Deployment

Once deployed, the fee project's stage parameters are immutable (revnet design). The only ongoing operations are:
- Receiving protocol fees (automatic)
- Distributing payouts via splits (permissioned to operator)
- Cross-chain bridging via suckers
- Issuance decay over time (38% cut every 360 days)

## 5. Invariants to Verify

- Project #1 is owned by the REVDeployer (data hook pattern).
- All stage parameters match the intended configuration.
- Sucker pairs connect the correct chains.
- Auto-issuance amounts match expected per-chain distribution.
- Operator address is the Sphinx safe, not an individual.
