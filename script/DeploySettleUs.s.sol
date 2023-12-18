// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {SettleUs} from "../src/SettleUs.sol";

contract DeploySettleUs is Script {
    function run() external returns (SettleUs) {
        vm.startBroadcast();
        SettleUs settleUs = new SettleUs();
        vm.stopBroadcast();
        return (settleUs);
    }
}
