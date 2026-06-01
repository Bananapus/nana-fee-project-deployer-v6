# Changelog

## 0.0.34 — Document NatSpec, comment, and lint conventions in STYLE_GUIDE

- `STYLE_GUIDE.md`: made the existing documentation conventions explicit — expanded the NatSpec section to spell out the required tags for every member kind, added a Comments section describing how inline comments explain the WHY of each block and stay framed around current behavior, and expanded the Linting section to describe the zero-notes build-and-test bar and the standalone disable-directive rule.
- Dependency floors: an attempt to raise the dependency caret floors to the latest published versions was held back because the latest `@croptop/core-v6` adds a constructor parameter to `CTPublisher` that the deploy test harness does not yet pass, so the floors remain unchanged in this release.

## 0.0.33 — Fix canonical-shape ownership check so re-runs are idempotent

- `script/Deploy.s.sol`: the canonical-shape check now compares the fee project's NFT owner against the `REVOwner` contract (`revnet.owner`) instead of the basic deployer (`revnet.basicDeployer`). `REVDeployer.deployFor` permanently forwards the project NFT to `REVOwner` at the end of a deploy, so the old comparison never matched a real deployment and a re-run against an already-deployed fee project reverted `DeployScript_FeeProjectNotCanonical` instead of cleanly recognizing the project as canonical and no-op'ing.
- Regression coverage (`test/regression/RegressionCanonicalGuard.t.sol`): the harness and its stub now reflect the real post-deploy owner (`REVOwner`); added coverage that a fee project owned by `REVOwner` is recognized as canonical and that one still owned by the deployer is rejected.
- Fork coverage (`test/FeeProjectDeployerFork.t.sol`): added a test that runs the real deploy path and asserts the project NFT rests at `REVOwner`, not the deployer.
- Docs (`INVARIANTS.md`, `README.md`): corrected the post-deploy NFT-ownership references to `REVOwner`.

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
