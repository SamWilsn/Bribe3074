// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Vm} from "@std/Vm.sol";

import "../Bribe3074.sol";

import "ds-test/test.sol";

address constant APPROVEE = 0x5555555555555555555555555555555555555555;
address constant ORIGIN = 0x285608733D47720B40447b1cC0293A2e4435090e;

Vm constant VM = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

contract FakeToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, type(uint256).max);
    }
}

contract SetSenderAndClaim is DoTheThing {
    IERC20 immutable TOKEN;

    constructor(IERC20 token) {
        TOKEN = token;
    }

    function doTheThing(bytes calldata) external {
        Bribe3074 bribe = Bribe3074(msg.sender);

        VM.prank(ORIGIN, ORIGIN);
        bribe.judge();

        bribe.claim(TOKEN);
    }
}

contract SetSenderAndApprove is DoTheThing {
    IERC20 immutable TOKEN;

    constructor(IERC20 token) {
        TOKEN = token;
    }

    function doTheThing(bytes calldata) external {
        Bribe3074 bribe = Bribe3074(msg.sender);

        VM.prank(ORIGIN, ORIGIN);
        bribe.judge();

        bribe.approveFor(TOKEN, APPROVEE);
    }
}

contract SetSender is DoTheThing {
    function doTheThing(bytes calldata) external {
        VM.prank(ORIGIN, ORIGIN);
        Bribe3074(msg.sender).judge();
    }
}

contract LeaveSender is DoTheThing {
    function doTheThing(bytes calldata) external {
        Bribe3074(msg.sender).judge();
    }
}

contract LeaveSenderAndClaim is DoTheThing {
    IERC20 immutable TOKEN;

    constructor(IERC20 token) {
        TOKEN = token;
    }

    function doTheThing(bytes calldata) external {
        Bribe3074 bribe = Bribe3074(msg.sender);
        bribe.claim(TOKEN);
    }
}

contract LeaveSenderAndApprove is DoTheThing {
    IERC20 immutable TOKEN;

    constructor(IERC20 token) {
        TOKEN = token;
    }

    function doTheThing(bytes calldata) external {
        Bribe3074 bribe = Bribe3074(msg.sender);
        bribe.approveFor(TOKEN, APPROVEE);
    }
}

contract Bribe3074Test is DSTest {

    bytes constant SIG_1 = hex"51948364f9370847cc297dde293d8d9b5e945f737e0cfe0efe14181a64b5baed6f18cc35c8adffe641429e2749b410961abcbf496672aa6205c410aa15f0bd561c";

    bytes constant SIG_2 = hex"a47eed4186347cfb3063a2e0140e7271399c6cd465b51f38e7da2b0f1f21411b2033d7459711e69ce825ae35d7e857a04c7495d83ec042444bddcd9ed448ef251b";

    Bribe3074 bribe;

    DoTheThing setSender;
    DoTheThing setSenderAndClaim;
    DoTheThing setSenderAndApprove;

    DoTheThing leaveSender;
    DoTheThing leaveSenderAndClaim;
    DoTheThing leaveSenderAndApprove;

    FakeToken tokenA;
    FakeToken tokenB;

    function setUp() public {
        tokenA = new FakeToken("A", "A");
        tokenB = new FakeToken("B", "B");

        bribe = new Bribe3074();

        setSender = new SetSender();
        setSenderAndClaim = new SetSenderAndClaim(tokenA);
        setSenderAndApprove = new SetSenderAndApprove(tokenA);

        leaveSender = new LeaveSender();
        leaveSenderAndClaim = new LeaveSenderAndClaim(tokenA);
        leaveSenderAndApprove = new LeaveSenderAndApprove(tokenA);
    }

    function unlock() private {
        VM.prank(ORIGIN, ORIGIN);
        bribe.release(SIG_1, SIG_2, setSender, hex"");
    }

    function testReleaseUnlock() public {
        assertTrue(bribe.locked());

        unlock();

        assertTrue(!bribe.locked());
    }

    function testReleaseStayLocked() public {
        assertTrue(bribe.locked());

        VM.prank(ORIGIN, ORIGIN);

        try bribe.release(SIG_1, SIG_2, leaveSender, hex"") {
            fail();
        } catch Error(string memory reason) {
            assertEq(reason, Errors.FAILED);
        }

        assertTrue(bribe.locked());
    }

    function testReleaseBadSig1() public {
        assertTrue(bribe.locked());

        VM.prank(ORIGIN, ORIGIN);

        try bribe.release(SIG_2, SIG_2, setSender, hex"") {
            fail();
        } catch Error(string memory reason) {
            assertEq(reason, Errors.INVALID_SIGNATURE);
        }

        assertTrue(bribe.locked());
    }

    function testReleaseBadSig2() public {
        assertTrue(bribe.locked());

        VM.prank(ORIGIN, ORIGIN);

        try bribe.release(SIG_1, SIG_1, setSender, hex"") {
            fail();
        } catch Error(string memory reason) {
            assertEq(reason, Errors.INVALID_SIGNATURE);
        }

        assertTrue(bribe.locked());
    }

    function testJudge() public {
        assertTrue(bribe.locked());

        try bribe.judge() {
            fail();
        } catch Error(string memory reason) {
            assertEq(reason, Errors.FAILED);
        }

        assertTrue(bribe.locked());
    }

    function testFund() public {
        address rX = address(5);
        address rY = address(6);

        assertEq(bribe.balanceOf(tokenA, rX), 0);
        assertEq(bribe.balanceOf(tokenB, rX), 0);
        assertEq(bribe.balanceOf(tokenA, rY), 0);
        assertEq(bribe.balanceOf(tokenB, rY), 0);

        tokenA.approve(address(bribe), type(uint256).max);
        tokenB.approve(address(bribe), type(uint256).max);

        bribe.fund(tokenA, rX, 100);

        assertEq(bribe.balanceOf(tokenA, rX), 100);
        assertEq(bribe.balanceOf(tokenB, rX), 0);
        assertEq(bribe.balanceOf(tokenA, rY), 0);
        assertEq(bribe.balanceOf(tokenB, rY), 0);

        bribe.fund(tokenB, rX, 99);

        assertEq(bribe.balanceOf(tokenA, rX), 100);
        assertEq(bribe.balanceOf(tokenB, rX), 99);
        assertEq(bribe.balanceOf(tokenA, rY), 0);
        assertEq(bribe.balanceOf(tokenB, rY), 0);

        bribe.fund(tokenB, rX, 98);

        assertEq(bribe.balanceOf(tokenA, rX), 100);
        assertEq(bribe.balanceOf(tokenB, rX), 197);
        assertEq(bribe.balanceOf(tokenA, rY), 0);
        assertEq(bribe.balanceOf(tokenB, rY), 0);

        bribe.fund(tokenB, rY, 6);

        assertEq(bribe.balanceOf(tokenA, rX), 100);
        assertEq(bribe.balanceOf(tokenB, rX), 197);
        assertEq(bribe.balanceOf(tokenA, rY), 0);
        assertEq(bribe.balanceOf(tokenB, rY), 6);

        bribe.fund(tokenA, rY, 7);

        assertEq(bribe.balanceOf(tokenA, rX), 100);
        assertEq(bribe.balanceOf(tokenB, rX), 197);
        assertEq(bribe.balanceOf(tokenA, rY), 7);
        assertEq(bribe.balanceOf(tokenB, rY), 6);

        assertEq(tokenA.balanceOf(address(bribe)), 107);
        assertEq(tokenB.balanceOf(address(bribe)), 203);
    }

    function testClaim() public {
        address self = address(this);

        tokenA.approve(address(bribe), 17);

        bribe.fund(tokenA, self, 17);

        assertEq(tokenA.balanceOf(self), type(uint256).max - 17);

        unlock();

        assertEq(tokenA.balanceOf(self), type(uint256).max - 17);

        bribe.claim(tokenA);

        assertEq(tokenA.balanceOf(self), type(uint256).max);
    }

    function testClaimLocked() public {
        address self = address(this);

        tokenA.approve(address(bribe), 17);

        bribe.fund(tokenA, self, 17);

        assertEq(tokenA.balanceOf(self), type(uint256).max - 17);

        try bribe.claim(tokenA) {
            fail();
        } catch Error(string memory reason) {
            assertEq(reason, Errors.LOCKED);
        }

        assertEq(tokenA.balanceOf(self), type(uint256).max - 17);
    }

    function testClaimTrial() public {
        address recpt = address(setSenderAndClaim);

        tokenA.approve(address(bribe), 17);

        bribe.fund(tokenA, recpt, 17);

        assertEq(tokenA.balanceOf(recpt), 0);

        VM.prank(ORIGIN, ORIGIN);
        bribe.release(SIG_1, SIG_2, setSenderAndClaim, hex"");

        assertEq(tokenA.balanceOf(recpt), 17);
    }

    function testClaimTrialLeaveSender() public {
        address recpt = address(leaveSenderAndClaim);

        tokenA.approve(address(bribe), 17);

        bribe.fund(tokenA, recpt, 17);

        assertEq(tokenA.balanceOf(recpt), 0);

        VM.prank(ORIGIN, ORIGIN);
        try bribe.release(SIG_1, SIG_2, leaveSenderAndClaim, hex"") {} catch {}

        assertEq(tokenA.balanceOf(recpt), 0);
    }

    function testClaimTwice() public {
        address self = address(this);

        tokenA.approve(address(bribe), 34);

        bribe.fund(tokenA, self, 17);
        bribe.fund(tokenA, address(0), 17);

        assertEq(tokenA.balanceOf(self), type(uint256).max - 34);

        unlock();

        assertEq(tokenA.balanceOf(self), type(uint256).max - 34);

        bribe.claim(tokenA);

        assertEq(tokenA.balanceOf(self), type(uint256).max - 17);

        try bribe.claim(tokenA) {} catch {}

        assertEq(tokenA.balanceOf(self), type(uint256).max - 17);
    }

    function testApprove() public {
        address self = address(this);

        tokenA.approve(address(bribe), 17);

        bribe.fund(tokenA, APPROVEE, 17);

        assertEq(tokenA.balanceOf(self), type(uint256).max - 17);

        unlock();

        assertEq(tokenA.balanceOf(self), type(uint256).max - 17);

        bribe.approveFor(tokenA, APPROVEE);

        assertEq(tokenA.balanceOf(self), type(uint256).max - 17);
        assertEq(tokenA.allowance(address(bribe), APPROVEE), 17);
    }

    function testApproveLocked() public {
        address self = address(this);

        tokenA.approve(address(bribe), 17);

        bribe.fund(tokenA, APPROVEE, 17);

        assertEq(tokenA.balanceOf(self), type(uint256).max - 17);

        try bribe.approveFor(tokenA, APPROVEE) {
            fail();
        } catch Error(string memory reason) {
            assertEq(reason, Errors.LOCKED);
        }

        assertEq(tokenA.balanceOf(self), type(uint256).max - 17);
        assertEq(tokenA.allowance(address(bribe), APPROVEE), 0);
    }

    function testApproveTrial() public {
        tokenA.approve(address(bribe), 17);

        bribe.fund(tokenA, APPROVEE, 17);

        assertEq(tokenA.balanceOf(APPROVEE), 0);

        VM.prank(ORIGIN, ORIGIN);
        bribe.release(SIG_1, SIG_2, setSenderAndApprove, hex"");

        assertEq(tokenA.balanceOf(APPROVEE), 0);
        assertEq(tokenA.allowance(address(bribe), APPROVEE), 17);
    }

    function testApproveTrialLeaveSender() public {
        tokenA.approve(address(bribe), 17);

        bribe.fund(tokenA, APPROVEE, 17);

        assertEq(tokenA.balanceOf(APPROVEE), 0);

        VM.prank(ORIGIN, ORIGIN);
        try bribe.release(SIG_1, SIG_2, leaveSenderAndApprove, hex"") {} catch {}

        assertEq(tokenA.balanceOf(APPROVEE), 0);
        assertEq(tokenA.allowance(address(bribe), APPROVEE), 0);
    }

    function testApproveTwice() public {
        address self = address(this);

        tokenA.approve(address(bribe), 34);

        bribe.fund(tokenA, APPROVEE, 17);
        bribe.fund(tokenA, address(0), 17);

        assertEq(tokenA.balanceOf(self), type(uint256).max - 34);

        unlock();

        assertEq(tokenA.balanceOf(self), type(uint256).max - 34);

        bribe.approveFor(tokenA, APPROVEE);

        assertEq(tokenA.balanceOf(APPROVEE), 0);
        assertEq(tokenA.allowance(address(bribe), APPROVEE), 17);

        try bribe.approveFor(tokenA, APPROVEE) {} catch {}

        assertEq(tokenA.balanceOf(APPROVEE), 0);
        assertEq(tokenA.allowance(address(bribe), APPROVEE), 17);
    }

    function testApproveThenClaim() public {
        address self = address(this);

        tokenA.approve(address(bribe), 34);

        bribe.fund(tokenA, APPROVEE, 17);
        bribe.fund(tokenA, address(0), 17);

        assertEq(tokenA.balanceOf(self), type(uint256).max - 34);

        unlock();

        assertEq(tokenA.balanceOf(self), type(uint256).max - 34);

        bribe.approveFor(tokenA, APPROVEE);

        assertEq(tokenA.balanceOf(APPROVEE), 0);
        assertEq(tokenA.allowance(address(bribe), APPROVEE), 17);

        try bribe.claimFor(tokenA, APPROVEE) {} catch {}

        assertEq(tokenA.balanceOf(APPROVEE), 0);
        assertEq(tokenA.allowance(address(bribe), APPROVEE), 17);
    }

}
