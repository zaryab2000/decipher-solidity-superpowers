# Foundry Test Patterns

This file is loaded by `solidity-builder` on demand — not injected at session start. Reference
it when implementing a specific test pattern described below.

---

## Pattern 1: Access Control Test Template

Tests access control for any privileged function. Always test WRONG caller first, then RIGHT caller.

```solidity
function test_<functionName>_revertsWhenCallerNotOwner() public {
    address attacker = makeAddr("attacker");
    vm.prank(attacker);
    vm.expectRevert(abi.encodeWithSelector(
        OwnableUnauthorizedAccount.selector,
        attacker
    ));
    contract.<functionName>(<args>);
}

function test_<functionName>_succeedsWhenCallerIsOwner() public {
    vm.prank(owner);
    contract.<functionName>(<args>);
    // assert state changed correctly
}
```

For `AccessControl`-based contracts, use the `AccessControlUnauthorizedAccount` error:
```solidity
vm.expectRevert(abi.encodeWithSelector(
    IAccessControl.AccessControlUnauthorizedAccount.selector,
    attacker,
    REQUIRED_ROLE
));
```

---

## Pattern 2: ERC-20 Balance Setup

Use `deal()` for ERC-20 balance setup — manipulates storage directly. Preferred over minting
because it works for any ERC-20 including ones without a public `mint()`.

```solidity
// Balance only
deal(address(token), alice, 1000e18);

// Balance + approval (common setup for deposit tests)
deal(address(token), alice, 1000e18);
vm.prank(alice);
token.approve(address(contract), type(uint256).max);
```

---

## Pattern 3: Event Verification

```solidity
// vm.expectEmit parameters: (checkTopic1, checkTopic2, checkTopic3, checkData)
// true = "verify this field", false = "don't care"
vm.expectEmit(true, false, false, true); // check topic1 (indexed) and data
emit ExpectedEvent(indexedParam, unindexedParam); // emit expected event
contract.functionThatShouldEmit(); // then call the function
```

To verify an event with all indexed topics:
```solidity
vm.expectEmit(true, true, true, true);
emit Transfer(from, to, amount);
token.transfer(to, amount);
```

---

## Pattern 4: Reentrancy Attack Test

Tests that a function is protected against reentrancy.

```solidity
contract ReentrancyAttacker {
    IVault vault;
    uint256 attackCount;
    uint256 constant MAX_ATTACKS = 5;

    constructor(IVault _vault) { vault = _vault; }

    function attack(uint256 amount) external {
        vault.withdraw(amount, address(this), address(this));
    }

    receive() external payable {
        if (attackCount < MAX_ATTACKS) {
            attackCount++;
            vault.withdraw(1 ether, address(this), address(this));
        }
    }
}

function test_withdraw_revertsOnReentrancy() public {
    ReentrancyAttacker attacker = new ReentrancyAttacker(vault);
    deal(address(token), address(attacker), 10 ether);
    vm.prank(address(attacker));
    token.approve(address(vault), 10 ether);
    vm.prank(address(attacker));
    vault.deposit(10 ether, address(attacker));

    vm.expectRevert(ReentrancyGuardReentrantCall.selector);
    vm.prank(address(attacker));
    attacker.attack(1 ether);
}
```

---

## Pattern 5: Time-Dependent Tests (Boundary Conditions)

Always test three points for time-dependent logic:
1. Exactly at threshold (should trigger)
2. 1 second before threshold (should not trigger)
3. 1 second after threshold (should trigger — provides margin confidence)

```solidity
function test_claim_revertsBeforeLockupExpires() public {
    uint256 lockupDuration = vault.lockupPeriod();

    vm.warp(block.timestamp + lockupDuration - 1); // 1 second before
    vm.expectRevert(Vault.LockupNotExpired.selector);
    vm.prank(alice);
    vault.claim();
}

function test_claim_succeedsExactlyAtLockupExpiry() public {
    uint256 lockupDuration = vault.lockupPeriod();

    vm.warp(block.timestamp + lockupDuration); // exactly at threshold
    vm.prank(alice);
    vault.claim(); // should succeed
}

function test_claim_succeedsAfterLockupExpiry() public {
    uint256 lockupDuration = vault.lockupPeriod();

    vm.warp(block.timestamp + lockupDuration + 1); // 1 second after
    vm.prank(alice);
    vault.claim(); // should succeed
}
```

---

## Pattern 6: Signature / Permit Tests

Testing EIP-2612 permit signatures.

```solidity
function test_permit_allowsGaslessApproval() public {
    uint256 alicePrivKey = 0xa11ce; // private key for test only
    address aliceDerived = vm.addr(alicePrivKey);
    deal(address(token), aliceDerived, 1000e18);

    uint256 deadline = block.timestamp + 1 hours;
    bytes32 domainSeparator = token.DOMAIN_SEPARATOR();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
        alicePrivKey,
        keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            keccak256(abi.encode(
                keccak256(
                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                ),
                aliceDerived,
                address(vault),
                1000e18,
                token.nonces(aliceDerived),
                deadline
            ))
        ))
    );

    token.permit(aliceDerived, address(vault), 1000e18, deadline, v, r, s);
    assertEq(token.allowance(aliceDerived, address(vault)), 1000e18);
}

function test_permit_revertsWhenDeadlineExpired() public {
    uint256 alicePrivKey = 0xa11ce;
    address aliceDerived = vm.addr(alicePrivKey);

    uint256 deadline = block.timestamp - 1; // already expired
    // ... sign and call permit ...
    vm.expectRevert(ERC2612ExpiredSignature.selector);
    token.permit(aliceDerived, address(vault), 1000e18, deadline, v, r, s);
}
```

---

## Pattern 7: Two-Step Ownership Transfer (Ownable2Step)

```solidity
function test_transferOwnership_requiresAcceptance() public {
    address newOwner = makeAddr("newOwner");

    vm.prank(owner);
    contract.transferOwnership(newOwner);

    // pendingOwner is set, but ownership not yet transferred
    assertEq(contract.pendingOwner(), newOwner);
    assertEq(contract.owner(), owner); // still the original owner

    // new owner must accept
    vm.prank(newOwner);
    contract.acceptOwnership();

    assertEq(contract.owner(), newOwner);
    assertEq(contract.pendingOwner(), address(0));
}

function test_transferOwnership_revertsWhenAcceptedByWrongAddress() public {
    address newOwner = makeAddr("newOwner");
    address impostor = makeAddr("impostor");

    vm.prank(owner);
    contract.transferOwnership(newOwner);

    vm.prank(impostor);
    vm.expectRevert(abi.encodeWithSelector(
        OwnableUnauthorizedAccount.selector,
        impostor
    ));
    contract.acceptOwnership();
}
```

---

## Pattern 8: Pausable Functions

```solidity
function test_pause_blocksDeposit() public {
    vm.prank(owner);
    contract.pause();

    deal(address(token), alice, 1000e18);
    vm.prank(alice);
    token.approve(address(contract), 1000e18);

    vm.prank(alice);
    vm.expectRevert(EnforcedPause.selector);
    contract.deposit(1000e18, alice);
}

function test_unpause_allowsDeposit() public {
    vm.prank(owner);
    contract.pause();
    vm.prank(owner);
    contract.unpause();

    deal(address(token), alice, 1000e18);
    vm.startPrank(alice);
    token.approve(address(contract), 1000e18);
    contract.deposit(1000e18, alice); // should succeed
    vm.stopPrank();
}

function test_pause_revertsWhenCallerNotOwner() public {
    address attacker = makeAddr("attacker");
    vm.prank(attacker);
    vm.expectRevert(abi.encodeWithSelector(
        OwnableUnauthorizedAccount.selector,
        attacker
    ));
    contract.pause();
}
```
