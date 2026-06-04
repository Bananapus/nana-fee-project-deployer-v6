# V5 to V6 Changelog

## Scope

This is a V5-to-V6 migration changelog, not a package release log or commit history. It compares `nana-fee-project-deployer-v5` in `../../v5/evm` with the current `nana-fee-project-deployer-v6` repo.

## Current V6 Surface

- `script/Deploy.s.sol`

## Summary

- This package is deployment-script-oriented. Its migration impact is the config it constructs for downstream V6 packages, not a runtime contract ABI of its own.
- The deployment flow targets the router-terminal ecosystem instead of the V5 swap-terminal ecosystem.
- Sucker-related inputs follow the V6 remote-token model. Remote native tokens are encoded as `bytes32` values rather than raw address fields.
- The script composes V6 package addresses and V6 permission assumptions.

## ABI, Event, and Error Changes

- This repo has no standalone runtime ABI to diff.
- Deployment wrappers that mirror this script must update their serialized config objects for downstream V6 packages.
- Verified source-level deployment deltas:
  - V5 imported `SwapTerminalDeploymentLib`; V6 imports `RouterTerminalDeploymentLib`.
  - V6 encodes the remote native token as `bytes32(uint256(uint160(JBConstants.NATIVE_TOKEN)))`.
  - The V5 `minBridgeAmount` field is absent from the V6 token-mapping construction.

## Machine-Checked ABI Coverage

Generated from Foundry artifacts, filtered to this repo's own runtime source roots and excluding tests, scripts, and dependencies.

- Own-source runtime ABI artifacts compared: V6 `0`, V5 `0`.
- This repo has no standalone runtime ABI in the audited source roots; migration impact comes from scripts, deployment artifacts, and sibling package ABIs.

## Migration Notes

- If you wrap or fork the deploy script, rebuild its config inputs from the V6 downstream packages.
- Do not carry V5 swap-terminal deployment fields forward.
- Treat deployment artifacts and sibling package ABIs as the source of truth for event/error handling.
