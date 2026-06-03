# Administration

## At a glance

| Item | Details |
| --- | --- |
| Scope | Deployment packaging for protocol fee project `#1` |
| Control posture | Mostly deployment-time control, then runtime control passes to composed repos |
| Highest-risk actions | Misconfiguring stage parameters, operator surfaces, or chain parity |
| Recovery posture | Poor once deployed; many mistakes are effectively permanent |

## Purpose

This repo is about controlling one critical deployment, not managing a general-purpose runtime surface.

## Control model

- deployment parameters define the important behavior
- post-deploy runtime control moves into revnet, directory, router-terminal, and sucker surfaces
- terminal locking is a separate operational decision after deployment

## Privileged surfaces

- `script/Deploy.s.sol`

## Operational notes

- review project `#1` as a global assumption
- verify operator and terminal targets before deployment
- compare settings with `deploy-all-v6` where shared parity is expected

## Recovery

- recovery is mostly redeploy-and-migrate, not in-place repair
- unlocked terminal routing may still be adjustable after deployment

## Admin boundaries

- this repo does not own runtime fee logic after deployment
- it cannot hot-fix bad immutable parameters

## Source map

- `script/Deploy.s.sol`
