---
disable-model-invocation: true
description: Run a full gas optimization audit on a contract before deployment
---

# /gas-audit

Invoke the `decipher-solidity-superpowers:solidity-gas-optimizer` skill, which dispatches
the `optimizoor` agent to run the full 8-category gas optimization audit.

Use this command after all tests pass and before running `/security-review` or `/pre-deploy`.
The audit produces a severity-categorized findings report and a gas snapshot diff.

If the user specifies a contract name or path, pass it to the gas optimizer as the audit target.
If no target is specified, audit all contracts in `src/`.

Do not deploy without completing the gas audit. `/pre-deploy` will block if the gas audit
report is absent.
