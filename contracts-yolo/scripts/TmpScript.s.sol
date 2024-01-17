// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// Scripting tool
import {Script} from "forge-std/Script.sol";

// Core contracts
import {YoloV2} from "../contracts/YoloV2.sol";
import {IYoloV2} from "../contracts/interfaces/IYoloV2.sol";
import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";

import {console2} from "forge-std/console2.sol";

contract TmpScript is Script {
    error ChainIdInvalid(uint256 chainId);

    function run() external {
        // uint256 deployerPrivateKey = vm.envUint("TESTNET_KEEPER_PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.envUint("TESTNET_KEY");

        vm.startBroadcast(deployerPrivateKey);

        YoloV2 yolo = YoloV2(0xce69a4cF5687F4d8B44E8C96a8bB9c8d7Ebe09Cf);
        yolo.updateProtocolFeeDiscountBp(9_500);

        vm.stopBroadcast();
    }
}
