// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Scripting tool
import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";

// Core contracts
import {Yolo} from "../../contracts/Yolo.sol";
import {IYolo} from "../../contracts/interfaces/IYolo.sol";

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {PriceOracle} from "../../contracts/PriceOracle.sol";
import {ITransferManager} from "@looksrare/contracts-transfer-manager/contracts/interfaces/ITransferManager.sol";

// Create2 factory interface
import {IImmutableCreate2Factory} from "../../contracts/interfaces/IImmutableCreate2Factory.sol";

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFCoordinatorV2Adapter} from "vrf-contracts/chainlink_compatible/VRFCoordinatorV2Adapter.sol";

contract Deployment is Script {
    using stdJson for string;

    IImmutableCreate2Factory private constant IMMUTABLE_CREATE2_FACTORY =
        IImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);

    function run() external {
        uint256 chainId = block.chainid;
        uint256 deployerPrivateKey = vm.envUint(_getString("privateKeyName"));

        IYoloV2.ConstructorCalldata memory constructorCalldata;
        constructorCalldata.roundDuration = 5 minutes;
        constructorCalldata.valuePerEntry = 0.01 ether;
        constructorCalldata.protocolFeeRecipient = _getAddress("protocolFeeRecipient");
        constructorCalldata.protocolFeeBp = 500;
        constructorCalldata.protocolFeeDiscountBp = 5_000;
        constructorCalldata.reservoirOracle = 0xAeB1D03929bF87F69888f381e73FBf75753d75AF;
        constructorCalldata.signatureValidityPeriod = 90 seconds;
        constructorCalldata.weth = _getAddress("wrappedNativeToken");
        constructorCalldata.vrfCoordinator = _getAddress("vrfCoordinator");
        constructorCalldata.subscriptionId = _getUint64("subscriptionId");
        constructorCalldata.keyHash = _getBytes32("keyHash");
        constructorCalldata.owner = _getAddress("owner");
        constructorCalldata.operator = _getAddress("operator");
        constructorCalldata.transferManager = _getAddress("transferManager");
        constructorCalldata.looks = _getAddress("looks");

        constructorCalldata.maximumNumberOfParticipantsPerRound = 50;

        vm.startBroadcast(deployerPrivateKey);

        if (chainId == 1) {
            PriceOracle erc20PriceOracle = PriceOracle(0x00000000000A95dBfC66D37F3FC5E597C0b03Daf);
            constructorCalldata.erc20Oracle = address(erc20PriceOracle);

            IMMUTABLE_CREATE2_FACTORY.safeCreate2({
                salt: vm.envBytes32("YOLO_SALT"),
                initializationCode: abi.encodePacked(type(YoloV2).creationCode, abi.encode(constructorCalldata))
            });

            IYoloV2 yolo = IYoloV2(0x00000000007767d79f9F4aA1Ff0d71b8E2E4a231);

            address[] memory currencies = new address[](100);
            currencies[0] = 0xb7F7F6C52F2e2fdb1963Eab30438024864c313F6;
            currencies[1] = 0x6EFc003D3F3658383F06185503340C2Cf27A57b6;
            currencies[2] = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
            currencies[3] = 0x60E4d786628Fea6478F785A6d7e704777c86a7c6;
            currencies[4] = 0x8821BeE2ba0dF28761AffF119D66390D594CD280;
            currencies[5] = 0xED5AF388653567Af2F388E6224dC7C4b3241C544;
            currencies[6] = 0x769272677faB02575E84945F03Eca517ACc544Cc;
            currencies[7] = 0x5Af0D9827E0c53E4799BB226655A1de152A425a5;
            currencies[8] = 0x348FC118bcC65a92dC033A951aF153d14D945312;
            currencies[9] = 0xE012Baf811CF9c05c408e879C399960D1f305903;
            currencies[10] = 0xBd3531dA5CF5857e7CfAA92426877b022e612cf8;
            currencies[11] = 0x7a63d17F5a59BCA04B6702F461b1f1A1c59b100B;
            currencies[12] = 0xB9951B43802dCF3ef5b14567cb17adF367ed1c0F;
            currencies[13] = 0xba30E5F9Bb24caa003E9f2f0497Ad287FDF95623;
            currencies[14] = 0xd1258DB6Ac08eB0e625B75b371C023dA478E94A9;
            currencies[15] = 0x39ee2c7b3cb80254225884ca001F57118C8f21B6;
            currencies[16] = 0xfE8C6d19365453D26af321D0e8c910428c23873F;
            currencies[17] = 0xEeca64ea9fCf99A22806Cd99b3d29cf6e8D54925;
            currencies[18] = 0x23581767a106ae21c074b2276D25e5C3e136a68b;
            currencies[19] = 0x8a90CAb2b38dba80c64b7734e58Ee1dB38B8992e;
            currencies[20] = 0x49cF6f5d44E70224e2E23fDcdd2C053F30aDA28B;
            currencies[21] = 0x960b7a6BCD451c9968473f7bbFd9Be826EFd549A;
            currencies[22] = 0xEfed2A58cC6A5b81f9158B231847f005cF086c01;
            currencies[23] = 0xaCF63E56fd08970b43401492a02F6F38B6635C91;
            currencies[24] = 0xD3D9ddd0CF0A5F0BFB8f7fcEAe075DF687eAEBaB;
            currencies[25] = 0x7Bd29408f11D2bFC23c34f18275bBf23bB716Bc7;
            currencies[26] = 0xCcc441ac31f02cD96C153DB6fd5Fe0a2F4e6A68d;
            currencies[27] = 0xc99c679C50033Bbc5321EB88752E89a93e9e83C5;
            currencies[28] = 0x6B00de202e3Cd03c523CA05d8b47231DBdD9142b;
            currencies[29] = 0x42069ABFE407C60cf4ae4112bEDEaD391dBa1cdB;
            currencies[30] = 0x57a204AA1042f6E66DD7730813f4024114d74f37;
            currencies[31] = 0x3Af2A97414d1101E2107a70E7F33955da1346305;
            currencies[32] = 0x1CB1A5e65610AEFF2551A50f76a87a7d3fB649C6;
            currencies[33] = 0x4b15a9c28034dC83db40CD810001427d3BD7163D;
            currencies[34] = 0x3bf2922f4520a8BA0c2eFC3D2a1539678DaD5e9D;
            currencies[35] = 0xe785E82358879F061BC3dcAC6f0444462D4b5330;
            currencies[36] = 0x1A92f7381B9F03921564a437210bB9396471050C;
            currencies[37] = 0xB852c6b5892256C264Cc2C888eA462189154D8d7;
            currencies[38] = 0x59325733eb952a92e069C87F0A6168b29E80627f;
            currencies[39] = 0x6339e5E072086621540D0362C4e3Cea0d643E114;
            currencies[40] = 0x09233d553058c2F42ba751C87816a8E9FaE7Ef10;
            currencies[41] = 0xCcDF1373040D9Ca4B5BE1392d1945C1DaE4a862c;
            currencies[42] = 0x34d85c9CDeB23FA97cb08333b511ac86E1C4E258;
            currencies[43] = 0xB6a37b5d14D502c3Ab0Ae6f3a0E058BC9517786e;
            currencies[44] = 0xEb2dFC54EbaFcA8F50eFcc1e21A9D100b5AEb349;
            currencies[45] = 0xEdB61f74B0d09B2558F1eeb79B247c1F363Ae452;
            currencies[46] = 0x670D4DD2e6BADFBbD372D0d37E06cd2852754a04;
            currencies[47] = 0x79FCDEF22feeD20eDDacbB2587640e45491b757f;
            currencies[48] = 0xf9e39ce3463B8dEF5748Ff9B8F7825aF8F1b1617;
            currencies[49] = 0xe1dC516B1486Aba548eecD2947A11273518434a4;
            currencies[50] = 0x521f9C7505005CFA19A8E5786a9c3c9c9F5e6f42;
            currencies[51] = 0x364C828eE171616a39897688A831c2499aD972ec;
            currencies[52] = 0x790B2cF29Ed4F310bf7641f013C65D4560d28371;
            currencies[53] = 0x59468516a8259058baD1cA5F8f4BFF190d30E066;
            currencies[54] = 0x7D8820FA92EB1584636f4F5b8515B5476B75171a;
            currencies[55] = 0xbDdE08BD57e5C9fD563eE7aC61618CB2ECdc0ce0;
            currencies[56] = 0x80336Ad7A747236ef41F47ed2C7641828a480BAA;
            currencies[57] = 0x32973908FaeE0Bf825A343000fE412ebE56F802A;
            currencies[58] = 0x6c410cF0B8c113Dc6A7641b431390B11d5515082;
            currencies[59] = 0xd774557b647330C91Bf44cfEAB205095f7E6c367;
            currencies[60] = 0x062E691c2054dE82F28008a8CCC6d7A1c8ce060D;
            currencies[61] = 0x306b1ea3ecdf94aB739F1910bbda052Ed4A9f949;
            currencies[62] = 0x1D20A51F088492A0f1C57f047A9e30c9aB5C07Ea;
            currencies[63] = 0x6dc6001535e15b9def7b0f6A20a2111dFA9454E2;
            currencies[64] = 0x524cAB2ec69124574082676e6F654a18df49A048;
            currencies[65] = 0x8943C7bAC1914C9A7ABa750Bf2B6B09Fd21037E0;
            currencies[66] = 0x77372a4cc66063575b05b44481F059BE356964A4;
            currencies[67] = 0x231d3559aa848Bf10366fB9868590F01d34bF240;
            currencies[68] = 0x892848074ddeA461A15f337250Da3ce55580CA85;
            currencies[69] = 0x4Db1f25D3d98600140dfc18dEb7515Be5Bd293Af;
            currencies[70] = 0x394E3d3044fC89fCDd966D3cb35Ac0B32B0Cda91;
            currencies[71] = 0x64a1C0937728d8d2fA8Cd81Ef61a9c860B7362Db;
            currencies[72] = 0xc3f733ca98E0daD0386979Eb96fb1722A1A05E69;
            currencies[73] = 0x2acAb3DEa77832C09420663b0E1cB386031bA17B;
            currencies[74] = 0x6c952aF158EC8D0FD94908E389C084394d9AeBBb;
            currencies[75] = 0x4D7d2e237D64d1484660b55c0A4cC092fa5e6716;
            currencies[76] = 0x1B829B926a14634d36625e60165c0770C09D02b2;
            currencies[77] = 0x1792a96E5668ad7C167ab804a100ce42395Ce54D;
            currencies[78] = 0x13303b4EE819FAc204be5eF77523cfCd558c082f;
            currencies[79] = 0x5b1085136a811e55b2Bb2CA1eA456bA82126A376;
            currencies[80] = 0x1F7c16FCe4fC894143aFB5545Bf04f676bf7DCf3;
            currencies[81] = 0xF661D58cfE893993b11D53d11148c4650590C692;
            currencies[82] = 0x8ff1523091c9517BC328223D50b52Ef450200339;
            currencies[83] = 0x81D6A3c844A9fB452ED069e9fc16cf37f137a58E;
            currencies[84] = 0x0Fc3DD8C37880a297166BEd57759974A157f0E74;
            currencies[85] = 0x05da517B1bf9999B7762EaEfa8372341A1a47559;
            currencies[86] = 0x75E95ba5997Eb235F40eCF8347cDb11F18ff640B;
            currencies[87] = 0xA10568356163A704e65b6F2B7d37775024b1DBa6;
            currencies[88] = 0xEf0182dc0574cd5874494a120750FD222FdB909a;
            currencies[89] = 0x209e639a0EC166Ac7a1A4bA41968fa967dB30221;
            currencies[90] = 0x354634c4621cDfb7a25E6486cCA1E019777D841B;
            currencies[91] = 0x0c2E57EFddbA8c768147D1fdF9176a0A6EBd5d83;
            currencies[92] = 0x9378368ba6b85c1FbA5b131b530f5F5bEdf21A18;
            currencies[93] = 0xaaD35C2DadbE77f97301617D82e661776c891Fa9;
            currencies[94] = 0xE6d48bF4ee912235398b96E16Db6F310c21e82CB;
            currencies[95] = 0x123b30E25973FeCd8354dd5f41Cc45A3065eF88C;
            currencies[96] = 0x3903d4fFaAa700b62578a66e7a67Ba4cb67787f9;
            currencies[97] = 0x789e35a999c443fE6089544056f728239B8ffeE7;
            currencies[98] = 0x3Acce66cD37518A6d77d9ea3039E00B3A2955460;
            currencies[99] = 0xf4d2888d29D722226FafA5d9B24F9164c092421E;
            yolo.updateCurrenciesStatus(currencies, true);
        } else if (chainId == 42161 || chainId == 8453) {
            address priceOracle = IMMUTABLE_CREATE2_FACTORY.safeCreate2({
                salt: vm.envBytes32(_getString("priceOracleSaltName")),
                initializationCode: abi.encodePacked(
                    type(PriceOracle).creationCode,
                    abi.encode(constructorCalldata.operator, constructorCalldata.weth)
                )
            });

            IYolo.ConstructorCalldata memory constructorCalldataV1;
            constructorCalldataV1.roundDuration = 5 minutes;
            constructorCalldataV1.valuePerEntry = 0.01 ether;
            constructorCalldataV1.protocolFeeBp = 500;
            constructorCalldataV1.reservoirOracle = 0xAeB1D03929bF87F69888f381e73FBf75753d75AF;
            constructorCalldataV1.signatureValidityPeriod = 90 seconds;

            constructorCalldataV1.maximumNumberOfDepositsPerRound = 50;
            constructorCalldataV1.maximumNumberOfParticipantsPerRound = 50;

            constructorCalldataV1.weth = _getAddress("wrappedNativeToken");
            constructorCalldataV1.keyHash = _getBytes32("keyHash");
            constructorCalldataV1.subscriptionId = _getUint64("subscriptionId");
            constructorCalldataV1.vrfCoordinator = _getAddress("vrfCoordinator");
            constructorCalldataV1.owner = _getAddress("owner");
            constructorCalldataV1.operator = _getAddress("operator");
            constructorCalldataV1.protocolFeeRecipient = _getAddress("protocolFeeRecipient");
            constructorCalldataV1.transferManager = _getAddress("transferManager");

            constructorCalldataV1.erc20Oracle = priceOracle;

            address yolo = IMMUTABLE_CREATE2_FACTORY.safeCreate2({
                salt: vm.envBytes32(_getString("yoloSaltName")),
                initializationCode: abi.encodePacked(type(Yolo).creationCode, abi.encode(constructorCalldataV1))
            });

            VRFCoordinatorV2Interface(constructorCalldataV1.vrfCoordinator).addConsumer(
                constructorCalldataV1.subscriptionId,
                yolo
            );

            ITransferManager(constructorCalldataV1.transferManager).allowOperator(yolo);
            // } else if (chainId == 421614) {

            // PriceOracle priceOracle = new PriceOracle(constructorCalldata.operator, constructorCalldata.weth);

            // IYolo.ConstructorCalldata memory constructorCalldataV1;
            // constructorCalldataV1.roundDuration = 5 minutes;
            // constructorCalldataV1.valuePerEntry = 0.01 ether;
            // constructorCalldataV1.protocolFeeBp = 500;
            // constructorCalldataV1.reservoirOracle = 0xAeB1D03929bF87F69888f381e73FBf75753d75AF;
            // constructorCalldataV1.signatureValidityPeriod = 90 seconds;

            // constructorCalldataV1.maximumNumberOfDepositsPerRound = 50;
            // constructorCalldataV1.maximumNumberOfParticipantsPerRound = 50;

            // constructorCalldataV1.weth = _getAddress("wrappedNativeToken");
            // constructorCalldataV1.keyHash = _getBytes32("keyHash");
            // constructorCalldataV1.subscriptionId = _getUint64("subscriptionId");
            // constructorCalldataV1.vrfCoordinator = _getAddress("vrfCoordinator");
            // constructorCalldataV1.owner = _getAddress("owner");
            // constructorCalldataV1.operator = _getAddress("operator");
            // constructorCalldataV1.protocolFeeRecipient = _getAddress("protocolFeeRecipient");
            // constructorCalldataV1.transferManager = _getAddress("transferManager");

            // constructorCalldataV1.erc20Oracle = address(priceOracle);

            // Yolo yolo = new Yolo(constructorCalldataV1);

            // YoloV2 yolo = new YoloV2(constructorCalldataV1);

            // VRFCoordinatorV2Interface(constructorCalldataV1.vrfCoordinator).addConsumer(
            //     constructorCalldataV1.subscriptionId,
            //     address(yolo)
            // );

            // ITransferManager(constructorCalldataV1.transferManager).allowOperator(address(yolo));
        } else if (chainId == 11155111) {
            // Sepolia Uniswap V3 factory address is 0x0227628f3F023bb0B980b67D528571c95c6DaC1c.
            // PriceOracle erc20PriceOracle = new PriceOracle(constructorCalldata.owner, constructorCalldata.weth);
            PriceOracle erc20PriceOracle = PriceOracle(0x5282Dec40c65cf3cf5d5d0E377EDff7C1083F327);
            constructorCalldata.erc20Oracle = address(erc20PriceOracle);

            // erc20PriceOracle.addOracle(0xa68c2CaA3D45fa6EBB95aA706c70f49D3356824E, uint24(3_000));

            YoloV2 yolo = new YoloV2(constructorCalldata);

            address[] memory currencies = new address[](3);
            currencies[0] = 0x61AAEcdbe9C2502a72fec63F2Ff510bE1b95DD97;
            currencies[1] = 0xa68c2CaA3D45fa6EBB95aA706c70f49D3356824E;
            currencies[2] = 0x0535208A1Db725f7a2f1ad2452fac4c177617f7e;

            yolo.updateCurrenciesStatus(currencies, true);
            yolo.grantRole(yolo.OPERATOR_ROLE(), 0x9eab2223d84060E212354BfA620BF687b6E9Ae20);

            VRFCoordinatorV2Interface(constructorCalldata.vrfCoordinator).addConsumer(
                constructorCalldata.subscriptionId,
                address(yolo)
            );

            ITransferManager(constructorCalldata.transferManager).allowOperator(address(yolo));
        } else if (chainId == 421614) {
            // There isn't an Arbitrum Sepolia Uniswap V3 deployment, but it cannot be 0
            constructorCalldata.erc20Oracle = 0x000000000000000000000000000000000000dEaD;
            YoloV2 yolo = new YoloV2(constructorCalldata);

            yolo.grantRole(yolo.OPERATOR_ROLE(), 0x9eab2223d84060E212354BfA620BF687b6E9Ae20);

            VRFCoordinatorV2Interface(constructorCalldata.vrfCoordinator).addConsumer(
                constructorCalldata.subscriptionId,
                address(yolo)
            );

            ITransferManager(constructorCalldata.transferManager).allowOperator(address(yolo));
        }
        vm.stopBroadcast();
    }

    function _getNetworkConfig() private view returns (string memory json) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/scripts/deployment/NetworkConfig.json");
        json = vm.readFile(path);
    }

    function _getAddress(string memory key) private view returns (address) {
        return
            abi.decode(
                _getNetworkConfig().parseRaw(string(abi.encodePacked(".", Strings.toString(block.chainid), ".", key))),
                (address)
            );
    }

    function _getString(string memory key) private view returns (string memory) {
        return
            abi.decode(
                _getNetworkConfig().parseRaw(string(abi.encodePacked(".", Strings.toString(block.chainid), ".", key))),
                (string)
            );
    }

    function _getUint64(string memory key) private view returns (uint64) {
        return
            abi.decode(
                _getNetworkConfig().parseRaw(string(abi.encodePacked(".", Strings.toString(block.chainid), ".", key))),
                (uint64)
            );
    }

    function _getBytes32(string memory key) private view returns (bytes32) {
        return
            abi.decode(
                _getNetworkConfig().parseRaw(string(abi.encodePacked(".", Strings.toString(block.chainid), ".", key))),
                (bytes32)
            );
    }
}
