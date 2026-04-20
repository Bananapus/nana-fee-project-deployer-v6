# Administration

## At A Glance

| Item | Details |
| --- | --- |
| Scope | Deployment of the canonical fee-beneficiary project and its initial downstream wiring |
| Control posture | Deployment-only control |
| Highest-risk actions | Resolving the wrong protocol addresses, choosing the wrong terminal or router shape, and deploying the wrong fee-project config |
| Recovery posture | Usually requires replacement deployment and ecosystem migration |

## Purpose

`nana-fee-project-deployer-v6` has no runtime admin surface of its own. Its significance is deployment-time: it chooses the configuration of the canonical fee-beneficiary project, and many downstream fee paths assume that project exists and is configured correctly.

## Control Model

- Deployment-only repo
- Runtime power lives in the downstream contracts it instantiates
- Script assumptions about terminal choice, revnet config, and cross-chain setup are the real control surface
- The launch script selects initial terminals, but terminal routing is not automatically locked after deployment

## Roles

| Role | How Assigned | Scope | Notes |
| --- | --- | --- | --- |
| Deployment operator | Whoever runs the script | One deployment | Chooses when and where the fee project is instantiated |
| Post-deploy project operator | Determined by downstream deployer config | Runtime | Not defined locally in this repo |

## Privileged Surfaces

The only meaningful control surface here is `script/Deploy.s.sol`, which:

- resolves existing protocol addresses
- assembles the fee project's immutable configuration
- chooses terminal configuration and optional sucker setup
- launches the canonical fee project through downstream deployers
- leaves the fee project's terminal selection mutable unless downstream operators explicitly lock it later

## Immutable And One-Way

- The fee project's initial stage config and operator assumptions become economically important immediately.
- Wrong address resolution is a deployment mistake, not a runtime toggle.
- Some runtime routing choices, especially terminal selection in the directory, still remain mutable after launch unless explicitly locked.

## Operational Notes

- Verify that the fee project's intended terminal and router setup are correct before deployment.
- Treat post-deploy terminal locking as a separate operational step if silent routing changes are unacceptable.
- Treat this repo as coupled to `deploy-all-v6` and the downstream deployers it calls.
- Re-check any downstream constructor or interface change against this script.

## Machine Notes

- Do not infer intent from partially resolved addresses; this repo depends on explicit config.
- Treat `script/Deploy.s.sol` as the runtime-equivalent source of truth because there is no local mutable contract admin surface.
- If the fee project's terminal routing has not been explicitly locked downstream, do not describe it as finalized.
- If downstream deployer assumptions changed, invalidate the runbook until the script and tests are reviewed together.

## Recovery

- If the wrong fee-project shape is deployed, the normal fix is a new deployment and broader ecosystem migration to the replacement path.
- There is no local owner or setter to patch the config afterward.
- Some downstream runtime configuration, such as terminal selection, may still be recoverable through the owning protocol surfaces if they were not locked.

## Admin Boundaries

- This repo cannot modify the runtime behavior of the deployed fee project after launch.
- It cannot safely autodiscover intent; it depends on explicit address and config choices.
- It also does not guarantee that downstream terminal selection is frozen; that guarantee must come from downstream locking.

## Source Map

- `script/Deploy.s.sol`
- `test/FeeProjectDeployerFork.t.sol`
- `test/FeeProjectEdgeCases.t.sol`
