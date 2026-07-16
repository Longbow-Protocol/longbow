// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TickMath} from "../../src/libraries/TickMath.sol";

/// @notice Minimal Uniswap V3 pool mock for oracle unit tests. The spot tick and
///         the TWAP (observed) tick are settable independently so tests can prove
///         the oracle averages over `observe()` rather than trusting spot.
contract MockUniswapV3Pool {
    address public immutable token0;
    address public immutable token1;
    uint24 public constant fee = 10_000;
    int24 public constant tickSpacing = 200;

    int24 public spotTick;
    int24 public twapTick;
    uint32 public oldestTimestamp = 1;

    constructor(address tokenA, address tokenB, int24 spotTick_, int24 twapTick_) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        spotTick = spotTick_;
        twapTick = twapTick_;
    }

    function setSpotTick(int24 t) external {
        spotTick = t;
    }

    function setTwapTick(int24 t) external {
        twapTick = t;
    }

    function setOldestTimestamp(uint32 t) external {
        oldestTimestamp = t;
    }

    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        )
    {
        return (TickMath.getSqrtRatioAtTick(spotTick), spotTick, 0, 2, 2, 0, true);
    }

    function observations(uint256)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        )
    {
        return (oldestTimestamp, 0, 0, true);
    }

    /// @dev Returns cumulative ticks consistent with a constant `twapTick`, so the
    ///      mean tick over any window equals `twapTick`.
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        tickCumulatives = new int56[](secondsAgos.length);
        secondsPerLiquidityCumulativeX128s = new uint160[](secondsAgos.length);
        uint32 nowTs = uint32(block.timestamp);
        for (uint256 i; i < secondsAgos.length; i++) {
            uint32 t = nowTs - secondsAgos[i];
            tickCumulatives[i] = int56(int256(twapTick) * int256(uint256(t)));
        }
    }

    function increaseObservationCardinalityNext(uint16) external {}
}
