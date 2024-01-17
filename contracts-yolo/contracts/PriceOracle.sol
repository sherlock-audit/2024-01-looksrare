// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

import {IPriceOracle} from "./interfaces/IPriceOracle.sol";

/**
 * @title PriceOracle
 * @notice This contract allows Yolo to retrieve a token's TWAP price in ETH from Uniswap V3 pools.
 * @author LooksRare protocol team (👀,💎)
 */
contract PriceOracle is IPriceOracle, OwnableTwoSteps {
    address private immutable weth;
    IUniswapV3Factory private constant UNISWAP_V3_FACTORY =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    mapping(address => address) public oracles;

    /**
     *
     * @param _owner The contract owner.
     * @param _weth Wrapped Ether address.
     */
    constructor(address _owner, address _weth) OwnableTwoSteps(_owner) {
        weth = _weth;
    }

    /**
     * @param token The token we want the price in ETH for.
     * @param fee Uniswap V3 pool fee.
     */
    function addOracle(address token, uint24 fee) external onlyOwner {
        address pool = UNISWAP_V3_FACTORY.getPool(token, weth, fee);
        oracles[token] = pool;
        emit PoolAdded(token, pool);
    }

    /**
     * @param token The token we no longer want the price in ETH for.
     */
    function removeOracle(address token) external onlyOwner {
        oracles[token] = address(0);
        emit PoolRemoved(token);
    }

    /**
     *
     * @param token The token we want the price in ETH for.
     * @param secondsAgo The duration we want to time-weight the average price.
     */
    function getTWAP(address token, uint32 secondsAgo) external view returns (uint256 price) {
        address pool = oracles[token];
        if (pool == address(0)) {
            revert PoolNotAllowed();
        }
        (int24 arithmeticMeanTick, ) = OracleLibrary.consult(pool, secondsAgo);
        price = OracleLibrary.getQuoteAtTick({
            tick: arithmeticMeanTick,
            baseAmount: uint128(10 ** IERC20(token).decimals()),
            baseToken: token,
            quoteToken: weth
        });
    }
}
