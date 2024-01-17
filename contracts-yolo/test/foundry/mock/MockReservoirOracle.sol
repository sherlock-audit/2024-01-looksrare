// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract MockReservoirOracle {
    error NotOwner();
    error InvalidSignature();
    error InvalidSigner();

    address public owner;

    bytes4 internal constant MAGICVALUE = 0x1626ba7e;

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        owner = _newOwner;
    }

    function isValidSignature(bytes32 _hash, bytes memory _signature) external view returns (bytes4 magicValue) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))
            v := byte(0, mload(add(_signature, 0x60)))
        }
        address recovered = ecrecover(_hash, v, r, s);

        if (recovered == address(0)) {
            revert InvalidSignature();
        }

        if (recovered != owner) {
            revert InvalidSigner();
        }

        return MAGICVALUE;
    }
}
