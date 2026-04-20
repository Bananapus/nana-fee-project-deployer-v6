# Audit Instructions

This repo deploys the canonical protocol fee project. The runtime surface is small, but mistakes here affect where ecosystem fees ultimately land.

## Audit Objective

Find issues that:
- deploy the fee project with incorrect ownership, rulesets, terminals, or hook wiring
- leave project `#1` misconfigured relative to the rest of the ecosystem
- route protocol fees to the wrong beneficiary or treasury surface
- create a deployment that is not idempotent or safe to replay

## Scope

In scope:
- `script/Deploy.s.sol`
- tests under `test/`
- operational references under `references/`

The main security question is not novel contract logic. It is whether the fee project is created exactly as the rest of the ecosystem expects.

## Start Here

1. `script/Deploy.s.sol`
2. `references/runtime.md`
3. `references/operations.md`

## Security Model

This repo is deployment-critical, not runtime-complex.
- it creates the canonical fee project other repos expect to exist
- project identity, owner, rulesets, terminal configuration, and hook wiring must all match ecosystem assumptions
- replay and idempotency matter because deployment may be repeated or composed into larger flows

## Roles And Privileges

| Role | Powers | How constrained |
|------|--------|-----------------|
| Deploy script caller | Create the canonical fee project | Must not retain lingering control |
| Fee project owner | Govern the fee sink after deployment | Must match ecosystem expectations |

## Integration Assumptions

| Dependency | Assumption | What breaks if wrong |
|------------|------------|----------------------|
| `nana-core-v6` | Protocol fees target this canonical project | Fees route to the wrong destination |
| `deploy-all-v6` | Full rollout expects the same project identity and wiring | Ecosystem deployment appears healthy but is inconsistent |

## Critical Invariants

1. The fee project is the intended canonical recipient
Core fee-processing paths elsewhere in the ecosystem must point at the project this repo deploys.

2. Ownership and permissions are correct
No deployment helper should retain administrative power after setup unless the design explicitly requires it.

3. Economics match assumptions
Rulesets, terminals, and hooks for the fee project must match the behavior other repos assume when forwarding protocol fees.

## Attack Surfaces

- stale deployment constants or references
- ownership transfer and permission setup
- accidental duplicate deployment or non-idempotent replay
- mismatch between expected project ID and the actual deployed project

## Verification

- `npm install`
- `forge build`
- `forge test`
