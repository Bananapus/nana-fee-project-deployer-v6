# nana-fee-project-deployer-v6 — Risks

## Trust Assumptions

1. **Sphinx Deployment** — Uses Sphinx for multi-chain atomic deployment. Sphinx proposal process controls execution.
2. **Operator Multisig** — The `safeAddress()` (Sphinx safe) receives operator role and split payouts. Compromise of the multisig = control of the fee project's splits and operations.
3. **Existing Deployments** — Script reads deployment addresses from other repos' deployment artifacts. If those artifacts are corrupted, deployment uses wrong addresses.
4. **REVDeployer** — Fee project is deployed as a revnet. All revnet trust assumptions apply (immutable stages, data hook behavior).

## Known Risks

| Risk | Description | Mitigation |
|------|-------------|------------|
| Hardcoded parameters | Stage configuration (issuance, splits, tax rate) is hardcoded | Parameters reviewed before deployment; immutable once deployed |
| Auto-issuance amounts | Pre-minted token amounts per chain are hardcoded | Carefully calculated to match expected distribution |
| Cross-chain ordering | Deployment must happen on all chains for suckers to connect | Sphinx handles multi-chain deployment atomically per phase |
| Single operator | All splits go to one operator address (multisig) | Multisig provides shared control |
| Project #1 significance | This IS the fee project — all protocol fees flow here | Maximum scrutiny on deployment parameters |

## Privileged Roles

| Role | Capabilities | Scope |
|------|-------------|-------|
| Sphinx safe (operator) | Receives split payouts, manages revnet operations | Project #1 |
| REVDeployer | Data hook for project #1 | Revnet behavior |

## Post-Deployment

Once deployed, the fee project's stage parameters are immutable (revnet design). The only ongoing operations are:
- Receiving protocol fees (automatic)
- Distributing payouts via splits (permissioned)
- Cross-chain bridging via suckers
