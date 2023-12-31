pragma solidity ^0.8.0;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/security/Pausable.sol";
import "@openzeppelin/security/ReentrancyGuard.sol";

import "@pancakeswap-v2-exchange-protocol/interfaces/IPancakeRouter02.sol";
import "./interfaces/IV3SwapRouter.sol";
import "./OracleInterface/IPyth.sol";
import "./interfaces/DataTypes.sol";

import "./interfaces/ILendingPool.sol";
import "./interfaces/IRivera.sol";
import "./interfaces/ILendingPoolAddressesProvider.sol";
import "./interfaces/IMultiFeeDistribution.sol";
import "./interfaces/IMasterChef.sol";
import "../../libs/LiquiMaths.sol";

import "../common/AbstractStrategy.sol";
import "../utils/StringUtils.sol";

contract PdnRivera is AbstractStrategy, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public token;
    address public wEth;
    address public debtToken;
    address public aToken;
    address public lendle;
    address public midToken;
    bytes32 public pId;

    address public lendingPool;
    address public riveraVault;
    address public routerH;
    address public pyth;
    address public multiFee;
    address public claimC;
    uint24 public fees = 500;

    uint256 public ltv;
    address public partner;
    uint256 public protocolFee;
    uint256 public partnerFee;
    uint256 public fundManagerFee;
    uint256 public feeDecimals;
    uint256 public withdrawFee;
    uint256 public withdrawFeeDecimals;

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

    constructor(
        CommonAddresses memory _commonAddresses,
        address _token,
        address _wEth,
        address _lendle,
        address _partner,
        address _lendigPool,
        address _riveraVault,
        address _pyth,
        uint256 _ltv,
        bytes32 _id,
        uint256 _protocolFee,
        uint256 _partnerFee,
        uint256 _fundManagerFee,
        uint256 _feeDecimals,
        address _claimC,
        address _multiFee,
        uint256 _withdrawFee,
        uint256 _withdrawFeeDecimals,
        address _routerH,
        address _midToken
    ) AbstractStrategy(_commonAddresses) {
        token = _token;
        wEth = _wEth;
        lendle = _lendle;
        partner = _partner;
        protocolFee = _protocolFee;
        partnerFee = _partnerFee;
        fundManagerFee = _fundManagerFee;
        feeDecimals = _feeDecimals;
        lendingPool = _lendigPool;
        riveraVault = _riveraVault;
        pyth = _pyth;
        pId = _id;
        ltv = _ltv;
        claimC = _claimC;
        multiFee = _multiFee;
        withdrawFee = _withdrawFee;
        withdrawFeeDecimals = _withdrawFeeDecimals;
        routerH = _routerH;
        midToken = _midToken;

        DataTypes.ReserveData memory w = ILendingPool(lendingPool)
            .getReserveData(wEth);
        DataTypes.ReserveData memory t = ILendingPool(lendingPool)
            .getReserveData(token);
        aToken = t.aTokenAddress;
        debtToken = w.variableDebtTokenAddress;

        _giveAllowances();
    }

    function deposit() public whenNotPaused nonReentrant {
        onlyVault();
        _deposit();
    }

    function _deposit() internal {
        uint256 tBal = IERC20(token).balanceOf(address(this));

        uint256 lendLendle = LiquiMaths.calculateLend(
            ltv,
            tBal,
            uint256(IERC20Metadata(token).decimals())
        );

        depositAave(lendLendle);

        uint256 borrowEth = LiquiMaths.calculateBorrow(
            ltv,
            tBal,
            uint256(IERC20Metadata(token).decimals())
        );
        uint256 amountEth = tokenToEthConversion(borrowEth);

        borrowAave(amountEth);
        uint256 etV = IERC20(wEth).balanceOf(address(this));
        _swapV3In(wEth, token, etV, fees);
        addLiquidity();
    }

    function depositAave(uint256 _supply) internal {
        ILendingPool(lendingPool).deposit(token, _supply, address(this), 0);
    }

    function borrowAave(uint256 _borrowAmount) internal {
        ILendingPool(lendingPool).borrow(
            wEth,
            _borrowAmount,
            2,
            0,
            address(this)
        );
    }

    function addLiquidity() internal {
        uint256 tBal = IERC20(token).balanceOf(address(this));
        IRivera(riveraVault).deposit(tBal, address(this));
    }

    function _swapV3In(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 fee
    ) public returns (uint256 amountOut) {
        amountOut = IV3SwapRouter(router).exactInputSingle(
            IV3SwapRouter.ExactInputSingleParams(
                tokenIn,
                tokenOut,
                fee,
                address(this),
                block.timestamp * 2,
                amountIn,
                0,
                0
            )
        );
    }

    function _swapV2(address tokenA, address tokenB, uint256 _amount) internal {
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        IPancakeRouter02(routerH).swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            block.timestamp * 2
        );
    }

    function withdraw(uint256 _amount) public nonReentrant {
        onlyVault();

        closeAll();

        uint256 wFee = (_amount * withdrawFee) / withdrawFeeDecimals;
        IERC20(token).transfer(
            0xdA2C794f2d2D8aaC0f5C1da3BD3B2C7914D9C4d7,
            wFee
        );
        uint256 toTrans = _amount - wFee;
        uint256 crB = IERC20(token).balanceOf(address(this));
        if (crB > toTrans) {
            IERC20(token).transfer(vault, toTrans);
            _deposit();
        } else {
            IERC20(token).transfer(vault, crB);
        }
    }

    function repayLoan(uint256 _amount) internal {
        ILendingPool(lendingPool).repay(wEth, _amount, 2, address(this));
    }

    function withdrawAave(uint256 _amount) internal {
        ILendingPool(lendingPool).withdraw(token, _amount, address(this));
    }

    function tokenToEthConversion(
        uint256 _amount
    ) public view returns (uint256) {
        uint256 ethPrice = uint256(
            int256(IPyth(pyth).getPriceUnsafe(pId).price)
        );
        uint256 weiU = (1e18 * 1e8) / (ethPrice);
        uint256 deci = IERC20Metadata(token).decimals();
        uint256 borrowEth = (weiU * _amount) / 10 ** deci;

        return borrowEth;
    }

    function ethToTokenConversion(
        uint256 _amount
    ) public view returns (uint256) {
        uint256 ethPrice = uint256(
            int256(IPyth(pyth).getPriceUnsafe(pId).price)
        );

        uint256 weiU = (1e18 * 1e8) / (ethPrice);

        uint256 deci = IERC20Metadata(token).decimals();

        uint256 pUsdc = (_amount * 10 ** deci) / weiU;
        return pUsdc;
    }

    function reBalance() public {
        onlyManager();
        // harvest();
        closeAll();
        _deposit();
    }

    function retireStrat() external {
        onlyVault();
        closeAll();
        uint256 totalBal = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(vault, totalBal);
    }

    function closeAll() internal {
        uint256 rBal = IRivera(riveraVault).balanceOf(address(this));
        uint256 balA = IRivera(riveraVault).convertToAssets(rBal);
        IRivera(riveraVault).withdraw(balA, address(this), address(this));

        uint256 balT = IERC20(token).balanceOf(address(this));
        _swapV3In(token, wEth, balT, fees);

        uint256 debtNow = IERC20(debtToken).balanceOf(address(this));
        repayLoan(debtNow);

        uint256 inAmount = IERC20(aToken).balanceOf(address(this));
        withdrawAave(inAmount);
        balT = IERC20(wEth).balanceOf(address(this));
        _swapV3In(wEth, token, balT, fees);
    }

    function harvest() public whenNotPaused {
        IMultiFeeDistribution(claimC).claim(address(this), forReward);
        (uint256 amount, uint256 penalty) = IMultiFeeDistribution(multiFee)
            .withdrawableBalance(address(this));
        IMultiFeeDistribution(multiFee).withdraw((amount * 99) / 100);
        uint256 lBal = IERC20(lendle).balanceOf(address(this));
        _swapV2(lendle, midToken, lBal);
        uint256 mBal = IERC20(midToken).balanceOf(address(this));
        _swapV3In(midToken, token, mBal, fees);
        _chargeFees(token);
        _deposit();
    }

    function balanceOf() public view returns (uint256) {
        return balanceRivera() + balanceDeposit() - totalDebt();
    }

    function balanceRivera() public view returns (uint256) {
        uint256 balS = IRivera(riveraVault).balanceOf(address(this));
        return IRivera(riveraVault).convertToAssets(balS);
    }

    function balanceDeposit() public view returns (uint256) {
        return IERC20(aToken).balanceOf(address(this));
    }

    function totalDebt() public view returns (uint256) {
        uint256 debt = IERC20(debtToken).balanceOf(address(this));
        return ethToTokenConversion(debt);
    }

    function inCaseTokensGetStuck(address _token) external {
        onlyManager();
        uint256 amount = IERC20(_token).balanceOf(address(this)); //Just finding the balance of this vault contract address in the the passed token and transfers
        IERC20(_token).transfer(msg.sender, amount);
    }

    function _chargeFees(address _token) internal {
        uint256 tokenBal = IERC20(_token).balanceOf(address(this));

        uint256 protocolFeeAmount = (tokenBal * protocolFee) / feeDecimals;
        IERC20(_token).safeTransfer(manager, protocolFeeAmount);

        uint256 fundManagerFeeAmount = (tokenBal * fundManagerFee) /
            feeDecimals;
        IERC20(_token).safeTransfer(owner(), fundManagerFeeAmount);

        uint256 partnerFeeAmount = (tokenBal * partnerFee) / feeDecimals;
        IERC20(_token).safeTransfer(partner, partnerFeeAmount);
    }

    function panic() public {
        onlyManager();
        closeAll();
        pause();
    }

    function pause() public {
        onlyManager();
        _pause();

        _removeAllowances();
    }

    function unpause() external {
        onlyManager();
        _unpause();

        _giveAllowances();

        _deposit();
    }

    function _giveAllowances() internal virtual {
        IERC20(token).approve(router, type(uint256).max);
        IERC20(token).approve(routerH, type(uint256).max);
        IERC20(token).approve(lendingPool, type(uint256).max);
        IERC20(token).approve(riveraVault, type(uint256).max);

        IERC20(wEth).approve(router, type(uint256).max);
        IERC20(wEth).approve(routerH, type(uint256).max);
        IERC20(wEth).approve(lendingPool, type(uint256).max);
        IERC20(wEth).approve(riveraVault, type(uint256).max);

        IERC20(midToken).approve(router, type(uint256).max);
        IERC20(midToken).approve(routerH, type(uint256).max);
        IERC20(midToken).approve(lendingPool, type(uint256).max);
        IERC20(midToken).approve(riveraVault, type(uint256).max);

        IERC20(lendle).approve(router, type(uint256).max);
        IERC20(lendle).approve(routerH, type(uint256).max);
        IERC20(lendle).approve(lendingPool, type(uint256).max);
        IERC20(lendle).approve(riveraVault, type(uint256).max);
    }

    function _removeAllowances() internal virtual {
        IERC20(token).safeApprove(router, 0);
        IERC20(token).safeApprove(lendingPool, 0);
        IERC20(token).safeApprove(riveraVault, 0);

        IERC20(wEth).safeApprove(router, 0);
        IERC20(wEth).safeApprove(lendingPool, 0);
        IERC20(wEth).safeApprove(riveraVault, 0);
    }
}
