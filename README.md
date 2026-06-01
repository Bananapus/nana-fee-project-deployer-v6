# Juicebox Fee Project Deployer

`@bananapus/fee-project-deployer-v6` deploys Juicebox project `#1`, the intended V6 protocol fee beneficiary. That project is economically important because many protocol fee flows in the workspace assume it exists and route there.

## Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) — architecture overview
- [USER_JOURNEYS.md](./USER_JOURNEYS.md) — user journeys
- [SKILLS.md](./SKILLS.md) — skills reference
- [RISKS.md](./RISKS.md) — risk surface
- [INVARIANTS.md](./INVARIANTS.md) — invariants this repo guarantees
- [ADMINISTRATION.md](./ADMINISTRATION.md) — administration playbook
- [AUDIT_INSTRUCTIONS.md](./AUDIT_INSTRUCTIONS.md) — audit instructions
- [STYLE_GUIDE.md](./STYLE_GUIDE.md) — code style conventions
- [CHANGELOG.md](./CHANGELOG.md) — release notes

## Overview

This repo is deployment-only. It packages the configuration for the fee project as a Revnet with router-terminal and sucker support so the protocol fee recipient is configured from the start.

The deployment sets up:

- the fee project's token and staged Revnet economics
- router terminal support for broader payment acceptance
- chain-specific sucker connectivity for the supported chain set
- auto-issuance allocations defined at deployment time

Use this repo when deploying or rehearsing protocol fee project `#1`. Do not treat it as a general-purpose Revnet deployer. That belongs in `revnet-core-v6`.

If the question is "how do Revnets work?" or "how do router terminals behave?" start in those repos first. This repo mostly packages one ecosystem-critical deployment.

## Key Script

| Script | Role |
| --- | --- |
| `script/Deploy.s.sol` | Primary deployment entrypoint for fee project `#1`. |

## Mental Model

This repo owns one thing: the exact deployment shape of the protocol fee recipient project. Its importance comes from what it deploys, not from code volume.

## Read These Files First

1. `script/Deploy.s.sol`
2. `test/TestFeeProjectDeployer.sol`
3. `revnet-core-v6/src/REVDeployer.sol`

## High-Signal Tests

1. `test/TestFeeProjectDeployer.sol`
2. `test/FeeProjectEdgeCases.t.sol`
3. `test/FeeProjectDeployerFork.t.sol`
4. `test/regression/LateStartTime.t.sol`

## Integration Traps

- this repo is mostly packaging, so many runtime assumptions live in sibling repos it composes
- fee-project deployment order matters because other packages may assume project `#1` already exists
- replay/idempotence checks must only skip when an existing project `#1` matches the exact NANA fee-project shape
- the canonical-shape ownership check compares against the `REVOwner` contract (`revnet.owner`), because `REVDeployer.deployFor` forwards the project NFT there at the end of a deploy — not the basic deployer, which only holds the NFT transiently
- all chains in a deployment set must write matching auto-issuance entries so the resulting ruleset hash stays aligned
- terminal selection is configured during deployment but not directory-locked here
- misconfigured stages or auto-issuance settings can be operationally wrong even if they compile and deploy cleanly

## Where State Lives

- deployment orchestration: `script/Deploy.s.sol`
- runtime fee-project state: the core, revnet, router-terminal, and sucker surfaces this repo wires together
- assumptions about project `#1`: across the wider ecosystem, not only in this repo

## Install

```bash
npm install @bananapus/fee-project-deployer-v6
```

## Development

```bash
npm install
forge build --deny notes --skip "*/test/**" --skip "*/script/**"
forge test --deny notes
```

Useful scripts:

- `npm run deploy:mainnets`
- `npm run deploy:testnets`

## Deployment Notes

This repo depends on addresses and artifacts from the core, router terminal, sucker, ownable, 721, and revnet packages. It should be deployed before broader fee-bearing protocol activity is expected.

## Repository Layout

```text
script/
  Deploy.s.sol
test/
  deployer, edge, and fork coverage
```

## Risks And Notes

- the fee project configuration is effectively permanent once deployed and referenced by the ecosystem
- incorrect auto-issuance or stage settings are costly because project `#1` is a global assumption
- cross-chain rule configuration drift is dangerous because chain-set auto-issuance entries are expected to hash identically
- deployment ordering matters because fee-bearing paths expect the beneficiary project to exist
- terminal routing remains mutable until an operator locks it in the directory

## For AI Agents

- Treat this repo as a deployment package for one ecosystem-critical project shape, not as a reusable protocol primitive.
- If a question is about runtime economics after deployment, move to `revnet-core-v6`, `nana-router-terminal-v6`, or `nana-suckers-v6`.
