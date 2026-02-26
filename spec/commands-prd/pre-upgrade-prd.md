# Command PRD: `/pre-upgrade`

**Output file:** `commands/pre-upgrade.md`
**Delegates to:** `decipher-solidity-superpowers:solidity-upgrader` skill
**Position in lifecycle:** Phase 5b — mandatory gate before any proxy upgrade execution

---

## Purpose

`/pre-upgrade` is the mandatory entry point before executing any proxy upgrade on any
network. It invokes the `solidity-upgrader` skill, which runs storage layout verification,
initialization safety checks, fork testing, and a staged rollout sequence before any upgrade
transaction is submitted.

This command exists because proxy upgrades are the most dangerous operation in upgradeable
contract systems. A single storage layout collision silently corrupts all proxy state.
A missing `_disableInitializers()` call leaves the implementation open to self-destruct
attacks. An unversioned re-initializer runs the wrong initialization logic on already-live
state.

The `solidity-upgrader` skill makes every one of these checks non-skippable. No audit
history, no "we've done this before," no "the layout is obviously the same" bypasses the
explicit `forge inspect` diff.

---

## What the Coding Agent Must Produce

The coding agent must produce a file at `commands/pre-upgrade.md` with this exact structure:

```markdown
---
disable-model-invocation: true
description: Verify storage layout safety and run staged checks before any proxy upgrade
---

# /pre-upgrade

Invoke the `decipher-solidity-superpowers:solidity-upgrader` skill.

Use this command before executing any proxy upgrade — UUPS, Transparent, or Beacon — on
any network. Runs storage layout diff, initialization safety checks, fork testing, and
enforces the fork → testnet → mainnet staged rollout sequence.

Storage layout verification is non-negotiable. "The layout is obviously the same" is a
blocked rationalization. Run the diff. Every time.
```

---

## Frontmatter Requirements

| Field | Value | Why |
|---|---|---|
| `disable-model-invocation` | `true` | Must be explicitly invoked. |
| `description` | `"Verify storage layout safety and run staged checks before any proxy upgrade"` | Shown in `/help`. "Storage layout safety" is the primary concern. "Staged checks" signals thoroughness. |

---

## Command Body Requirements

The body must:

1. **Name the skill exactly** — `decipher-solidity-superpowers:solidity-upgrader`.

2. **State the scope** — "any proxy upgrade — UUPS, Transparent, or Beacon — on any
   network." All three proxy patterns and all networks. No exemptions.

3. **List the four core checks** in one line each:
   - Storage layout diff
   - Initialization safety checks
   - Fork testing
   - Staged rollout (fork → testnet → mainnet)

4. **State the non-negotiability of storage layout verification** explicitly. This is the
   single most critical check. The body should contain this sentence verbatim or very
   close: "Storage layout verification is non-negotiable."

5. **Include a blocked rationalization** directly in the command body:
   `"The layout is obviously the same" is a blocked rationalization.`
   This is unusual for a command body — most are purely descriptive — but the storage layout
   rationalization is so common and so dangerous that putting it in the command text ensures
   the model reads it every time the command fires.

6. **State the hard imperative** — "Run the diff. Every time." Two sentences. Short.
   Authoritative.

---

## What This Command Must NOT Do

- Must NOT describe how `forge inspect` is invoked. That is the skill's job.
- Must NOT contain the 8-item pre-upgrade checklist. That lives in the skill.
- Must NOT describe the `cast storage` verification step. That is in the skill.
- Must NOT allow skipping storage layout diff even for "minor" upgrades. All upgrades
  go through the full checklist. There is no "minor upgrade" path.
- Must NOT distinguish between UUPS, Transparent, and Beacon in the command body — all
  follow the same pre-upgrade process. The skill handles pattern-specific differences.

---

## The 8-Item Checklist (Enforced by Skill, Not Command)

These items are listed for the coding agent to understand what the skill checks.
They must NOT appear in the command body.

1. Export old implementation storage layout:
   `forge inspect OldImpl storage-layout --pretty > old-layout.txt`
2. Export new implementation storage layout:
   `forge inspect NewImpl storage-layout --pretty > new-layout.txt`
3. Diff the layouts — no existing slots shifted, removed, or type-changed:
   `diff old-layout.txt new-layout.txt`
4. Verify new state variables only appended at end or fill `__gap` slots
5. Verify `_disableInitializers()` is called in the new implementation's constructor
6. Verify new initializer is versioned with `reinitializer(N)` modifier, not `initializer`
7. All existing tests pass with new implementation (`forge test`)
8. New tests for new functionality written and passing

---

## Why Storage Layout Verification Has Its Own Directive in the Command Body

This is the only command in the plugin that includes a rationalization block in the body
itself (rather than deferring entirely to the skill). The reason:

Developers upgrading their own contracts have seen the layout. They wrote it. They feel
certain it is safe. This confidence is the exact failure mode. The `forge inspect` diff
catches:

- Inheritance order changes that silently shift slot assignments
- New state variables inserted in the wrong position in a parent contract
- Type changes (e.g., `uint128` → `uint256`) that shift subsequent slots
- Mapping/array slot count changes

None of these are visible to the naked eye in a side-by-side code review. The diff command
catches all of them. The command body reinforces this because the model reads the command
body before invoking the skill.

---

## Staged Rollout Sequence (Enforced by Skill)

The sequence is:
1. **Fork test:** `forge test --fork-url $MAINNET_RPC` (test upgrade against live state)
2. **Testnet:** Deploy new implementation, upgrade proxy, verify behavior
3. **Mainnet:** Only after testnet is clean. No mainnet-only upgrades.

---

## Placement in the Lifecycle

```
New implementation written + tested via solidity-builder
    └─► /security-review on new implementation
    └─► /pre-upgrade
            └─► solidity-upgrader skill
                    └─► storage layout diff (non-negotiable)
                    └─► initialization safety check
                    └─► fork test with new implementation
                    └─► testnet upgrade + verification
                    └─► mainnet upgrade + cast storage verification
```

This command may be run multiple times across the upgrade lifecycle (once for fork, once
for testnet, once for mainnet). The staged rollout sequence enforces order.

---

## Proxy Pattern Reference (Skill-Level Detail, Not Command-Level)

| Pattern | Upgrade authorization | Storage concern |
|---|---|---|
| UUPS | `_authorizeUpgrade` in implementation | Implementation stores upgrade logic — must protect it |
| Transparent | ProxyAdmin contract | Admin and user calls strictly separated |
| Beacon | BeaconProxy → UpgradeableBeacon | Single upgrade changes all proxies sharing the beacon |

These distinctions are the skill's responsibility, not the command's. Listed here for
the coding agent to understand the scope of what the skill handles.

---

## Verification Checklist for the Coding Agent

After writing `commands/pre-upgrade.md`, verify:

- [ ] `disable-model-invocation: true` is present
- [ ] `description` mentions "storage layout safety" and "proxy upgrade"
- [ ] Skill name is plugin-qualified: `decipher-solidity-superpowers:solidity-upgrader`
- [ ] Body mentions all three proxy patterns (UUPS, Transparent, Beacon)
- [ ] Body mentions all four core checks (storage diff, init safety, fork test, staged rollout)
- [ ] "Storage layout verification is non-negotiable" appears in body
- [ ] Blocked rationalization ("obviously the same") appears in body
- [ ] Hard imperative ("Run the diff. Every time.") appears in body
- [ ] Body is ≤ 12 lines
- [ ] 8-item checklist does NOT appear in command body
- [ ] File is saved to `commands/pre-upgrade.md`
