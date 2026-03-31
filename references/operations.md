# Fee Project Operations

## Change Checklist

- If you edit the fee project's shape, verify revnet, router-terminal, and sucker assumptions together.
- If you edit deployment ordering, confirm the broader ecosystem still finds project `#1` when expected.
- If a bug appears in fee behavior, check whether it lives in this deployment package or the downstream repo providing the runtime logic.

## Common Failure Modes

- This repo is blamed for runtime behavior that actually lives in the composed revnet or router terminal packages.
- A stale assumption about the fee project's stage or issuance config survives after sibling repos evolve.
