# User Journeys

## Repo Purpose

This repo deploys protocol fee project `#1` in the intended V6 shape.

## Primary Actors

- operators deploying the canonical fee project
- reviewers verifying that project `#1` matches ecosystem assumptions
- engineers rehearsing or replaying deployment flows

## Key Surfaces

- `script/Deploy.s.sol`
- fee-project tests and edge-case tests

## Journey 1: Deploy Protocol Fee Project `#1`

**Actor:** deployment operator.

**Intent:** launch the canonical fee beneficiary project.

**Preconditions**
- upstream deployment artifacts are present and correct
- economic parameters and chain set are reviewed

**Main Flow**
1. Run the deploy script.
2. Configure project `#1` with the intended revnet, router-terminal, and sucker shape.
3. Verify the resulting project matches the expected ecosystem assumptions.

**Failure Modes**
- wrong upstream artifact addresses
- mismatched stage or auto-issuance parameters
- deployment ordering mistakes

**Postconditions**
- project `#1` exists as the intended fee beneficiary

## Journey 2: Verify Cross-Chain Parity

**Actor:** operator or reviewer.

**Intent:** confirm that the deployment set matches across chains where it should.

**Preconditions**
- deployments have completed on the intended chain set

**Main Flow**
1. Compare the chain-specific configuration outputs.
2. Check that shared economic parameters match where required.
3. Confirm terminal and bridge wiring are the intended ones.

**Failure Modes**
- chain drift in auto-issuance or stage configuration
- router-terminal or sucker wiring mismatch

**Postconditions**
- the deployment set is internally consistent

## Trust Boundaries

- this repo trusts sibling deployment artifacts
- most runtime behavior lives in the repos it composes
- project `#1` is an ecosystem-wide assumption after deployment

## Hand-Offs

- Use `revnet-core-v6` for runtime fee-project economics.
- Use `nana-router-terminal-v6` and `nana-suckers-v6` for the runtime behavior of the attached surfaces.
