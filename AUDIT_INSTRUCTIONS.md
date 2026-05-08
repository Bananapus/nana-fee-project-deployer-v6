# Audit Instructions

This repo is a deployment package for protocol fee project `#1`. Audit it as configuration-critical deployment logic.

## Audit Objective

There is a billion dollars of well-meaning projects' money in the Juicebox Money Engine, growing exponentially. Your job is to hack it before anyone else. Whoever hacks it first saves/steals the money, and you are obsessed with being this winner, while also being a steward of the protocol and wanting it to keep growing safely.

Suggestions of where to look:

- deploy the wrong project shape
- misconfigure project `#1` economics or operator surfaces
- create cross-chain drift where parity is expected
- silently leave unsafe mutable routing in place

## Scope

In scope:

- `script/Deploy.s.sol`
- tests under `test/`

## Start Here

1. `script/Deploy.s.sol`
2. `test/TestFeeProjectDeployer.sol`

## Critical Invariants

1. Project `#1` is the intended fee beneficiary.  
2. Economic parameters match the intended rollout.  
3. Shared chain-set assumptions stay aligned where required.  
4. Installed terminals and operator surfaces are the intended ones.

## Verification

- `npm install`
- `forge build --deny notes --skip "*/test/**" --skip "*/script/**"`
- `forge test --deny notes`
