// SPDX-License-Identifier: MPL-2.0

pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library Signature {
    function hashEthSignedMessage(bytes32 messageHash)
        private
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
            );
    }

    function recoverSigner(bytes32 messageHash, bytes memory signature)
        internal
        pure
        returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

        return ecrecover(hashEthSignedMessage(messageHash), v, r, s);
    }

    function splitSignature(bytes memory sig)
        private
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65);

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }
}

interface DoTheThing {
    function doTheThing(bytes memory extraData) external;
}

contract Bribe3074 {
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
        return keccak256(abi.encodePacked(tx.origin));
    }

    function hashMessage2() private view returns (bytes32) {
        return keccak256(abi.encodePacked(hashMessage1()));
    }

    function release(
        bytes memory signature1,
        bytes memory signature2,
        DoTheThing doer,
        bytes memory extraData
    )
        external
    {
        require(State.Locked == sState);    // Prevent unwanted re-entrancy.
        sState = State.Trial;               // Mark as having entered.

        // Prove `tx.origin` is a normal EOA by having it sign two different
        // messages.
        address signer1 = Signature.recoverSigner(hashMessage1(), signature1);
        require(tx.origin == signer1);

        address signer2 = Signature.recoverSigner(hashMessage2(), signature2);
        require(tx.origin == signer2);

        // Call into an arbitrary contract that does the 3074 magic, and calls
        // back into this contract's `judge`.
        require(address(doer) != address(this));
        doer.doTheThing(extraData);

        // Revert in the case where `judge` is never called.
        require(State.Unlocked == sState);
    }

    function judge() external {
        // Only possible if 3074 is implemented, or we're in the top level of
        // execution.
        require(msg.sender == tx.origin);

        // Require that we've been called earlier in this call stack, excluding
        // the possibility we're in the top level of execution.
        require(State.Trial == sState);

        // Unlock claims!
        sState = State.Unlocked;
        emit Unlocked();
    }

    function fund(IERC20 token, address recipient, uint256 amount) external {
        require(State.Locked == sState);

        sBalances[token][recipient] += amount;
        emit Funded(msg.sender, recipient, token, amount);
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success);
    }

    function claim(IERC20 token) external {
        claimFor(token, msg.sender);
    }

    function claimFor(IERC20 token, address recipient) public {
        require(State.Unlocked == sState);
        uint256 amount = sBalances[token][recipient];
        sBalances[token][recipient] = 0;
        bool success = token.transfer(recipient, amount);
        require(success);
    }

    function approveFor(IERC20 token, address recipient) external {
        require(State.Unlocked == sState);

        uint256 amount = sBalances[token][recipient];
        require(amount > 0);

        sBalances[token][recipient] = 0;

        bool success = token.approve(recipient, amount);
        require(success);
    }
}
