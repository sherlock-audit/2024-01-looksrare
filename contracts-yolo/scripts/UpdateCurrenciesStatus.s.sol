// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// Scripting tool
import {Script} from "forge-std/Script.sol";

// Core contracts
import {YoloV2} from "../contracts/YoloV2.sol";

contract UpdateCurrenciesStatus is Script {
    function run() external {
        uint256 chainId = block.chainid;

        uint256 deployerPrivateKey = vm.envUint("TESTNET_KEY");

        vm.startBroadcast(deployerPrivateKey);

        YoloV2 yolo = YoloV2(0xce69a4cF5687F4d8B44E8C96a8bB9c8d7Ebe09Cf);
        address[] memory currencies = new address[](1);
        currencies[0] = 0xF9C20B8bb6D552f8aCC7c0301C20c929aa107797;
        yolo.updateCurrenciesStatus(currencies, true);

        vm.stopBroadcast();
    }
}
