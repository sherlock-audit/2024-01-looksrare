// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// Scripting tool
import {Script} from "forge-std/Script.sol";

// Core contracts
import {PriceOracle} from "../contracts/PriceOracle.sol";

import {console2} from "forge-std/console2.sol";

contract OracleSimulation is Script {
    error ChainIdInvalid(uint256 chainId);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTNET_KEY");

        vm.startBroadcast(deployerPrivateKey);

        PriceOracle oracle = new PriceOracle(
            0xF332533bF5d0aC462DC8511067A8122b4DcE2B57,
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        );
        address token = 0xf4d2888d29D722226FafA5d9B24F9164c092421E;
        oracle.addOracle(token, uint24(3_000));
        console2.log(oracle.getTWAP(token, uint32(3_600)));

        vm.stopBroadcast();
    }
}
