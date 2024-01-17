// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

import {IPriceOracle} from "../../../contracts/interfaces/IPriceOracle.sol";

contract MockPriceOracle is IPriceOracle, OwnableTwoSteps {
    address private immutable weth;
    mapping(address => address) public oracles;

    constructor(address _owner, address _weth) OwnableTwoSteps(_owner) {
        weth = _weth;
    }

    function addOracle(address token, uint24 fee) external onlyOwner {
        address pool = address(uint160(uint256(keccak256(abi.encodePacked(token, weth, fee)))));
        oracles[token] = pool;
        emit PoolAdded(token, pool);
    }

    function removeOracle(address token) external onlyOwner {
        oracles[token] = address(0);
        emit PoolRemoved(token);
    }

    function getTWAP(address token, uint32 /*secondsAgo*/) external view returns (uint256 price) {
        address pool = oracles[token];
        if (pool == address(0)) {
            revert PoolNotAllowed();
        }
        price = 635032386273720;
    }
}
