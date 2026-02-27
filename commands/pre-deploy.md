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

If the user specifies a contract name and/or network, pass both to the deployer skill.
If no network is specified, the skill will ask.
