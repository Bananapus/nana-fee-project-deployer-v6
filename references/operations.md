# Fee project operations

## Change checklist

- If you edit the fee project's shape, verify revnet, router-terminal, and sucker assumptions together.
- If you edit deployment ordering, confirm the broader ecosystem still finds project `#1` when expected.
- If a bug appears in fee behavior, check whether it lives in this deployment package or the downstream repo providing the runtime logic.
- Treat this repo as deployment orchestration, not a standalone runtime package. Most behavioral bugs will land in sibling repos.

## Common failure modes

- This repo is blamed for runtime behavior that actually lives in the composed revnet or router terminal packages.
- A stale assumption about the fee project's stage or issuance config survives after sibling repos evolve.
- The fee project is deployed with a subtly wrong start time or stage shape, and the mistake only shows up once other repos begin paying fees into project `#1`.
