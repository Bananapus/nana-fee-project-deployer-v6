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

## Fee Collection Context

Project #1 is the protocol's fee sink. In `JBMultiTerminal`, the constant `_FEE_BENEFICIARY_PROJECT_ID` is hardcoded to `1`. Every terminal operation that incurs a fee (payouts to addresses outside the ecosystem, cash-outs) sends 2.5% (`FEE = 25` out of `MAX_FEE = 1000`) to project #1 via an internal `pay` call. Fees can be held for up to 28 days before processing, giving the paying project a window to reclaim them, but once processed they flow into project #1's balance as regular payments — minting NANA tokens for the fee payer as a side effect.

This deployer exists to configure project #1 as a revnet so those fee revenues are governed by immutable on-chain rules rather than a multisig.

## Design Decisions

**Initial issuance (10,000 NANA per ETH):** Sets the starting token price. A round number provides a simple mental model for early participants — 1 ETH buys exactly 10,000 NANA.

**Issuance cut (38% per 360 days):** Each 360-day cycle, the number of tokens minted per ETH drops by 38%. This creates steady deflationary pressure on new issuance, rewarding earlier participants while keeping the rate moderate enough that the project remains attractive to new contributors over multiple cycles.

**Split to operator (62%):** 62% of all newly minted tokens go to the split operator (the multisig). This funds ongoing protocol development and ecosystem growth. The remaining 38% goes to the payer, giving fee contributors meaningful NANA exposure.

**Cash-out tax (10%):** A 10% tax on cash-outs (`cashOutTaxRate = 1000` out of `MAX_CASH_OUT_TAX_RATE = 10000`) creates a mild incentive to hold rather than immediately redeem, while still allowing relatively cheap exits. This keeps the treasury stable without locking participants in.

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
