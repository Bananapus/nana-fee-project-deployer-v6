# Fee Project Runtime

## Core Role

- [`script/Deploy.s.sol`](../script/Deploy.s.sol) packages the fee project's Revnet, routing, and sucker assumptions into the canonical deployment for project `#1`.

## High-Risk Areas

- Ecosystem assumption drift: many repos assume project `#1` exists and is shaped correctly.
- Stage and issuance configuration: mistakes are expensive because the fee beneficiary is global.
- Deployment ordering: fee-bearing paths expect this project to exist before broader ecosystem activity.

## Tests To Trust First

- [`test/FeeProjectDeployerFork.t.sol`](../test/FeeProjectDeployerFork.t.sol) for live assumptions.
- [`test/FeeProjectEdgeCases.t.sol`](../test/FeeProjectEdgeCases.t.sol) and [`test/TestFeeProjectDeployer.sol`](../test/TestFeeProjectDeployer.sol) for deployment-shape edge cases.
