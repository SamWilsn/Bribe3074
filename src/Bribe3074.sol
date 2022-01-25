// SPDX-License-Identifier: MPL-2.0

pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface DoTheThing {
    function doTheThing(bytes memory extraData) external;
}

library Errors {
    string constant internal INVALID_SIGNATURE = "bad sig";
    string constant internal REENTER = "reenter";
    string constant internal NOT_ENTERED = "unentered";
    string constant internal INVALID_DOER = "bad doer";
    string constant internal NOT_JUDGED = "unjudged";
    string constant internal LOCKED = "locked";
}

contract Bribe3074 {
    using SafeERC20 for IERC20;

    enum State {
        Null,
        Locked,
        Trial,
        Unlocked
    }

    event Funded(address indexed donor, address indexed recipient, IERC20 token, uint256 amount);
    event Unlocked();

    State private sState = State.Locked;
    mapping (IERC20 => mapping (address => uint256)) private sBalances;

    function locked() external view returns (bool) {
        return State.Unlocked != sState;
    }

    function balanceOf(IERC20 token, address account) external view returns (uint256) {
        return sBalances[token][account];
    }

    function hashMessage1() private view returns (bytes32) {
        return keccak256(abi.encodePacked(msg.sender));
    }

    function hashMessage2() private view returns (bytes32) {
        return keccak256(abi.encodePacked(hashMessage1()));
    }

    function verifySignature(
        bytes32 messageHash,
        bytes memory signature
    )
        private
        view
    {
        address recovered = ECDSA.recover(
            ECDSA.toEthSignedMessageHash(messageHash),
            signature
        );
        require(msg.sender == recovered, Errors.INVALID_SIGNATURE);
    }

    function release(
        DoTheThing doer,
        bytes memory extraData
    )
        external
    {
        require(State.Locked == sState, Errors.REENTER);    // Prevent unwanted re-entrancy.
        sState = State.Trial;                               // Mark as having entered.

        // Call into an arbitrary contract that does the 3074 magic, and calls
        // back into this contract's `judge`.
        require(address(doer) != address(this), Errors.INVALID_DOER);
        doer.doTheThing(extraData);

        // Revert in the case where `judge` is never called.
        require(State.Unlocked == sState, Errors.NOT_JUDGED);
    }

    function judge(
        bytes memory signature1,
        bytes memory signature2
    ) external {
        // Prove `msg.sender` is a normal EOA by having it sign two different
        // messages.
        verifySignature(hashMessage1(), signature1);
        verifySignature(hashMessage2(), signature2);

        // Require that we've been called earlier in this call stack. Together
        // with the proof above that `msg.sender` is an EOA, this guarantees a
        // 3074-like EIP has been implemented.
        require(State.Trial == sState, Errors.NOT_ENTERED);

        // Unlock claims!
        sState = State.Unlocked;
        emit Unlocked();
    }

    function fund(IERC20 token, address recipient, uint256 amount) external {
        require(State.Locked == sState, Errors.LOCKED);

        sBalances[token][recipient] += amount;
        emit Funded(msg.sender, recipient, token, amount);
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    function claim(IERC20 token) external {
        claimFor(token, msg.sender);
    }

    function claimFor(IERC20 token, address recipient) public {
        require(State.Unlocked == sState, Errors.LOCKED);
        uint256 amount = sBalances[token][recipient];
        sBalances[token][recipient] = 0;
        token.safeTransfer(recipient, amount);
    }

    function approveFor(IERC20 token, address recipient) external {
        require(State.Unlocked == sState, Errors.LOCKED);

        uint256 amount = sBalances[token][recipient];
        require(amount > 0);

        sBalances[token][recipient] = 0;

        token.safeApprove(recipient, amount);
    }
}
