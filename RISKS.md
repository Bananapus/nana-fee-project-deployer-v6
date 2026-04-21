# Fee Project Deployer Risk Register

This file covers the risks around project `#1`, the protocol fee sink.

## How To Use This File

- Read `Priority risks` first. Project `#1` deserves stricter operational treatment than a normal deployment.
- Treat `Invariants to verify` as ecosystem-level checks, not local niceties.

## Priority Risks

| Priority | Risk | Why it matters | Primary controls |
|----------|------|----------------|------------------|
| P0 | Misconfigured project `#1` rollout | Every fee path points here. A bad deployment can break fee collection or distort token economics globally. | Deterministic deploy review, chain parity checks, and post-deploy verification. |
| P1 | Post-deploy liveness degradation | If project `#1` cannot accept fees cleanly, downstream repos often keep operating while fee economics silently degrade. | Monitoring, smoke tests, and routing review. |
| P1 | Governance or ownership irreversibility mistakes | The fee project's ownership and revnet wiring are opinionated and hard to unwind. | Careful one-shot configuration review. |

## 1. Trust Assumptions

- **Sphinx deployment is trusted.**
- **The operator multisig is trusted.**
- **Existing deployment artifacts are trusted inputs.**
- **Router-terminal artifact availability matters.**
- **Revnet deployer assumptions apply.**

## 2. Configuration Risks

- **Hardcoded parameters are permanent once deployed.**
- **Auto-issuance amounts matter.**
- **Start time can already be in the past at deployment.**
- **L2 sucker deployer selection can go wrong.**
- **Terminal selection is configured, not locked.**
- **Economic parameters like `splitPercent` and `cashOutTaxRate` are highly sensitive.**

## 3. Project `#1` Significance

This is the fee project. Maximum scrutiny on deployment parameters is warranted.

## 4. Post-Deployment Risks

- **Terminal availability matters.**
- **Terminal redirection risk persists until routing is locked.**
- **Sucker bridge liveness matters.**
- **Issuance decay compounds over time.**
- **Operator responsibility remains concentrated.**

## 5. Accepted Behaviors

### 5.1 Historical stage anchoring is intentional

`NANA_START_TIME` may already be in the past at deployment time. That is accepted because the fee project is intended to share one canonical issuance schedule across chains.

## 6. Invariants To Verify

- project `#1` is owned by the intended deployer surface
- stage parameters match the intended configuration
- sucker pairs connect the correct chains
- auto-issuance amounts match the intended per-chain distribution
- operator address is the intended multisig
- shared economic parameters match `deploy-all-v6` where expected
- the fee project's primary terminal accepts the intended native asset on every deployed chain

