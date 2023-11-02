// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/strategies/irs/CommonStrat.sol";
import "../src/vaults/RiveraAutoCompoundingVaultV2Public.sol";
import "../src/strategies/irs/LendleRivera.sol";
import "../src/strategies/irs/interfaces/ILendleRivera.sol";
import "../src/strategies/common/interfaces/IStrategy.sol";

import "./Weth.sol";
import "@pancakeswap-v2-exchange-protocol/interfaces/IPancakeRouter02.sol";

contract CheckDeposit is Script {
    address public vault = 0x2760394D2103f799A678C555009c1E94e5Eb217A;
    address public strategy = 0x5963e4acBf39139A6C60f9899458dECd9ee26ed9;
    address public token = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    function setUp() public {}

    function run() public {
        uint privateKey = 0xfc2f8cc0abd2d9d05229c8942e8a529d1ba9265eb1b4c720c03f7d074615afbb;
        address acc = vm.addr(privateKey);
        console.log("Account", acc);

        uint256 dpDai = 10 * (10 ** 18);

        vm.startBroadcast(privateKey);

        IERC20(token).approve(vault, dpDai);

        RiveraAutoCompoundingVaultV2Public(vault).deposit(dpDai, acc);

        console.log(RiveraAutoCompoundingVaultV2Public(vault).totalAssets());
        console.log(RiveraAutoCompoundingVaultV2Public(vault).balanceOf(acc));
        console.log(IERC20(token).balanceOf(acc));
    }
}

// forge script scripts/CheckDeposit.s.sol:CheckDeposit --rpc-url http://127.0.0.1:8545/ --broadcast -vvv --legacy --slow
