# Command PRD: `/pre-deploy`

**Output file:** `commands/pre-deploy.md`
**Delegates to:** `decipher-solidity-superpowers:solidity-deployer` skill
**Position in lifecycle:** Phase 5a — mandatory gate before any network deployment

---

## Purpose

`/pre-deploy` is the mandatory entry point before deploying any contract to any network
(local fork, testnet, or mainnet). It invokes the `solidity-deployer` skill, which runs the
full pre-deployment checklist and guides the dry-run → broadcast → verify sequence.

This command exists because unguarded deployments miss critical steps: contracts shipped
without NatSpec, without on-chain verification, with `console.log` still imported, with
ownership left on a hot wallet, or without a recorded deployment manifest.

**No `forge create` commands. No manual deployments. No exceptions.** Every deployment in
the plugin lifecycle flows through this command.

---

## What the Coding Agent Must Produce

The coding agent must produce a file at `commands/pre-deploy.md` with this exact structure:

```markdown
---
disable-model-invocation: true
description: Run the pre-deployment checklist and deploy via a Forge script
---

# /pre-deploy

Invoke the `decipher-solidity-superpowers:solidity-deployer` skill.

Use this command before deploying to any network — local fork, testnet, or mainnet.
Runs the full 10-item pre-deployment checklist, then guides a dry-run followed by
a broadcast deployment with on-chain verification.

Requires `/gas-audit` and `/security-review` to be complete. No `forge create`.
No manual deployments. All deployments go through `script/Deploy<Contract>.s.sol`.
```

---

## Frontmatter Requirements

| Field | Value | Why |
|---|---|---|
| `disable-model-invocation` | `true` | Must be explicitly invoked. |
| `description` | `"Run the pre-deployment checklist and deploy via a Forge script"` | Shown in `/help`. "Via a Forge script" signals the constraint: no manual deploys. |

---

## Command Body Requirements

The body must:

1. **Name the skill exactly** — `decipher-solidity-superpowers:solidity-deployer`.

2. **State the scope** — "any network — local fork, testnet, or mainnet". No network is
   exempt from this checklist. The user should not think `/pre-deploy` is only for mainnet.

3. **Describe the sequence** — "dry-run followed by broadcast deployment with on-chain
   verification". This sets the three-step expectation: simulate, broadcast, verify.

4. **State the upstream dependencies** — `/gas-audit` and `/security-review` must be
   complete. Without these, the deployer skill should block. The command primes this
   expectation.

5. **State the hard constraint explicitly** — "No `forge create`. No manual deployments."
   This is explicit enough that the model will refuse to run `forge create` even if asked,
   because the command text tells it not to.

6. **State the deployment mechanism** — "All deployments go through
   `script/Deploy<Contract>.s.sol`". This tells the user what to expect: a script will be
   written or verified, not a one-liner cast command.

---

## Optional: Network + Contract Specification

The user may specify targets:
- `/pre-deploy` — deploys the primary contract in context, prompts for network
- `/pre-deploy Vault --network sepolia` — deploys `Vault` to Sepolia
- `/pre-deploy Vault --network mainnet` — deploys `Vault` to mainnet

The command body may include:

```
If the user specifies a contract name and/or network, pass both to the deployer skill.
If no network is specified, the skill will ask.
```

This prevents the deployer from asking redundant questions when the user already said.

---

## What This Command Must NOT Do

- Must NOT contain the 10-item pre-deployment checklist. That lives in the skill.
- Must NOT describe how `forge script` is invoked. That is the skill's job.
- Must NOT describe on-chain verification commands. Those are in the skill.
- Must NOT allow `forge create` or manual deploys — even "as a fallback" or "if script
  is unavailable." There is no fallback. Write the script.
- Must NOT distinguish between testnet and mainnet in the command body. Both go through
  the same checklist. The skill may handle network-specific logic.

---

## The 10-Item Checklist (Enforced by Skill, Not Command)

These items are listed here for the coding agent to understand what the skill checks.
They must NOT appear in the command body.

1. All tests pass including fork tests
2. No compiler warnings
3. Slither clean — all findings triaged with justification
4. Gas snapshot committed and diff reviewed
5. Contract size under 24,576 bytes (EIP-170 limit)
6. All public/external functions have complete NatSpec
7. No `console.log` or test imports in production contracts
8. No `TODO` or `FIXME` in production code
9. Constructor/initializer arguments documented in `script/config/<network>.json`
10. Ownership transfer to multisig is the LAST step after deployment verification

---

## Deployment Sequence (Enforced by Skill)

The sequence is:
1. **Simulate:** `forge script script/Deploy<Contract>.s.sol --rpc-url $RPC_URL`
   — must succeed with no errors
2. **Broadcast:** `forge script ... --broadcast --verify --etherscan-api-key $KEY`
   — only after simulation passes
3. **Verify:** Check Etherscan/block explorer for source verification
4. **Record:** Write `deployments/<network>/<contract>.json` with address, tx hash,
   block number, deployer address, constructor args

---

## Placement in the Lifecycle

```
/gas-audit (report exists in docs/audits/)
/security-review (all Critical/High findings resolved)
    └─► /pre-deploy
            └─► solidity-deployer skill
                    └─► 10-item checklist
                    └─► dry-run via forge script (simulate)
                    └─► broadcast deployment
                    └─► on-chain verification
                    └─► deployments/<network>/<contract>.json written
            └─► ► ► /audit-prep (if proceeding to external audit)
            └─► ► ► /pre-upgrade (for future upgrades)
```

---

## Post-Deployment Artifacts

The skill (not the command) writes these. Listed for coding agent awareness:

- `deployments/<network>/<ContractName>.json` — deployed address, tx hash, block, deployer,
  constructor args, implementation address (for proxies)
- Gas snapshot at deployment block (for regression tracking)

---

## Verification Checklist for the Coding Agent

After writing `commands/pre-deploy.md`, verify:

- [ ] `disable-model-invocation: true` is present
- [ ] `description` mentions "pre-deployment checklist" and "Forge script"
- [ ] Skill name is plugin-qualified: `decipher-solidity-superpowers:solidity-deployer`
- [ ] Body states scope: "any network — local fork, testnet, or mainnet"
- [ ] Body states the sequence: dry-run → broadcast → verify
- [ ] Upstream dependencies stated: `/gas-audit` and `/security-review`
- [ ] Hard constraint stated: "No `forge create`. No manual deployments."
- [ ] Deployment mechanism stated: `script/Deploy<Contract>.s.sol`
- [ ] Body is ≤ 10 lines
- [ ] The 10-item checklist does NOT appear in the command body
- [ ] File is saved to `commands/pre-deploy.md`
