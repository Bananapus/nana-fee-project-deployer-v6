# Architecture

## Purpose

`nana-fee-project-deployer-v6` exists to deploy project `#1`, the protocol fee beneficiary. That makes this repo more important than its small code surface suggests: a large part of the ecosystem assumes project `#1` exists and is correctly configured.

## Boundaries

- This repo is deployment-only. It does not introduce new runtime contracts.
- The runtime behavior of the deployed fee project comes from `revnet-core-v6`, `nana-router-terminal-v6`, and `nana-suckers-v6`.
- The repo owns the specific configuration for the canonical fee project, not the generic revnet machinery.

## Main Components

| Component | Responsibility |
| --- | --- |
| `script/Deploy.s.sol` | Builds the fee project configuration and launches it via downstream deployers |
| tests | Verify the script's configuration and integration assumptions |

## Deployment Model

```text
deployment script
  -> resolves already-deployed protocol addresses
  -> builds the revnet configuration for project #1
  -> configures terminals, auto-issuances, and cross-chain suckers
  -> launches the fee project that receives ecosystem fees
```

## Critical Invariants

- Project `#1` must exist before any protocol path that pays fees expects to use it.
- Stage configuration and auto-issuance amounts are effectively permanent once deployed.
- The script's address-resolution assumptions must stay aligned with the canonical deployment order in `deploy-all-v6`.

## Where Complexity Lives

- The repo is small, but its correctness depends on many external assumptions being true at once.
- The main risk is stale configuration, not internal code complexity.

## Dependencies

- `revnet-core-v6` for the deployed project model
- `nana-router-terminal-v6` and `nana-suckers-v6` for runtime features
- `deploy-all-v6` for address and sequencing expectations

## Safe Change Guide

- Treat configuration changes as protocol-level economic changes, not script refactors.
- If a downstream constructor or deployer surface changes, revisit this script immediately.
- Keep fork tests meaningful; this repo's value is mostly in proving that the deployment assumptions still hold.
