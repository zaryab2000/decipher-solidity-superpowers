---
disable-model-invocation: true
description: Generate the complete audit package before engaging an external auditor
---

# /audit-prep

Invoke the `decipher-solidity-superpowers:solidity-audit-prep` skill.

Use this command when all internal work is complete: code is feature-complete, all tests
pass, gas audit is done, and all Critical/High security findings are resolved.

Generates the mandatory 4-document audit package:
- `audit/scope.md` — in-scope files, exact commit hash, dependency audit status
- `audit/protocol.md` — actors, state machine, invariants, trust assumptions
- `audit/threat-model.md` — attacker goals, capabilities, vectors of concern
- `audit/findings-log.md` — all internal findings with resolutions and regression tests

Do not engage an external auditor without this package.
