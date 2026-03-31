# User Journeys

## Who This Repo Serves

- protocol operators deploying project `#1`
- maintainers validating that the ecosystem's fee sink is configured correctly
- auditors reviewing the assumptions around the canonical fee beneficiary

## Journey 1: Deploy The Fee Project

**Starting state:** the core protocol, revnet deployer, suckers, and router terminal artifacts for the target chains are already known.

**Success:** project `#1` exists as the fee recipient revnet for the ecosystem.

**Flow**
1. Load the deployment addresses the script depends on.
2. Approve the revnet deployer to configure the fee project.
3. Run `script/Deploy.s.sol` with the baked-in NANA fee-project configuration.
4. The script deploys project `#1` as a revnet with its router terminal and cross-chain sucker setup.

## Journey 2: Validate The Deployment Before Treating The Ecosystem As Live

**Starting state:** the deployment script has completed.

**Success:** maintainers are confident that protocol fees now have a valid destination.

**Flow**
1. Confirm that project `#1` exists and the expected terminals are wired.
2. Confirm the revnet stage parameters match the intended issuance, split, and cash-out settings.
3. Confirm the cross-chain auto-issuance and sucker wiring match the intended chains.
4. Treat any mismatch as a blocker for further ecosystem deployment because all fees point here.

**Why this matters:** the broader protocol assumes project `#1` is real. If it is wrong, the mistake propagates everywhere.

## Hand-Offs

- Use [revnet-core-v6](../revnet-core-v6/USER_JOURNEYS.md) for the runtime behavior of the deployed fee revnet.
- Use [deploy-all-v6](../deploy-all-v6/USER_JOURNEYS.md) if this deployment is part of a full-stack rollout.
