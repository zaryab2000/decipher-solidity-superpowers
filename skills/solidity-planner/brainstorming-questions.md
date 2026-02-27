# Brainstorming Questions by Contract Category

This file is loaded by `solidity-planner` when the contract being designed falls into one of the
categories below. Read the relevant section before asking Phase 2 questions. Do not load this
entire file into context for every design session — only the matching category section.

---

## ERC-20 Token

- Is the total supply fixed or mintable? Who can mint? Is there a cap?
- Is the token pausable? Who can pause? Can transfers be permanently disabled?
- Does it use EIP-2612 permit (gasless approvals)?
- Does it need vote delegation (ERC20Votes)?
- Are there transfer restrictions (blocklist, allowlist)?
- Does it use any fee mechanism on transfer?

**Common OZ bases:** `ERC20`, `ERC20Permit`, `ERC20Burnable`, `ERC20Votes`, `ERC20Pausable`

**Attack patterns to confirm mitigated:**
- Approval frontrunning: does the contract use `increaseAllowance`/`decreaseAllowance` over direct `approve`?
- Infinite approval risks: does the UI warn users about `approve(type(uint256).max)`?
- Permit replay: is the `nonce` tracked per-user? Is the `deadline` enforced?

---

## ERC-4626 Vault

- What is the underlying asset? Is it standard ERC-20?
- Does the vault deposit into an external protocol (Aave, Compound, Yearn)?
- How are shares calculated on first deposit? (Must handle empty vault case to prevent inflation attack)
- Is there a management fee? A performance fee? Who collects it?
- Are there withdrawal queues or lockup periods?
- Is there a max deposit or max withdrawal per transaction?
- What happens if the underlying protocol is paused or rugged?

**Attack patterns to confirm mitigated:**
- First-depositor inflation attack: use virtual shares offset (`_decimalsOffset()` in OZ ERC4626 v5)
  or require minimum initial deposit
- Donation attack: does `totalAssets()` use the actual balance or a tracked internal counter?
- Rounding direction: deposits round down (favors vault), withdrawals round up (favors vault)
  — verify OZ ERC4626 implements this correctly for your version

---

## Governance (OpenZeppelin Governor)

- What token grants voting power? ERC20Votes or ERC721Votes?
- What is the voting delay (time between proposal creation and voting start)?
- What is the voting period?
- What quorum is required? Is it fixed or adaptive?
- Is there a timelock on proposal execution? What is the delay?
- Who can create proposals? Is there a proposal threshold?
- Can the guardian veto malicious proposals?

**Attack patterns to confirm mitigated:**
- Flash loan voting: is voting power measured at a past snapshot block, not current block?
- Proposal manipulation: can an attacker create malicious proposals with small stake?
- Timelock bypass: is the `TimelockController` the admin, not an EOA?
- Quorum manipulation: can a large token holder manipulate quorum thresholds?

---

## Oracle Consumer

- Which oracle provider? Chainlink, Pyth, Uniswap TWAP, or custom?
- What is the acceptable staleness threshold? (Chainlink default: 1 hour)
- What is the fallback if the oracle is unavailable?
- Are you deploying to an L2? (Chainlink L2 feeds require sequencer uptime check)
- What price precision does the oracle return? (Chainlink: 8 decimals; tokens: 18 decimals)
- Can negative or zero prices occur? How are they handled?

**Required staleness check pattern (Chainlink):**
```solidity
(, int256 price, , uint256 updatedAt, ) = feed.latestRoundData();
if (price <= 0) revert InvalidPrice(price);
if (block.timestamp - updatedAt > STALENESS_THRESHOLD) revert StalePrice(updatedAt);
```

**L2 sequencer uptime check (Chainlink on Arbitrum/Base/Optimism):**
```solidity
// Must check sequencer uptime feed before using any price
(, int256 answer, uint256 startedAt, , ) = sequencerFeed.latestRoundData();
if (answer != 0) revert SequencerDown();
if (block.timestamp - startedAt < GRACE_PERIOD) revert GracePeriodNotOver();
```

---

## AMM / DEX

- Is this a constant product (x*y=k), constant sum, or concentrated liquidity AMM?
- Are there swap fees? Who collects them? How are they distributed?
- Is there a protocol fee? Can it be changed?
- How are positions represented — fungible (ERC-20 LP shares) or non-fungible (NFT)?
- Is there a price impact limit to protect against sandwich attacks?
- How is liquidity initialization protected against donation attacks?

**Attack patterns to confirm mitigated:**
- Sandwich attacks: is there a minimum output parameter on swaps?
- Price manipulation: does the AMM use spot price or TWAP for any external use?
- Donation attack on initialization: does the first LP receive fair shares for their deposit?
- Flash loan drain: is liquidity locked for at least one block after provision?

---

## Staking / Rewards

- What token is staked? What token is rewarded?
- Is the reward rate fixed or variable?
- Is there a lockup period? Can users unstake early with a penalty?
- How are rewards calculated — per-block, per-second, or snapshot-based?
- Can rewards be compounded in the same transaction?
- What happens if the reward pool runs out?
- Can the staking contract be paused without locking staked funds?

**Attack patterns to confirm mitigated:**
- Flash-stake: can a user stake and unstake in the same transaction to claim rewards?
  Mitigation: snapshot-based rewards, per-block minimum lock
- Reward manipulation: can the operator change the reward rate in a way that front-runs stakers?
  Mitigation: timelock on rate changes
- Incorrect accounting: does the reward accumulator handle the case where `totalStaked == 0`?
  (Division by zero when no one is staking is a common bug)
