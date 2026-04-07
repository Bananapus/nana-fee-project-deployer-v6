# Juicebox Fee Project Deployer

`@bananapus/fee-project-deployer-v6` deploys Juicebox project `#1`, the protocol fee beneficiary. That project is economically important because protocol fees across the ecosystem ultimately route there.

Architecture: [ARCHITECTURE.md](./ARCHITECTURE.md)

## Overview

This repo is deployment-only. It packages the configuration for the fee project as a Revnet with router-terminal and sucker support so the protocol fee recipient is operational from the start.

The deployment sets up:

- the fee project's token and staged Revnet economics
- router terminal support for broader payment acceptance
- cross-chain sucker connectivity for the core supported networks
- auto-issuance allocations defined at deployment time

Use this repo when deploying or rehearsing protocol fee project `#1`. Do not treat it as a general-purpose Revnet deployer; that belongs in `revnet-core-v6`.

If the question is "how do Revnets work?" or "how do router terminals behave?" start in those repos first. This repo is mostly packaging a specific ecosystem-critical deployment.

## Key Script

| Script | Role |
| --- | --- |
| `script/Deploy.s.sol` | Canonical deployment entrypoint for fee project `#1`. |

## Mental Model

This repo owns one thing: the exact deployment shape of the protocol fee recipient project. Its importance comes from what it deploys, not from code volume.

## Development

```bash
npm install
forge build
forge test
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
- deployment ordering matters because fee-bearing paths expect the beneficiary project to exist
