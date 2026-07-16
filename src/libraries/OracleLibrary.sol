// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IUniswapV3Pool} from "../interfaces/IUniswapV3.sol";
import {FullMath} from "./FullMath.sol";
import {TickMath} from "./TickMath.sol";

/// @title Oracle library
/// @notice Provides functions to integrate with a Uniswap V3 pool's built-in
///         oracle. Port of Uniswap v3-periphery `OracleLibrary` to 0.8.x.
library OracleLibrary {
    /// @notice Calculates the arithmetic mean tick over `secondsAgo` seconds.
    /// @param pool Address of the Uniswap V3 pool.
    /// @param secondsAgo Length of the TWAP window, in seconds.
    /// @return arithmeticMeanTick The time-weighted average tick over the window.
    function consult(address pool, uint32 secondsAgo) internal view returns (int24 arithmeticMeanTick) {
        require(secondsAgo != 0, "BP");

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives,) = IUniswapV3Pool(pool).observe(secondsAgos);
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];

        arithmeticMeanTick = int24(tickCumulativesDelta / int56(uint56(secondsAgo)));
        // Always round to negative infinity.
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(uint56(secondsAgo)) != 0)) {
            arithmeticMeanTick--;
        }
    }

    /// @notice Given a tick and a token amount, calculates the amount of the other token.
    /// @param tick Tick value used to compute the quote.
    /// @param baseAmount Amount of `baseToken` to be converted.
    /// @param baseToken Address of the token the `baseAmount` is denominated in.
    /// @param quoteToken Address of the token quoted against.
    /// @return quoteAmount Amount of `quoteToken` for `baseAmount` of `baseToken`.
    function getQuoteAtTick(int24 tick, uint128 baseAmount, address baseToken, address quoteToken)
        internal
        pure
        returns (uint256 quoteAmount)
    {
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);

        // Avoid overflow when the ratio fits in 128 bits.
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }
}
