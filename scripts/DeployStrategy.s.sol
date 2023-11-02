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

contract deployRivera is Script {
    address public token = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // dai eth Mainnet
    address public wEth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; //wEth aave
    address public debtToken = 0x778A13D3eeb110A4f7bb6529F99c000119a08E92; //Stable debt dai
    address public aToken = 0x028171bCA77440897B824Ca71D1c56caC55b68A3; //aDai
    address public lendle = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9; //aave v2 eth mainnet
    bytes32 public pId =
        0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

    address public lendingPool = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9; // aave main net
    address public riveraVault = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address public router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // univ2
    address public pyth = 0x4305FB66699C3B2702D4d05CF36551390A4c69C6;

    address public partner = 0xFaBcc4b22fFEa25D01AC23c5d225D7B27CB1B6B8; // my address
    uint256 public protocolFee = 0;
    uint256 public partnerFee = 0;
    uint256 public fundManagerFee = 0;
    uint256 public feeDecimals = 100;

    uint256 stratUpdateDelay = 172800;
    uint256 vaultTvlCap = 10000e18;

    function setUp() public {}

    function run() public {
        address gaus = 0xFaBcc4b22fFEa25D01AC23c5d225D7B27CB1B6B8;
        uint privateKey = 0xfc2f8cc0abd2d9d05229c8942e8a529d1ba9265eb1b4c720c03f7d074615afbb;
        address acc = vm.addr(privateKey);
        console.log("Account", acc);

        vm.startBroadcast(privateKey);

        RiveraAutoCompoundingVaultV2Public vault = new RiveraAutoCompoundingVaultV2Public(
                token,
                "Earth-WZETA-ACE-Vault",
                "Earth-WZETA-ACE-Vault",
                stratUpdateDelay,
                vaultTvlCap
            );

        CommonAddresses memory _commonAddresses = CommonAddresses(
            address(vault),
            router
        );

        LendleRivera parentStrategy = new LendleRivera(
            _commonAddresses,
            token,
            wEth,
            debtToken,
            aToken,
            lendle,
            partner,
            lendingPool,
            riveraVault,
            pyth,
            pId
        );

        Weth(wEth).deposit{value: 1e18}();
        uint256 bal = Weth(wEth).balanceOf(acc);
        console.log(bal);
        vault.init(IStrategy(address(parentStrategy)));
        console.log("ParentVault");
        console2.logAddress(address(vault));
        console.log("ParentStrategy");
        console2.logAddress(address(parentStrategy));
        vm.stopBroadcast();
    }
}

//forge script scripts/DeployStrategy.s.sol:deployRivera --rpc-url http://127.0.0.1:8545/ --broadcast -vvv --legacy --slow

// anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/td_qaUjqZjgk924-NBThBa6N0au5ZfMZ --mnemonic "disorder pretty oblige witness close face food stumble name material couch planet"
