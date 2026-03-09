# nana-fee-project-deployer-v6 — Architecture

## Purpose

Deployment script for Juicebox V6's fee project (project #1). This is the NANA revnet — the project that receives protocol fees (2.5%) from all Juicebox V6 operations. Uses Sphinx for multi-chain atomic deployments.

## Contract Map

```
script/
└── Deploy.s.sol — Sphinx deployment script for the NANA fee project
```

There is no `src/` directory. This repo exists solely to deploy project #1 as a revnet.

## What It Deploys

The script deploys project #1 (the NANA fee project) as a revnet via `REVDeployer.deployFor()` with:

- **Token:** NANA (ERC-20)
- **Base currency:** ETH
- **Single stage:** 62% split to operator, 38% issuance cut per 360 days, 10% cash-out tax
- **Initial issuance:** 10,000 tokens per ETH
- **Multi-chain:** Ethereum, Optimism, Base, Arbitrum
- **Auto-issuance:** Pre-minted tokens distributed across 4 chains to operator multisig
- **Terminal config:** JBMultiTerminal (native token) + JBRouterTerminal
- **Cross-chain:** Sucker deployments for OP, Base, and Arbitrum bridges

## Deployment Flow

```
Sphinx proposal → Deploy.deploy()
  → Load existing core, sucker, revnet, router-terminal deployments
  → Configure accounting contexts (native token, 18 decimals)
  → Configure terminals (multi-terminal + router-terminal)
  → Define stage: issuance, splits, cash-out tax, sucker permission
  → Define auto-issuances per chain (mainnet, base, OP, arbitrum)
  → Define sucker deployments (OP, Base, Arbitrum deployers)
  → Approve REVDeployer for project #1
  → Call REVDeployer.deployFor(projectId=1, ...)
```

## Dependencies
- `@bananapus/core-v6` — Core protocol deployment libraries
- `@bananapus/suckers-v6` — Sucker deployment libraries
- `@rev-net/core-v6` — Revnet deployment libraries
- `@bananapus/router-terminal-v6` — Router terminal deployment libraries
- `@bananapus/721-hook-v6` — 721 hook (transitive)
- `@bananapus/ownable-v6` — Ownership (transitive)
- `@bananapus/permission-ids-v6` — Permission constants (transitive)
- `@openzeppelin/contracts` — Standard utilities
