// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

import {PriceOracle} from "../../contracts/PriceOracle.sol";
import {IPriceOracle} from "../../contracts/interfaces/IPriceOracle.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract PriceOracle_Test is TestHelpers {
    uint32 private constant TWAP_WINDOW = 3_600;

    function setUp() public {
        _forkMainnet();
        _deployPriceOracle();
    }

    function test_addOracle() public asPrankedUser(owner) {
        expectEmitCheckAll();
        emit PoolAdded(LOOKS, 0x4b5Ab61593A2401B1075b90c04cBCDD3F87CE011);

        priceOracle.addOracle(LOOKS, 3_000);
        assertEq(priceOracle.oracles(LOOKS), 0x4b5Ab61593A2401B1075b90c04cBCDD3F87CE011);
    }

    function test_addOracle_RevertIf_NotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        priceOracle.addOracle(LOOKS, 3_000);
    }

    function test_removeOracle() public asPrankedUser(owner) {
        priceOracle.addOracle(LOOKS, 3_000);

        expectEmitCheckAll();
        emit PoolRemoved(LOOKS);

        priceOracle.removeOracle(LOOKS);
        assertEq(priceOracle.oracles(LOOKS), address(0));
    }

    function test_removeOracle_RevertIf_NotOwner() public {
        vm.prank(owner);
        priceOracle.addOracle(LOOKS, 3_000);

        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        priceOracle.removeOracle(LOOKS);
    }

    function test_getTWAP() public asPrankedUser(owner) {
        priceOracle.addOracle(LOOKS, 3_000);
        uint256 price = priceOracle.getTWAP(LOOKS, TWAP_WINDOW);
        assertEq(price, 33684085101692);
    }

    function test_getTWAP_TokenDecimalsIsNot18() public asPrankedUser(owner) {
        priceOracle.addOracle(USDC, 500);
        priceOracle.addOracle(USDT, 500);

        uint256 usdcPrice = priceOracle.getTWAP(USDC, TWAP_WINDOW);
        assertEq(usdcPrice, 635032386273720);

        uint256 usdtPrice = priceOracle.getTWAP(USDT, TWAP_WINDOW);
        assertEq(usdtPrice, 635413500973043);
    }

    function test_getTWAP_RevertIf_PoolNotAllowed() public {
        vm.expectRevert(IPriceOracle.PoolNotAllowed.selector);
        priceOracle.getTWAP(USDT, TWAP_WINDOW);
    }

    function test_getTWAP_RevertIf_OLD() public asPrankedUser(owner) {
        priceOracle.addOracle(USDC, 500);
        vm.expectRevert(bytes("OLD"));
        priceOracle.getTWAP(USDC, uint32(86_400));
    }
}
