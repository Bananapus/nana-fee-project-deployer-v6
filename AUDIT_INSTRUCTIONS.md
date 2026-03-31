# Audit Instructions

This repo deploys the canonical protocol fee project. The runtime surface is small, but mistakes here affect where ecosystem fees ultimately land.

## Objective

Find issues that:
- deploy the fee project with incorrect ownership, rulesets, terminals, or hook wiring
- leave project `#1` misconfigured relative to the rest of the ecosystem
- route protocol fees to the wrong beneficiary or treasury surface
- create a deployment that is not idempotent or safe to replay

## Scope

In scope:
- deployment logic and scripts in this repo
- any helper contracts or script-side configuration used to create the fee project
- associated tests

The main security question is not novel contract logic. It is whether the fee project is created exactly as the rest of the ecosystem expects.

## Critical Invariants

1. The fee project is the intended canonical recipient
Core fee-processing paths elsewhere in the ecosystem must point at the project this repo deploys.

2. Ownership and permissions are correct
No deployment helper should retain administrative power after setup unless the design explicitly requires it.

3. Economics match assumptions
Rulesets, terminals, and hooks for the fee project must match the behavior other repos assume when forwarding protocol fees.

## Threat Model

Prioritize:
- stale deployment constants
- missing ownership transfer
- accidental duplicate deployment
- mismatch between expected project ID and actual created project

## Build And Verification

Standard workflow:
- `npm install`
- `forge build`
- `forge test`

Useful findings here show that protocol fees can be redirected, trapped, or rendered inconsistent with what `nana-core-v6` and `deploy-all-v6` expect.
