pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "@openzeppelin/token/ERC20/IERC20.sol";
import "../src/strategies/irs/LendleRivera.sol";
import "../src/strategies/irs/interfaces/ILendleRivera.sol";
import "../src/vaults/RiveraAutoCompoundingVaultV2Public.sol";
import "../src/strategies/common/AbstractStrategy.sol";
import "../src/strategies/irs/interfaces/IRivera.sol";
import "../src/strategies/common/interfaces/IStrategy.sol";
import "../src/strategies/irs/interfaces/ILendingPool.sol";
import "../src/strategies/irs/interfaces/IMultiFeeDistribution.sol";
import "../src/strategies/irs/interfaces/IMasterChef.sol";
import "../src/libs/LiquiMaths.sol";

contract StrategyTest is Test {
    address vault = 0x8a1b62c438B7b1d73A7a323C6b685fEc021610aC;
    address strat = 0xf5eB7A02d1B8Dc14D5419Ee9F3f4DeE342960e08;
    address riveraVault = 0x5f247B216E46fD86A09dfAB377d9DBe62E9dECDA;
    address lendingPool = 0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3;
    address masterC = 0xC90C10c7e3B2F14870cC870A046Bd099CCDDEe12;
    address multifee = 0x5C75A733656c3E42E44AFFf1aCa1913611F49230;
    address tokenVesting = 0xA7f784Dc0EC287342B0B84e63961eFfA541f7E6f;
    address chiefI = 0x79e2fd1c484EB9EE45001A98Ce31F28918F27C41;

    address token = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9;
    address wEth = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111;
    address lendel = 0x25356aeca4210eF7553140edb9b8026089E49396;
    address debtToken = 0x5DF9a4BE4F9D717b2bFEce9eC350DcF4cbCb91d8;
    address aToken = 0xF36AFb467D1f05541d998BBBcd5F7167D67bd8fC;

    address manager = 0x69605b7A74D967a3DA33A20c1b94031BC6cAF27c;
    address normalU = 0xf12Ac6acb0B8542B1c717E520A5B4C085222e4b9;
    address ethWhale = 0xf89d7b9c864f589bbF53a82105107622B35EaA40;
    address user = 0xFaBcc4b22fFEa25D01AC23c5d225D7B27CB1B6B8;

    uint256 one = 1e6;
    uint256 oneEth = 1e18;

    address[] public forReward = [
        0xF36AFb467D1f05541d998BBBcd5F7167D67bd8fC,
        0x334a542b51212b8Bcd6F96EfD718D55A9b7D1c35,
        0xE71cbaaa6B093FcE66211E6f218780685077D8B5,
        0xaC3c14071c80819113DF501E1AB767be910d5e5a,
        0x44CCCBbD7A5A9e2202076ea80C185DA0058f1715,
        0x42f9F9202D5F4412148662Cf3bC68D704c8E354f,
        0x787Cb0D29194f0fAcA73884C383CF4d2501bb874,
        0x5DF9a4BE4F9D717b2bFEce9eC350DcF4cbCb91d8,
        0x683696523512636B46A826A7e3D1B0658E8e2e1c,
        0x18d3E4F9951fedcdDD806538857eBED2F5F423B7
    ];

    function setUp() public {
        vm.startPrank(ethWhale);

        IERC20(token).transfer(user, 1000000 * one);
        IERC20(token).transfer(normalU, 10000 * one);

        IERC20(wEth).transfer(user, 100 * oneEth);

        uint256 mybal = IERC20(token).balanceOf(ethWhale);
        uint256 dpDai = one * 1000;
        IERC20(token).approve(vault, dpDai);
        RiveraAutoCompoundingVaultV2Public(vault).deposit(dpDai, ethWhale);
        vm.warp(block.timestamp + 7 * 24 * 60 * 60);

        vm.stopPrank();
    }

    function test_Transfer() public {
        vm.startPrank(user);

        uint256 bal = IERC20(token).balanceOf(user);
        // console.log("balance USDC", bal);
        uint256 ethB = IERC20(wEth).balanceOf(user);
        // console.log("Weth Balance", ethB);
        // assertEq(bal, 1000000 * 1e6);
        // assertEq(ethB, 100 * 1e18);

        vm.stopPrank();
    }

    function test_DepositTokenNotPaused() public {
        vm.startPrank(user);

        uint256 mybal = IERC20(token).balanceOf(user);
        uint256 dpDai = one * 10;
        IERC20(token).approve(vault, dpDai);
        RiveraAutoCompoundingVaultV2Public(vault).deposit(dpDai, user);

        uint256 totalA = RiveraAutoCompoundingVaultV2Public(vault)
            .totalAssets();

        uint256 balVal = RiveraAutoCompoundingVaultV2Public(vault).balanceOf(
            user
        );

        uint256 shaToAsset = RiveraAutoCompoundingVaultV2Public(vault)
            .convertToAssets(balVal);

        console.log("Balance of Strategy", totalA);
        console.log("Balance of user in Vault", balVal);
        console.log("user share to assets", shaToAsset);

        // assertEq(totalA, shaToAsset);
        // assertLe(totalA, dpDai);
        vm.stopPrank();
    }

    // function test_HarvestDirectly() public {
    //     vm.startPrank(user);

    //     uint256 mybal = IERC20(token).balanceOf(user);
    //     uint256 dpDai = one * 1000;
    //     IERC20(token).approve(vault, dpDai);
    //     RiveraAutoCompoundingVaultV2Public(vault).deposit(dpDai, user);
    //     vm.warp(block.timestamp + 7 * 24 * 60 * 60);
    //     vm.stopPrank();

    //     vm.startPrank(strat);
    //     IMultiFeeDistribution(chiefI).claim(strat, forReward);
    //     (uint256 amount, uint256 penalty) = IMultiFeeDistribution(multifee)
    //         .withdrawableBalance(strat);
    //     vm.stopPrank();
    //     console.log(IMultiFeeDistribution(multifee).totalBalance(strat));
    //     console.log("amount ", amount);
    //     console.log("penalty", penalty);
    //     console.log(
    //         "total bal",
    //         IMultiFeeDistribution(multifee).totalBalance(strat)
    //     );
    //     vm.startPrank(strat);

    //     IMultiFeeDistribution(multifee).withdraw(amount);
    //     vm.stopPrank();
    //     console.log(IERC20(lendel).balanceOf(strat));
    //     console.log(IMultiFeeDistribution(multifee).totalBalance(strat));
    // }

    function test_HarvestByUser() public {
        vm.startPrank(user);

        uint256 mybal = IERC20(token).balanceOf(user);
        uint256 dpDai = one * 1000;
        IERC20(token).approve(vault, dpDai);
        RiveraAutoCompoundingVaultV2Public(vault).deposit(dpDai, user);
        vm.warp(block.timestamp + 7 * 24 * 60 * 60);
        vm.stopPrank();

        console.log("total Assets before", IStrategy(strat).balanceOf());

        vm.startPrank(user);
        vm.warp(block.timestamp + 7 * 24 * 60 * 60);
        IStrategy(strat).harvest();
        vm.stopPrank();
        console.log("total Assets after", IStrategy(strat).balanceOf());
    }

    // function test_BorrowOutside() public {
    //     vm.startPrank(normalU);
    //     uint256 dpDai = one * 1000;
    //     uint256 depoI = LiquiMaths.calculateLend(80, dpDai, 6);
    //     uint256 borU = LiquiMaths.calculateBorrow(80, dpDai, 6);
    //     uint256 borE = IStrategy(strat).tokenToEthConversion(borU);
    //     IERC20(token).approve(lendingPool, dpDai);
    //     ILendingPool(lendingPool).deposit(token, depoI, normalU, 0);
    //     ILendingPool(lendingPool).borrow(wEth, borE, 2, 0, normalU);
    //     console.log("total debtU", borU);
    //     console.log("total eth", borE);
    //     console.log("in account", IERC20(wEth).balanceOf(normalU));
    //     console.log(
    //         "amount calculated",
    //         IStrategy(strat).ethToTokenConversion(borE)
    //     );
    // }

    // function test_DepositTokenMulti(uint256 _amount) public {
    //     vm.assume(_amount >= one && _amount < 1000 * one);

    //     vm.startPrank(user);

    //     IERC20(token).approve(vault, _amount);
    //     RiveraAutoCompoundingVaultV2Public(vault).deposit(_amount, user);

    //     uint256 balVal = RiveraAutoCompoundingVaultV2Public(vault).balanceOf(
    //         user
    //     );
    //     uint256 inU = RiveraAutoCompoundingVaultV2Public(vault).convertToAssets(
    //         balVal
    //     );

    //     // assertEq(inU, RiveraAutoCompoundingVaultV2Public(vault).totalAssets());
    // }

    // function test_DepositWrongToken() public {
    //     vm.startPrank(user);

    //     uint256 mybal = IERC20(wEth).balanceOf(user);
    //     uint256 dpDai = one * 10;
    //     IERC20(wEth).approve(vault, dpDai);
    //     vm.expectRevert();
    //     RiveraAutoCompoundingVaultV2Public(vault).deposit(dpDai, user);
    //     vm.stopPrank();
    // }

    // function test_DepositTokenPaused() public {
    //     vm.startPrank(manager);

    //     IStrategy(strat).pause();

    //     vm.stopPrank();

    //     vm.startPrank(user);

    //     uint256 mybal = IERC20(token).balanceOf(user);
    //     uint256 dpDai = mybal / 10;
    //     IERC20(token).approve(vault, dpDai);
    //     vm.expectRevert();
    //     RiveraAutoCompoundingVaultV2Public(vault).deposit(dpDai, user);

    //     vm.stopPrank();
    // }

    // function test_DepositAllLogics() public {
    //     vm.startPrank(user);

    //     uint256 mybal = IERC20(token).balanceOf(user);
    //     uint256 dpDai = one * 1000;
    //     IERC20(token).approve(vault, dpDai);
    //     RiveraAutoCompoundingVaultV2Public(vault).deposit(dpDai, user);

    //     vm.stopPrank();

    //     uint256 depoI = LiquiMaths.calculateLend(80, dpDai, 6);
    //     uint256 borU = LiquiMaths.calculateBorrow(80, dpDai, 6);
    //     uint256 borE = IStrategy(strat).tokenToEthConversion(borU);
    //     uint256 inRI = dpDai - depoI + borU;
    //     uint256 totalaa = inRI + depoI - borU;
    //     console.log(
    //         "Vault total assets",
    //         RiveraAutoCompoundingVaultV2Public(vault).totalAssets()
    //     );
    //     console.log("total loan", IStrategy(strat).totalDebt());
    //     console.log("total deposit", IStrategy(strat).balanceDeposit());
    //     console.log("total in rivera", IStrategy(strat).balanceRivera());
    //     console.log("remaining", IERC20(token).balanceOf(strat));
    //     console.log("remaining weth", IERC20(wEth).balanceOf(strat));
    //     console.log("calculated outside");
    //     console.log("total loan", borU);
    //     console.log("total deposit", depoI);
    //     console.log("total in rivera", inRI);
    //     console.log("total in assets outside", totalaa);
    //     console.log("remaining", IERC20(token).balanceOf(strat));
    //     console.log("remaining weth", IERC20(wEth).balanceOf(strat));
    //     console.log(
    //         "strat balance in rivera",
    //         RiveraAutoCompoundingVaultV2Public(riveraVault).balanceOf(strat)
    //     );
    // }

    // function test_WithdrawToken() public {
    //     vm.startPrank(user);
    //     uint256 mybal = IERC20(token).balanceOf(user);
    //     uint256 dpDai = 1000 * one;
    //     IERC20(token).approve(vault, dpDai);
    //     RiveraAutoCompoundingVaultV2Public(vault).deposit(dpDai, user);

    //     uint256 totalA = RiveraAutoCompoundingVaultV2Public(vault)
    //         .totalAssets();

    //     console.log("vault balance after deposit", totalA);

    //     uint256 balVal = RiveraAutoCompoundingVaultV2Public(vault).balanceOf(
    //         user
    //     );

    //     uint256 bU = RiveraAutoCompoundingVaultV2Public(vault).convertToAssets(
    //         balVal
    //     );
    //     console.log("Balance of user after depo", bU);

    //     RiveraAutoCompoundingVaultV2Public(vault).withdraw(bU, user, user);

    //     console.log(
    //         "balance of user after withdraw",
    //         RiveraAutoCompoundingVaultV2Public(vault).balanceOf(user)
    //     );
    //     console.log(
    //         "vault balance after withdraw",
    //         RiveraAutoCompoundingVaultV2Public(vault).totalAssets()
    //     );
    //     console.log("total loan", IStrategy(strat).totalDebt());
    //     console.log("total deposit", IStrategy(strat).balanceDeposit());
    //     console.log("total in rivera", IStrategy(strat).balanceRivera());
    //     console.log(
    //         "fee withdraw",
    //         IERC20(token).balanceOf(0xdA2C794f2d2D8aaC0f5C1da3BD3B2C7914D9C4d7)
    //     );
    //     // assertEq(RiveraAutoCompoundingVaultV2Public(vault).balanceOf(user), 0);
    //     // assertEq(RiveraAutoCompoundingVaultV2Public(vault).totalAssets(), 0);
    //     vm.stopPrank();
    // }

    // function test_WithdrawTokenMulti(uint256 _amount) public {
    //     vm.assume(_amount >= one && _amount < 1000 * one);

    //     vm.startPrank(user);
    //     IERC20(token).approve(vault, _amount);
    //     RiveraAutoCompoundingVaultV2Public(vault).deposit(_amount, user);

    //     uint256 totalA = RiveraAutoCompoundingVaultV2Public(vault)
    //         .totalAssets();

    //     uint256 balVal = RiveraAutoCompoundingVaultV2Public(vault).balanceOf(
    //         user
    //     );
    //     uint256 bU = RiveraAutoCompoundingVaultV2Public(vault).convertToAssets(
    //         balVal
    //     );

    //     RiveraAutoCompoundingVaultV2Public(vault).withdraw(bU, user, user);
    //     // assertEq(RiveraAutoCompoundingVaultV2Public(vault).balanceOf(user), 0);
    //     // assertEq(RiveraAutoCompoundingVaultV2Public(vault).totalAssets(), 0);
    //     vm.stopPrank();
    // }

    // function test_PanicWithManager() public {
    //     vm.startPrank(user);
    //     uint256 mybal = IERC20(token).balanceOf(user);
    //     uint256 dpDai = one * 10;
    //     IERC20(token).approve(vault, dpDai);
    //     RiveraAutoCompoundingVaultV2Public(vault).deposit(dpDai, user);
    //     vm.stopPrank();

    //     vm.startPrank(manager);
    //     IStrategy(strat).panic();
    //     vm.stopPrank();
    //     assertEq(IStrategy(strat).paused(), true);

    //     uint256 balRi = IRivera(riveraVault).balanceOf(strat);
    //     uint256 dbt = IERC20(debtToken).balanceOf(strat);
    //     uint256 depoo = IERC20(aToken).balanceOf(strat);
    //     console.log("balri", balRi);
    //     console.log("dbt", dbt);
    //     console.log("depoo", depoo);

    //     assertEq(balRi, 0);
    //     assertEq(dbt, 0);
    //     assertEq(depoo, 0);
    // }

    // function test_PauseAndUnpause() public {
    //     vm.startPrank(user);
    //     uint256 mybal = IERC20(token).balanceOf(user);
    //     uint256 dpDai = mybal / 10;
    //     IERC20(token).approve(vault, dpDai);
    //     RiveraAutoCompoundingVaultV2Public(vault).deposit(dpDai, user);
    //     vm.stopPrank();

    //     vm.startPrank(manager);
    //     IStrategy(strat).panic();
    //     vm.stopPrank();
    //     assertEq(IStrategy(strat).paused(), true);

    //     vm.startPrank(manager);
    //     IStrategy(strat).unpause();
    //     vm.stopPrank();
    //     assertEq(IStrategy(strat).paused(), false);
    // }

    // function test_retierStratDirectly() public {
    //     vm.startPrank(user);

    //     uint256 mybal = IERC20(token).balanceOf(user);
    //     uint256 dpDai = mybal / 10;
    //     IERC20(token).approve(vault, dpDai);
    //     RiveraAutoCompoundingVaultV2Public(vault).deposit(dpDai, user);
    //     vm.stopPrank();

    //     vm.startPrank(vault);
    //     IStrategy(strat).retireStrat();
    //     uint256 bNow = IERC20(token).balanceOf(strat);

    //     assertEq(bNow, 0);
    //     vm.stopPrank();
    // }

    // function test_reBalanceWithoutManager() public {
    //     vm.startPrank(user);

    //     uint256 mybal = IERC20(token).balanceOf(user);
    //     uint256 dpDai = mybal / 10;
    //     IERC20(token).approve(vault, dpDai);
    //     RiveraAutoCompoundingVaultV2Public(vault).deposit(dpDai, user);

    //     vm.expectRevert();
    //     IStrategy(strat).reBalance();

    //     vm.stopPrank();
    // }

    // function test_reBalanceWithManager() public {
    //     vm.startPrank(user);

    //     uint256 mybal = IERC20(token).balanceOf(user);
    //     uint256 dpDai = mybal / 10;
    //     IERC20(token).approve(vault, dpDai);
    //     RiveraAutoCompoundingVaultV2Public(vault).deposit(dpDai, user);

    //     vm.stopPrank();

    //     vm.startPrank(manager);
    //     IStrategy(strat).reBalance();
    //     vm.stopPrank();
    // }
}

//forge test --fork-url http://127.0.0.1:8545/ --match-path test/StrategyTest.t.sol -vvv
