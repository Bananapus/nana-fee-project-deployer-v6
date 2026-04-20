# User Journeys

## Repo Purpose

This repo packages the canonical deployment of fee project `#1`.
It is deployment packaging, not the long-lived runtime logic. Once the project is live, the important behavior mostly
belongs to [revnet-core-v6](../revnet-core-v6/USER_JOURNEYS.md) and the integrated sibling repos it wires together.

## Primary Actors

- protocol operators deploying fee project `#1`
- reviewers checking that the fee sink exists before the broader ecosystem rollout
- engineers rehearsing the packaged deployment on forks or testnets

## Key Surfaces

- `script/Deploy.s.sol`: deploys fee project `#1` with its packaged Revnet and auxiliary integrations
- `test/TestFeeProjectDeployer.sol`: highest-signal deployment-shape regression coverage
- `test/FeeProjectEdgeCases.t.sol`: covers issuance decay, fee-project cash-out behavior, and fee-terminal failure handling

## Journey 1: Deploy The Fee Project

**Actor:** protocol operator.

**Intent:** create project `#1` in the exact packaged shape other V6 repos assume.

**Preconditions**
- the target chain does not already have the intended fee project deployment
- sibling-package artifacts and addresses are current
- the operator understands this repo deploys a composed project, not a bare core treasury

**Main Flow**
1. Run `script/Deploy.s.sol` with the environment and artifact inputs it expects.
2. The script deploys the fee project as a packaged Revnet rather than an ad hoc Juicebox project.
3. Router, sucker, token, and auto-issuance configuration are installed as part of the same deployment shape.
4. The script approves the Revnet deployer for project `#1` and expects that canonical ID to be available for this rollout.

**Failure Modes**
- sibling artifacts drift from the versions this script expects
- the operator treats project `#1` as a generic deploy target rather than a canonical dependency
- the chain already consumed project ID `1` for something else or the deployer approval points at the wrong address
- the operator misses that `NANA_START_TIME` is historical, so issuance decay may already be underway at deployment
- downstream packages later point at the wrong addresses

**Postconditions**
- project `#1` exists in the exact packaged deployment shape this repo defines, subject to later validation

## Journey 2: Validate The Deployment Before Treating The Ecosystem As Live

**Actor:** reviewer or deployment lead.

**Intent:** confirm that project `#1` is the expected fee sink before other repos depend on it.

**Preconditions**
- deployment has completed
- the team has expected addresses and runtime assumptions to compare against

**Main Flow**
1. Run the repo's tests and compare the deployed shape against the expected config.
2. Confirm stage settings, issuance behavior, and auxiliary integrations match the intended deployment.
3. Confirm ecosystem assumptions about project `#1` actually match the deployment outputs.
4. Confirm the configured operator, split percent, cash-out tax rate, and auto-issuance amounts match the intended economic schedule.
5. Confirm the accepted terminals are the intended ones and decide whether post-deploy terminal locking is required by operations policy.
6. Only then let other packages assume fee project `#1` is ready.

**Failure Modes**
- tests pass locally but artifact imports still point at stale sibling deployments
- reviewers check the deploy script but not the resulting project shape
- reviewers verify formatting but not economic intent, so a wrong `splitPercent` or `cashOutTaxRate` ships anyway
- teams assume router and terminal acceptance is locked when the directory can still be changed later by privileged actors
- other repos are configured before this deployment is trusted

**Postconditions**
- the team has either accepted the deployment as the canonical fee sink or blocked broader ecosystem rollout

## Journey 3: Rehearse The Fee Project Deployment On Testnets Or Forks

**Actor:** engineer or release manager.

**Intent:** exercise the exact fee-project packaging before deploying it for real.

**Preconditions**
- fork or testnet dependencies mirror the intended production topology closely enough to be useful

**Main Flow**
1. Run the deployment flow in rehearsal environments.
2. Watch imported addresses from sibling repos closely because this package is mostly composition.
3. Verify late deployment still produces the intended historical issuance schedule rather than a fresh local epoch.
4. Treat dependency drift as a blocker even if the local deploy script still executes.

**Postconditions**
- the team has higher confidence that project `#1` will land in the expected shape
- runtime questions should now move to the underlying runtime repos rather than this package

## Trust Boundaries

- this repo trusts sibling-package artifacts and deployment scripts more than it defines standalone runtime logic
- this repo hardcodes economically sensitive values for the canonical fee sink, so review must distinguish "script ran" from "correct fee schedule shipped"
- the deployed fee project's ongoing behavior belongs to the runtime repos it composes, especially Revnet

## Hand-Offs

- Use [revnet-core-v6](../revnet-core-v6/USER_JOURNEYS.md) for the staged economic behavior the deployed fee project will actually run.
- Use [deploy-all-v6](../deploy-all-v6/USER_JOURNEYS.md) if the operational question is about the entire ecosystem rollout rather than project `#1` specifically.
