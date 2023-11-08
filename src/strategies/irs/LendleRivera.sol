pragma solidity ^0.8.0;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/security/Pausable.sol";
import "@openzeppelin/security/ReentrancyGuard.sol";

import "@pancakeswap-v2-exchange-protocol/interfaces/IPancakeRouter02.sol";
import "./OracleInterface/IPyth.sol";

import "./interfaces/ILendingPool.sol";
import "./interfaces/IRivera.sol";
import "./interfaces/ILendingPoolAddressesProvider.sol";
import "../../libs/LiquiMaths.sol";

import "../common/AbstractStrategy.sol";
import "../utils/StringUtils.sol";

contract LendleRivera is AbstractStrategy, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public token;
    address public wEth;
    address public debtToken;
    address public aToken;
    address public lendle;
    bytes32 public pId;

    address public lendingPool;
    address public riveraVault;
    address public pyth;

    uint256 public ltv;
    address public partner;
    uint256 public protocolFee;
    uint256 public partnerFee;
    uint256 public fundManagerFee;
    uint256 public feeDecimals;

    constructor(
        CommonAddresses memory _commonAddresses,
        address _token,
        address _wEth,
        address _debtToken,
        address _aToken,
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
        uint256 _feeDecimals
    ) AbstractStrategy(_commonAddresses) {
        token = _token;
        wEth = _wEth;
        debtToken = _debtToken;
        aToken = _aToken;
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
        _giveAllowances();
    }

    function deposit() public {
        onlyVault();
        _deposit();
    }

    function _deposit() internal {
        uint256 tBal = IERC20(token).balanceOf(address(this));

        uint256 lendLendle = LiquiMaths.calculateLend(ltv, tBal);

        depositAave(lendLendle);

        uint256 borrowEth = LiquiMaths.calculateBorrow(ltv, tBal);
        uint256 amountEth = tokenToEthConversion(borrowEth);

        borrowAave(amountEth);
        swapTokens(wEth, token, IERC20(wEth).balanceOf(address(this)));
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

    function swapTokens(
        address tokenA,
        address tokenB,
        uint256 amountIn
    ) public {
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        IPancakeRouter02(router).swapExactTokensForTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp * 2
        );
    }

    function withdraw(uint256 _amount) public {
        onlyVault();

        IRivera(riveraVault).withdraw(_amount, address(this), address(this));
        _chargeFees(token);
        uint256 tBal = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(vault, tBal);
    }

    function repayLoan(uint256 _amount) internal {
        ILendingPool(lendingPool).repay(wEth, _amount, 2, address(this));
    }

    function withdrawAave(uint256 _amount) internal {
        ILendingPool(lendingPool).withdraw(token, _amount, address(this));
    }

    function tokenToEthConversion(uint256 _amount) internal returns (uint256) {
        uint256 ethPrice = uint256(
            int256(IPyth(pyth).getPriceUnsafe(pId).price)
        );

        uint256 weiU = ((1 * 10e18) * 10e8) / (ethPrice);
        uint256 borrowEth = ((_amount) * weiU) / 10e7;

        return borrowEth;
    }

    function ethToTokenConversion(
        uint256 _amount
    ) internal view returns (uint256) {
        uint256 ethPrice = uint256(
            int256(IPyth(pyth).getPriceUnsafe(pId).price)
        );

        uint256 weiU = ((1 * 10e18) * 10e8) / (ethPrice);

        uint256 pUsdc = (_amount * 10e6) / weiU;
        return pUsdc;
    }

    function reBalance() public {
        onlyManager();
        //harvest();

        uint256 rBal = IRivera(riveraVault).balanceOf(address(this));
        IRivera(riveraVault).withdraw(rBal, address(this), address(this));

        uint256 balT = IERC20(token).balanceOf(address(this));
        swapTokens(token, wEth, balT);

        uint256 debtNow = IERC20(debtToken).balanceOf(address(this));
        repayLoan(debtNow);

        uint256 inAmount = IERC20(aToken).balanceOf(address(this));
        withdrawAave(inAmount);
        balT = IERC20(wEth).balanceOf(address(this));
        swapTokens(wEth, token, balT);

        _deposit();
    }

    function harvest() public {
        // to convert lendle reward

        // ILendingPool(lendingPool).getReward();
        uint256 lBal = IERC20(lendle).balanceOf(address(this));
        _chargeFees(token);
        swapTokens(lendle, token, lBal);
        _deposit();
    }

    function balanceOf() public view returns (uint256) {
        return balanceRivera() + balanceDeposit() - totalDebt();
    }

    function balanceRivera() public view returns (uint256) {
        return IRivera(riveraVault).balanceOf(address(this));
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
        uint256 rBal = IRivera(riveraVault).balanceOf(address(this));
        IRivera(riveraVault).withdraw(rBal, address(this), address(this));

        uint256 balT = IERC20(token).balanceOf(address(this));
        swapTokens(token, wEth, balT);

        uint256 debtNow = IERC20(debtToken).balanceOf(address(this));
        repayLoan(debtNow);

        uint256 inAmount = IERC20(aToken).balanceOf(address(this));
        withdrawAave(inAmount);
        balT = IERC20(wEth).balanceOf(address(this));
        swapTokens(wEth, token, balT);
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

        deposit();
    }

    function _giveAllowances() internal virtual {
        IERC20(token).approve(router, type(uint256).max);
        IERC20(token).approve(lendingPool, type(uint256).max);
        IERC20(token).approve(riveraVault, type(uint256).max);

        IERC20(wEth).approve(router, type(uint256).max);
        IERC20(wEth).approve(lendingPool, type(uint256).max);
        IERC20(wEth).approve(riveraVault, type(uint256).max);
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
