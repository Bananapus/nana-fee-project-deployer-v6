# User Journeys

## Who This Repo Serves

- operators deploying Juicebox fee project `#1`
- reviewers validating that the ecosystem's fee beneficiary is configured correctly before broader rollout
- teams rehearsing fee-project deployment on testnets or forks

## Journey 1: Deploy The Fee Project

**Starting state:** the ecosystem is not live yet or fee project `#1` does not exist on the target chain set.

**Success:** the protocol fee beneficiary project is deployed with its intended Revnet, router terminal, and sucker configuration.

**Flow**
1. Run `script/Deploy.s.sol` with the environment and artifact inputs it expects.
2. The script deploys the fee project as a packaged Revnet rather than a bare Juicebox project.
3. Router-terminal support, cross-chain sucker support, and auto-issuance allocations are installed as part of that one deployment.

## Journey 2: Validate The Deployment Before Treating The Ecosystem As Live

**Starting state:** project `#1` has been deployed but fee-bearing paths should not rely on it yet.

**Success:** the deployment is known to match the intended configuration and dependent repos can safely point at it.

**Flow**
1. Run the repo's deployer, edge, and fork tests against the target assumptions.
2. Confirm the fee project's stage settings, issuance behavior, and auxiliary integrations match the expected deployment shape.
3. Only then let the rest of the ecosystem assume project `#1` exists as the fee sink.

## Journey 3: Rehearse The Fee Project Deployment On Testnets Or Forks

**Starting state:** the team wants confidence before touching the production chain set.

**Success:** the exact packaged deployment for project `#1` has been exercised under realistic conditions.

**Flow**
1. Use the repo's deployment scripts and fork coverage to simulate the rollout.
2. Pay attention to addresses imported from sibling repos because this package is mostly packaging, not isolated logic.
3. Treat drift in those dependencies as a deployment blocker even if the local script still runs.

## Hand-Offs

- Use [revnet-core-v6](../revnet-core-v6/USER_JOURNEYS.md) for the staged economic behavior the deployed fee project will actually run.
- Use [deploy-all-v6](../deploy-all-v6/USER_JOURNEYS.md) if the operational question is about the entire ecosystem rollout rather than project `#1` specifically.
