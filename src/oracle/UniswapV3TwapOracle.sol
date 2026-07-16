// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/*//////////////////////////////////////////////////////////////////////////////
                                    LONGBOW
                 The leverage layer for $LONG on Robinhood Chain

    Website   https://longbowfi.xyz
    X         https://x.com/longbowfi
    GitHub    https://github.com/Longbow-Finance
//////////////////////////////////////////////////////////////////////////////*/

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IUniswapV3Pool} from "../interfaces/IUniswapV3.sol";
import {OracleLibrary} from "../libraries/OracleLibrary.sol";

/// @title UniswapV3TwapOracle
/// @notice Reads the price of LONG in ETH (WAD) from a Uniswap V3 LONG/WETH pool
///         using the pool's built-in observation oracle. The time-weighted
///         average tick over `window` seconds makes it resistant to single-block
///         / flash-loan manipulation: an attacker would have to hold a
///         manipulated price across the whole averaging window.
/// @dev    Unlike the V2 design, no keeper `update()` is required — the price is
///         read passively via `observe()`. Before the pool has accumulated a full
///         `window` of observations, `observe()` would revert, so we transparently
///         fall back to the pool's spot tick. Increase the pool's observation
///         cardinality at deploy so the TWAP window is actually retained.
contract UniswapV3TwapOracle is IPriceOracle {
    /// @notice The LONG/WETH Uniswap V3 pool this oracle reads from.
    IUniswapV3Pool public immutable pool;
    /// @notice The LONG token (base of the quote).
    address public immutable long;
    /// @notice The WETH token (quote asset — price is denominated in ETH).
    address public immutable weth;
    /// @notice TWAP averaging window, in seconds.
    uint32 public immutable window;

    /// @dev One whole LONG (18 decimals) used as the quote base amount.
    uint128 private constant ONE_LONG = 1e18;

    error ZeroAddress();
    error BadWindow();
    error LongNotInPool();

    /// @param pool_ The Uniswap V3 LONG/WETH pool.
    /// @param long_ The LONG token address (must be one side of the pool).
    /// @param window_ TWAP window in seconds (e.g. 1800 for 30 minutes).
    constructor(address pool_, address long_, uint32 window_) {
        if (pool_ == address(0) || long_ == address(0)) revert ZeroAddress();
        if (window_ == 0) revert BadWindow();

        pool = IUniswapV3Pool(pool_);
        long = long_;
        window = window_;

        address t0 = IUniswapV3Pool(pool_).token0();
        address t1 = IUniswapV3Pool(pool_).token1();
        if (long_ == t0) weth = t1;
        else if (long_ == t1) weth = t0;
        else revert LongNotInPool();
    }

    /// @inheritdoc IPriceOracle
    /// @dev ETH per LONG, scaled by 1e18. Uses the `window`-second TWAP; falls
    ///      back to the current tick if the pool lacks that much history yet.
    function priceWad() external view returns (uint256) {
        int24 tick = _twapTick();
        return OracleLibrary.getQuoteAtTick(tick, ONE_LONG, long, weth);
    }

    /// @notice The current spot price of LONG in ETH (WAD), ignoring the TWAP.
    /// @dev For display/diagnostics only — never use spot to gate liquidations.
    function spotPriceWad() external view returns (uint256) {
        (, int24 tick,,,,,) = pool.slot0();
        return OracleLibrary.getQuoteAtTick(tick, ONE_LONG, long, weth);
    }

    /// @dev Mean tick over the shorter of `window` and the pool's available
    ///      observation history. Falls back to the spot tick when the pool has
    ///      no usable history yet (freshly created / single observation).
    function _twapTick() internal view returns (int24) {
        uint32 w = window;
        uint32 oldest = _oldestSecondsAgo();
        if (oldest < w) w = oldest;
        if (w == 0) {
            (, int24 tick,,,,,) = pool.slot0();
            return tick;
        }

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = w;
        secondsAgos[1] = 0;

        try pool.observe(secondsAgos) returns (int56[] memory tickCumulatives, uint160[] memory) {
            int56 delta = tickCumulatives[1] - tickCumulatives[0];
            int24 mean = int24(delta / int56(uint56(w)));
            if (delta < 0 && (delta % int56(uint56(w)) != 0)) mean--;
            return mean;
        } catch {
            (, int24 tick,,,,,) = pool.slot0();
            return tick;
        }
    }

    /// @dev Seconds since the pool's oldest retained observation (0 if none).
    function _oldestSecondsAgo() internal view returns (uint32) {
        (,, uint16 observationIndex, uint16 observationCardinality,,,) = pool.slot0();
        if (observationCardinality == 0) return 0;

        // The oldest observation sits just after the current index in the ring.
        (uint32 ts,,, bool initialized) = pool.observations((observationIndex + 1) % observationCardinality);
        // Ring not yet full: oldest is slot 0.
        if (!initialized) {
            (ts,,,) = pool.observations(0);
        }
        uint32 nowTs = uint32(block.timestamp);
        return ts == 0 || ts > nowTs ? 0 : nowTs - ts;
    }
}
