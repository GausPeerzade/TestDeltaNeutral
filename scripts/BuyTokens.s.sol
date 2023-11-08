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

contract BuyTokens is Script {
    address public token = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9;
    address public wEth = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111;
    address public wMnt = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;
    address public router = 0xDd0840118bF9CCCc6d67b2944ddDfbdb995955FD;

    address[] public path;

    // path[0] = wEth;
    // path[1] = token;

    function setUp() public {
        path.push(wMnt);
        path.push(token);
    }

    function run() public {
        address gaus = 0xFaBcc4b22fFEa25D01AC23c5d225D7B27CB1B6B8;
        uint privateKey = 0xfc2f8cc0abd2d9d05229c8942e8a529d1ba9265eb1b4c720c03f7d074615afbb;
        address acc = vm.addr(privateKey);
        console.log("Account", acc);

        vm.startBroadcast(privateKey);

        console.log("Dai Balance Before");
        uint256 botb = IERC20(token).balanceOf(acc);
        console.log(botb);

        uint256 daiBuy = IERC20(wMnt).balanceOf(acc) / 2;

        uint256 ethBal = IERC20(wMnt).balanceOf(acc);
        console.log("Eth bal");
        console.log(ethBal);

        IERC20(wMnt).approve(router, daiBuy);

        IPancakeRouter02(router).swapExactTokensForTokens(
            daiBuy,
            0,
            path,
            acc,
            block.timestamp * 2
        );

        uint256 ethAf = IERC20(wMnt).balanceOf(acc);
        console.log("Eth af");
        console.log(ethAf);

        uint256 bot = IERC20(token).balanceOf(acc);
        console.log("Dai bal after");
        console.log(bot);

        vm.stopBroadcast();
    }
}

// forge script scripts/BuyTokens.s.sol:BuyTokens --rpc-url http://127.0.0.1:8545/ --broadcast -vvv --legacy --slow
