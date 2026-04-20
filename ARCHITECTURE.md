# Architecture

## Purpose

`nana-fee-project-deployer-v6` deploys the canonical fee-beneficiary project, expected to be project `#1`. Its surface is small, but many protocol paths assume that project exists and is configured exactly as this repo expects.

## System Overview

This is a deployment-only repo. `script/Deploy.s.sol` resolves already-deployed protocol addresses, assembles the fee project's runtime configuration, and launches it through downstream deployers. The deployed project's runtime behavior comes from `revnet-core-v6`, `nana-router-terminal-v6`, and `nana-suckers-v6`, not from contracts defined here.

## Core Invariants

- Project `#1` must exist before any fee-paying path expects to route protocol fees there.
- The chosen stage configuration and auto-issuance settings become economically significant immediately after deployment.
- This repo has no independent runtime contract surface; all long-lived behavior comes from the downstream contracts it configures.
- The script must resolve the intended predeployed addresses, not merely any non-zero addresses of the right type.
- Address resolution in this repo must stay aligned with `deploy-all-v6` and downstream deployer expectations.

## Modules

| Module | Responsibility | Notes |
| --- | --- | --- |
| `script/Deploy.s.sol` | Builds and launches the canonical fee project | Main deployment path |
| `test/` | Verifies deployment assumptions and edge cases | Main safety net |

## Trust Boundaries

- This repo does not define runtime protocol behavior.
- It is trusted for selecting the right downstream addresses and the right launch-time parameters.
- Its configuration is tightly coupled to the deployment order in `deploy-all-v6`.

## Critical Flows

### Deploy Fee Project

```text
operator
  -> runs Deploy.s.sol
  -> script resolves already-deployed core and product addresses
  -> script assembles the fee project's revnet-style configuration
  -> downstream deployers launch the canonical fee project
```

## Accounting Model

No accounting lives in this repo. Its economic impact is configuration-driven: a bad deployment here instantiates the wrong fee sink for the ecosystem.

## Security Model

- The main risk is stale configuration, not local code complexity.
- The absence of local runtime code does not make this repo low-impact; a bad launch here misconfigures the ecosystem-wide fee sink.
- Downstream constructor or deployer changes can silently invalidate this repo's assumptions.

## Safe Change Guide

- Treat configuration edits as protocol-level economic changes.
- Revisit this repo whenever downstream deployer surfaces or canonical addresses change.
- If the fee project's expected integrations change, update this doc and `references/runtime.md` in the same change set.
- Keep fork and edge-case tests meaningful; they are the main proof that the deployment assumptions still hold.

## Canonical Checks

- canonical fee-project deployment on realistic chain state:
  `test/FeeProjectDeployerFork.t.sol`
- configuration-edge validation and launch assumptions:
  `test/FeeProjectEdgeCases.t.sol`
- issuance timing drift on late deployment:
  `test/audit/LateStartTime.t.sol`

## Source Map

- `script/Deploy.s.sol`
- `test/FeeProjectDeployerFork.t.sol`
- `test/FeeProjectEdgeCases.t.sol`
- `test/audit/LateStartTime.t.sol`
- `test/TestFeeProjectDeployer.sol`
- `references/runtime.md`
- `references/operations.md`
