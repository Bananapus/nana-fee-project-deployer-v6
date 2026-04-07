# Juicebox Fee Project Deployer

## Use This File For

- Use this file when the task is about deploying or rehearing protocol fee project `#1`, checking its project shape, or validating assumptions that the broader ecosystem makes about the fee beneficiary.
- Start here, then open the deploy script or focused tests that cover fee-project configuration and edge cases.

## Read This Next

| If you need... | Open this next |
|---|---|
| Repo overview and deployment intent | [`README.md`](./README.md), [`ARCHITECTURE.md`](./ARCHITECTURE.md) |
| Canonical deployment behavior | [`script/Deploy.s.sol`](./script/Deploy.s.sol) |
| Fork or edge validation | [`test/FeeProjectDeployerFork.t.sol`](./test/FeeProjectDeployerFork.t.sol), [`test/FeeProjectEdgeCases.t.sol`](./test/FeeProjectEdgeCases.t.sol), [`test/TestFeeProjectDeployer.sol`](./test/TestFeeProjectDeployer.sol) |

## Repo Map

| Area | Where to look |
|---|---|
| Scripts | [`script/`](./script/) |
| Tests | [`test/`](./test/) |

## Purpose

Deployment packaging for Juicebox fee project `#1`, the ecosystem-wide fee beneficiary. This repo matters because many fee-bearing flows assume that specific project exists and is configured correctly.

## Reference Files

- Open [`references/runtime.md`](./references/runtime.md) when you need the core assumptions this repo bakes into fee project `#1`.
- Open [`references/operations.md`](./references/operations.md) when you need deployment breadcrumbs, verification pointers, or the common stale assumptions around fee-project shape and ordering.

## Working Rules

- Start in [`script/Deploy.s.sol`](./script/Deploy.s.sol). This repo is packaging, not a general-purpose protocol module.
- Treat project `#1` assumptions as ecosystem-critical. Small configuration mistakes here ripple widely.
- When debugging behavior, confirm whether the source is this deployment shape or a downstream revnet/router/sucker repo it composes.
