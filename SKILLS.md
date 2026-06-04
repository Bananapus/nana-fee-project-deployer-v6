# Juicebox Fee Project Deployer

## Use this file for

- Use this file when the task involves deploying or reviewing protocol fee project `#1`.
- Start here, then decide whether the issue is in deployment packaging, cross-chain parity, or the runtime repo this deployer wires together.

## Read this next

| If you need... | Open this next |
|---|---|
| Repo overview and deployment shape | [`README.md`](./README.md), [`ARCHITECTURE.md`](./ARCHITECTURE.md) |
| Per-repo scoped invariants | [`INVARIANTS.md`](./INVARIANTS.md) |
| Main deployment script | [`script/Deploy.s.sol`](./script/Deploy.s.sol) |
| Main tests | [`test/TestFeeProjectDeployer.sol`](./test/TestFeeProjectDeployer.sol), [`test/FeeProjectEdgeCases.t.sol`](./test/FeeProjectEdgeCases.t.sol), [`test/FeeProjectDeployerFork.t.sol`](./test/FeeProjectDeployerFork.t.sol) |
| Underlying revnet deployer | [`../revnet-core-v6/src/REVDeployer.sol`](../revnet-core-v6/src/REVDeployer.sol) |

## Purpose

Single-purpose deployment package for the canonical protocol fee project.

## Working rules

- Start in [`script/Deploy.s.sol`](./script/Deploy.s.sol).
- Treat deployment parameters as economic policy, not boilerplate.
- Compare this repo's economic settings with `deploy-all-v6` where they are expected to match.
- Remember that directory terminal locking is a separate post-deploy step.
