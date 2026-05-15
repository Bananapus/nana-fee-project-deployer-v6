# Changelog

## 0.0.24 — Bump v6 deps to nana-core-v6 0.0.53 cohort

- `@bananapus/core-v6`: `^0.0.49 → ^0.0.53` ([PR #145](https://github.com/Bananapus/nana-core-v6/pull/145)).
- `@bananapus/721-hook-v6`: `^0.0.49 → ^0.0.50`.
- `@bananapus/buyback-hook-v6`: `^0.0.45 → ^0.0.46`.
- `@bananapus/suckers-v6`: `^0.0.43 → ^0.0.46`.
- All `JBRulesetMetadata` literals (src + test) patched to include `pauseCrossProjectFeeFreeInflows: false`.

## Scope

This file describes the verified change from `nana-fee-project-deployer-v5` to the current `nana-fee-project-deployer-v6` repo.

## Current v6 surface

- `script/Deploy.s.sol`

## Summary

- The deployment flow now assumes the router-terminal ecosystem instead of the old swap-terminal one.
- Sucker-related deployment inputs follow the v6 remote-token model, which means the surrounding config assumptions moved with `nana-suckers-v6`.
- This repo remains deployment-oriented rather than ABI-heavy, but its wiring changed because the downstream protocol packages changed.
- The repo moved from the v5 Solidity baseline to `0.8.28`.

## Verified deltas

- The v5 script imported `SwapTerminalDeploymentLib`; the current script imports `RouterTerminalDeploymentLib`.
- The current deploy script encodes the remote native token as `bytes32(uint256(uint160(JBConstants.NATIVE_TOKEN)))` instead of using the old raw-address field.
- The old `minBridgeAmount` field is gone from the current script's token-mapping construction.

## Breaking ABI changes

- This repo is still deployment-script-oriented rather than a contract ABI target.
- The meaningful break is in the config objects it constructs for downstream v6 repos: router-terminal inputs, bytes32 remote-token encoding, and the absence of v5 loan/buyback-hook config shape.

## Indexer impact

- None directly from this repo's own runtime surface.
- Deployment wrappers that mirror this script need to update their config serialization and downstream ABI expectations.

## Migration notes

- If you wrap or mirror this deploy script, rebuild its config inputs from the current downstream v6 packages.
- Do not port old swap-terminal assumptions forward. The deployment surface now targets router-terminal-era components.
