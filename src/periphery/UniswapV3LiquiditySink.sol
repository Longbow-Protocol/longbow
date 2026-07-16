// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/*//////////////////////////////////////////////////////////////////////////////
                                    LONGBOW
                 The leverage layer for $LONG on Robinhood Chain

    Website   https://longbowfi.xyz
    X         https://x.com/longbowfi
    GitHub    https://github.com/Longbow-Finance
//////////////////////////////////////////////////////////////////////////////*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILiquiditySink} from "../interfaces/ILiquiditySink.sol";
import {ISwapRouter02, INonfungiblePositionManager, IUniswapV3Pool, IWETH9} from "../interfaces/IUniswapV3.sol";
import {OracleLibrary} from "../libraries/OracleLibrary.sol";
import {TickMath} from "../libraries/TickMath.sol";

/// @title UniswapV3LiquiditySink
/// @notice Turns forfeited (liquidated) ETH collateral into permanent Uniswap V3
///         liquidity. Incoming ETH is wrapped to WETH; half is swapped for LONG,
///         then both legs are added to a single **full-range** LONG/WETH position
///         held by this contract. The contract exposes no way to withdraw or
///         decrease that liquidity, so it is locked forever — matching Longbow's
///         rule that a liquidated deposit permanently supports the pool.
/// @dev    The position NFT is minted to and held by this contract. A future
///         dedicated locker can take over fee collection; today fees simply
///         accrue to the locked position. Confirm the Uniswap V3 addresses on
///         Robinhood Chain before use.
contract UniswapV3LiquiditySink is ILiquiditySink {
    using SafeERC20 for IERC20;

    ISwapRouter02 public immutable router;
    INonfungiblePositionManager public immutable positionManager;
    IUniswapV3Pool public immutable pool;
    IERC20 public immutable long;
    IWETH9 public immutable weth;
    uint24 public immutable fee;
    int24 public immutable tickLower;
    int24 public immutable tickUpper;
    bool public immutable longIsToken0;

    /// @notice Max acceptable slippage on the internal WETH->LONG swap, in bps.
    uint256 public immutable slippageBps;

    /// @notice The full-range position NFT id (0 until the first donation mints it).
    uint256 public positionId;

    error NothingToDonate();
    error ZeroAddress();
    error BadSlippage();
    error LongNotInPool();

    event Donated(uint256 ethIn, uint256 positionId, uint128 liquidityAdded);

    constructor(address router_, address positionManager_, address pool_, address long_, uint256 slippageBps_) {
        if (router_ == address(0) || positionManager_ == address(0) || pool_ == address(0) || long_ == address(0)) {
            revert ZeroAddress();
        }
        if (slippageBps_ >= 10_000) revert BadSlippage();

        router = ISwapRouter02(router_);
        positionManager = INonfungiblePositionManager(positionManager_);
        pool = IUniswapV3Pool(pool_);
        long = IERC20(long_);
        slippageBps = slippageBps_;
        fee = IUniswapV3Pool(pool_).fee();

        address t0 = IUniswapV3Pool(pool_).token0();
        address t1 = IUniswapV3Pool(pool_).token1();
        address weth_;
        if (long_ == t0) {
            weth_ = t1;
            longIsToken0 = true;
        } else if (long_ == t1) {
            weth_ = t0;
            longIsToken0 = false;
        } else {
            revert LongNotInPool();
        }
        weth = IWETH9(weth_);

        int24 spacing = IUniswapV3Pool(pool_).tickSpacing();
        tickLower = (TickMath.MIN_TICK / spacing) * spacing;
        tickUpper = (TickMath.MAX_TICK / spacing) * spacing;
    }

    /// @inheritdoc ILiquiditySink
    function donate() external payable {
        uint256 amount = msg.value;
        if (amount == 0) revert NothingToDonate();

        // 1. Wrap the incoming ETH to WETH.
        weth.deposit{value: amount}();

        // 2. Swap half of the WETH into LONG, slippage-guarded off the spot tick.
        uint256 half = amount / 2;
        IERC20(address(weth)).forceApprove(address(router), half);

        (, int24 spotTick,,,,,) = pool.slot0();
        uint256 expectedLong = OracleLibrary.getQuoteAtTick(spotTick, uint128(half), address(weth), address(long));
        uint256 minLong = expectedLong - (expectedLong * slippageBps) / 10_000;

        router.exactInputSingle(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: address(weth),
                tokenOut: address(long),
                fee: fee,
                recipient: address(this),
                amountIn: half,
                amountOutMinimum: minLong,
                sqrtPriceLimitX96: 0
            })
        );

        // 3. Add everything we hold as full-range liquidity.
        uint256 longBal = long.balanceOf(address(this));
        uint256 wethBal = weth.balanceOf(address(this));

        long.forceApprove(address(positionManager), longBal);
        IERC20(address(weth)).forceApprove(address(positionManager), wethBal);

        (uint256 amount0, uint256 amount1) = longIsToken0 ? (longBal, wethBal) : (wethBal, longBal);

        uint128 liquidityAdded;
        if (positionId == 0) {
            (uint256 id, uint128 liq,,) = positionManager.mint(
                INonfungiblePositionManager.MintParams({
                    token0: longIsToken0 ? address(long) : address(weth),
                    token1: longIsToken0 ? address(weth) : address(long),
                    fee: fee,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    amount0Desired: amount0,
                    amount1Desired: amount1,
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: address(this),
                    deadline: block.timestamp
                })
            );
            positionId = id;
            liquidityAdded = liq;
        } else {
            (uint128 liq,,) = positionManager.increaseLiquidity(
                INonfungiblePositionManager.IncreaseLiquidityParams({
                    tokenId: positionId,
                    amount0Desired: amount0,
                    amount1Desired: amount1,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                })
            );
            liquidityAdded = liq;
        }

        // Clear residual approvals; any dust remains for the next donation.
        long.forceApprove(address(positionManager), 0);
        IERC20(address(weth)).forceApprove(address(positionManager), 0);

        emit Donated(amount, positionId, liquidityAdded);
    }

    receive() external payable {}
}
