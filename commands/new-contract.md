---
disable-model-invocation: true
description: Start a new smart contract, interface, library, or protocol component
---

# /new-contract

Invoke the `decipher-solidity-superpowers:solidity-planner` skill.

Use this command to start designing a new smart contract, interface, library, or protocol
component. The planner enforces design-before-code: no `.sol` files are written until the
architecture is approved, invariants are defined, and interfaces are committed.

If the user provided a contract name or description, pass it to the planner as initial context.

Do not skip this command. Do not write contract code before running `/new-contract`.
