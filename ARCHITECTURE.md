# Architecture

## Purpose

`nana-fee-project-deployer-v6` packages the one specific deployment shape for protocol fee project `#1`.

## System overview

This repo is mostly one deployment script plus tests. It wires together revnet, router-terminal, and sucker components so the fee beneficiary project exists in the expected shape from the start.

## Core invariants

- project `#1` must be the intended fee beneficiary
- economic parameters must match the intended rollout
- chain-set configuration must stay aligned where cross-chain parity is required
- the correct operator and terminal surfaces must be installed

## Trust boundaries

- runtime trust mostly lives in the repos this deployer composes
- deployment artifacts from sibling repos are trusted inputs
- the Sphinx safe and configured multisig surfaces are real operational trust points

## Critical flow

```text
deploy script
  -> load upstream deployment artifacts
  -> configure revnet parameters for project #1
  -> configure terminals and bridge support
  -> launch the fee project in its intended ecosystem shape
```

## Security model

- the main risk is not code complexity, but permanent misconfiguration
- project `#1` matters because many other fee paths assume it exists and works
- post-deploy terminal mutability remains a live risk until operators lock it

## Safe change guide

- review economic parameters as carefully as contract logic
- compare against `deploy-all-v6` where shared assumptions should match
- verify router-terminal and bridge artifacts before deployment

## Source map

- `script/Deploy.s.sol`
- `test/TestFeeProjectDeployer.sol`
