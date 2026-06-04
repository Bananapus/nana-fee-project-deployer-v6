# Changelog

## 0.0.35 — Raise dependency floors to the latest published cohort

- `package.json`: raised every dependency caret floor to its latest published version — `@bananapus/core-v6` `^0.0.72 → ^0.0.79`, `@rev-net/core-v6` `^0.0.78 → ^0.0.84`, `@croptop/core-v6` `^0.0.60 → ^0.0.64`, `@bananapus/router-terminal-v6` `^0.0.56 → ^0.0.60`, `@bananapus/suckers-v6` `^0.0.61 → ^0.0.67`, `@bananapus/721-hook-v6` `^0.0.59 → ^0.0.65`, `@bananapus/buyback-hook-v6` `^0.0.59 → ^0.0.66`, `@bananapus/address-registry-v6` `^0.0.29 → ^0.0.33`, and `@bananapus/permission-ids-v6` `^0.0.27 → ^0.0.29`. Added `@bananapus/ownable-v6` `^0.0.36` as an explicit dev dependency so the resolved copy keeps pace with what the bumped `@croptop/core-v6` and `@rev-net/core-v6` expect.
- `@croptop/core-v6` `0.0.64` adds a `permit2` argument to the `CTPublisher` constructor (inserted ahead of `trustedForwarder`). The two deploy test harnesses (`test/FeeProjectDeployerFork.t.sol`, `test/FeeProjectEdgeCases.t.sol`) now pass the canonical Permit2 address through that argument so they keep building against the new constructor shape.

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

## v5 to v6 migration

The verified v5 → v6 delta for this repo. The runtime surface is a deploy script, so the breaks live in the config objects it constructs for downstream v6 packages rather than in a contract ABI.

### Scope

This section describes the verified change from `nana-fee-project-deployer-v5` to `nana-fee-project-deployer-v6`.

### v6 surface

- `script/Deploy.s.sol`

### Summary

- The deployment flow targets the router-terminal ecosystem in place of the v5 swap-terminal one.
- Sucker-related deployment inputs follow the v6 remote-token model, so the surrounding config assumptions moved with `nana-suckers-v6`.
- The repo stays deployment-oriented rather than ABI-heavy, but its wiring tracks the downstream protocol packages it composes.
- The repo targets Solidity `0.8.28`.

### Verified deltas

- v5 imported `SwapTerminalDeploymentLib`; v6 imports `RouterTerminalDeploymentLib`.
- v6 encodes the remote native token as `bytes32(uint256(uint160(JBConstants.NATIVE_TOKEN)))` in place of the v5 raw-address field.
- The v5 `minBridgeAmount` field is absent from v6's token-mapping construction.

### Breaking ABI changes

- This repo is deployment-script-oriented rather than a contract ABI target.
- The meaningful break is in the config objects it constructs for downstream v6 repos: router-terminal inputs, bytes32 remote-token encoding, and the absence of the v5 loan/buyback-hook config shape.

### Indexer impact

- None directly from this repo's own runtime surface.
- Deployment wrappers that mirror this script update their config serialization and downstream ABI expectations to match.

### Migration notes

- If you wrap or mirror this deploy script, rebuild its config inputs from the v6 downstream packages.
- Do not carry v5 swap-terminal assumptions forward; the deployment surface targets router-terminal-era components.
