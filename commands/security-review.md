---
disable-model-invocation: true
description: Run a two-stage security review on a completed contract implementation
---

# /security-review

Invoke the `decipher-solidity-superpowers:solidity-code-reviewer` skill, which dispatches
the `reviewoor` agent for a two-stage security review: spec compliance, then full security
analysis.

Use this command after completing a contract implementation and passing the gas audit.
Findings are severity-rated (Critical / High / Medium / Low / Informational).

Critical and High findings block all further progress and must be resolved before
`/pre-deploy` or `/audit-prep`.

If the user specifies a contract name or path, pass it to the code reviewer as the review target.
If no target is specified, the reviewer will identify the contract from context or ask.
