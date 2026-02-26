# Command PRD: `/pre-deploy`

**File:** `commands/pre-deploy.md`

**Delegates to:** `solidity-deployer` skill

---

## Purpose

User-triggered entry point to run the mandatory pre-deployment checklist before any network deployment (testnet or mainnet).

---

## File Contents

```markdown
---
disable-model-invocation: true
---

# /pre-deploy

Invoke the `decipher-solidity-superpowers:solidity-deployer` skill.

Use this command before any deployment (testnet or mainnet). Runs the full
pre-deployment checklist and ensures the deployment script meets all requirements.
```

---

## When to Use

Before any deployment to any network. This command enforces the `solidity-deployer` skill's gate: no `forge create`, no manual deployment, no shortcuts.

---

## What Happens on Invocation

1. The `solidity-deployer` skill is invoked.
2. The skill runs through the 10-item mandatory pre-deployment checklist:
   - All tests pass (including fork tests)
   - No compiler warnings
   - Slither clean — all findings triaged
   - Gas snapshot committed
   - Contract size under 24,576 bytes
   - All NatSpec complete
   - No `console.log` imports in production contracts
   - No `TODO` or `FIXME` in production code
   - Constructor/initializer arguments in config file
   - Ownership transfer to multisig is the LAST step
3. The skill verifies a `script/Deploy<ContractName>.s.sol` script exists.
4. The skill guides through dry-run then broadcast deployment.
5. Post-deployment: verification checklist is run and deployment manifest written.

---

## Notes

- `disable-model-invocation: true` means the command only fires when the user explicitly types `/pre-deploy`.
- Testnet and mainnet deployments both require this checklist — no exceptions.
- The gas audit (`/gas-audit`) and security review (`/security-review`) must complete before running `/pre-deploy`.
