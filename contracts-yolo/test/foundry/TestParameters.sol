// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @dev These are Sepolia parameters.
 */
abstract contract TestParameters is Test {
    using stdJson for string;

    bytes32 internal constant KEY_HASH = hex"8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef";
    uint64 internal constant SUBSCRIPTION_ID = 734;
    address internal constant VRF_COORDINATOR = 0x271682DEB8C4E0901D1a1550aD2e64D568E69909;
    address internal constant SUBSCRIPTION_ADMIN = 0xB5a9e5a319c7fDa551a30BE592c77394bF935c6f;
    address internal constant RESERVOIR_ORACLE = 0xAeB1D03929bF87F69888f381e73FBf75753d75AF;
    address internal constant PUDGY_PENGUINS = 0xBd3531dA5CF5857e7CfAA92426877b022e612cf8;
    address internal constant NPCERS = 0xa5ea010a46EaE77bD20EEE754f6D15320358dfD8;
    address internal constant GEMESIS = 0xbe9371326F91345777b04394448c23E2BFEaa826;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant LOOKS = 0xf4d2888d29D722226FafA5d9B24F9164c092421E;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    uint40 internal constant ROUND_DURATION = 10 minutes;
    uint40 internal constant MAXIMUM_NUMBER_OF_PARTICIPANTS_PER_ROUND = 20;

    uint256 internal constant FULFILL_RANDOM_WORDS_REQUEST_ID =
        11338694365390227707752217035088928507242015434390445755734987844103727766356;
    uint256 internal constant FULFILL_RANDOM_WORDS_REQUEST_ID_2 =
        97101810247967952848970932981456518489990405688176491887859608349397797467324;

    function _pudgyPenguinsDepositsCalldataBase(
        uint256 tokenId
    ) private pure returns (IYoloV2.DepositCalldata[] memory depositsCalldata) {
        depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC721;
        depositsCalldata[0].tokenAddress = PUDGY_PENGUINS;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        depositsCalldata[0].tokenIdsOrAmounts = tokenIds;
    }

    function _pudgyPenguinsDepositsCalldata(
        uint256 tokenId
    ) internal view returns (IYoloV2.DepositCalldata[] memory depositsCalldata) {
        depositsCalldata = _pudgyPenguinsDepositsCalldataBase(tokenId);
        depositsCalldata[0].reservoirOracleFloorPrice = _reservoirPudgyPenguinsFloorPrice();
    }

    function _pudgyPenguinsDepositsCalldata2(
        uint256 tokenId
    ) internal view returns (IYoloV2.DepositCalldata[] memory depositsCalldata) {
        depositsCalldata = _pudgyPenguinsDepositsCalldataBase(tokenId);
        depositsCalldata[0].reservoirOracleFloorPrice = _reservoirPudgyPenguinsFloorPrice2();
    }

    function _reservoirGemesisFloorPrice() internal view returns (IYoloV2.ReservoirOracleFloorPrice memory floorPrice) {
        floorPrice = _decodeReservoirFloorPrice("/test/foundry/gemesis-floor-price.json");
    }

    function _reservoirPudgyPenguinsFloorPrice()
        internal
        view
        returns (IYoloV2.ReservoirOracleFloorPrice memory floorPrice)
    {
        floorPrice = _decodeReservoirFloorPrice("/test/foundry/pudgy-penguins-floor-price.json");
    }

    function _reservoirPudgyPenguinsFloorPrice2()
        internal
        view
        returns (IYoloV2.ReservoirOracleFloorPrice memory floorPrice)
    {
        floorPrice = _decodeReservoirFloorPrice("/test/foundry/pudgy-penguins-floor-price-2.json");
    }

    function _reservoirPudgyPenguinsFloorPriceUSDC()
        internal
        view
        returns (IYoloV2.ReservoirOracleFloorPrice memory floorPrice)
    {
        floorPrice = _decodeReservoirFloorPrice("/test/foundry/pudgy-penguins-usdc-floor-price.json");
    }

    function _reservoirNPCersFloorPrice() internal view returns (IYoloV2.ReservoirOracleFloorPrice memory floorPrice) {
        floorPrice = _decodeReservoirFloorPrice("/test/foundry/npcers-floor-price.json");
    }

    function _reservoirNPCersSpotFloorPrice()
        internal
        view
        returns (IYoloV2.ReservoirOracleFloorPrice memory floorPrice)
    {
        floorPrice = _decodeReservoirFloorPrice("/test/foundry/npcers-spot-floor-price.json");
    }

    function _decodeReservoirFloorPrice(
        string memory path
    ) private view returns (IYoloV2.ReservoirOracleFloorPrice memory floorPrice) {
        string memory root = vm.projectRoot();
        string memory json = vm.readFile(string.concat(root, path));

        floorPrice.id = abi.decode(json.parseRaw(".message.id"), (bytes32));
        floorPrice.payload = abi.decode(json.parseRaw(".message.payload"), (bytes));
        floorPrice.timestamp = abi.decode(json.parseRaw(".message.timestamp"), (uint256));
        floorPrice.signature = abi.decode(json.parseRaw(".message.signature"), (bytes));
    }
}
