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
