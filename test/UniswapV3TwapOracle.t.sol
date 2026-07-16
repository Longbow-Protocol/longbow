// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {UniswapV3TwapOracle} from "../src/oracle/UniswapV3TwapOracle.sol";
import {OracleLibrary} from "../src/libraries/OracleLibrary.sol";
import {MockUniswapV3Pool} from "./mocks/MockUniswapV3Pool.sol";

contract UniswapV3TwapOracleTest is Test {
    // Deterministic addresses with a known ordering (long < weth here).
    address internal constant LONG = address(0x1111111111111111111111111111111111111111);
    address internal constant WETH = address(0x2222222222222222222222222222222222222222);

    uint32 internal constant WINDOW = 30 minutes;

    // tick ~ -69080 => price ~1e-3 ETH per LONG; tick 0 => 1:1.
    int24 internal constant TICK_NORMAL = -69080;
    int24 internal constant TICK_HIGH = 0;

    function setUp() public {
        vm.warp(10 days); // give the pool plenty of "history" behind oldestTimestamp
    }

    function _deploy(int24 spot, int24 twap) internal returns (MockUniswapV3Pool pool, UniswapV3TwapOracle oracle) {
        pool = new MockUniswapV3Pool(LONG, WETH, spot, twap);
        oracle = new UniswapV3TwapOracle(address(pool), LONG, WINDOW);
    }

    function test_Constructor_RevertWhenLongNotInPool() public {
        MockUniswapV3Pool pool = new MockUniswapV3Pool(LONG, WETH, 0, 0);
        vm.expectRevert(UniswapV3TwapOracle.LongNotInPool.selector);
        new UniswapV3TwapOracle(address(pool), address(0xdead), WINDOW);
    }

    function test_Constructor_RevertOnZeroWindow() public {
        MockUniswapV3Pool pool = new MockUniswapV3Pool(LONG, WETH, 0, 0);
        vm.expectRevert(UniswapV3TwapOracle.BadWindow.selector);
        new UniswapV3TwapOracle(address(pool), LONG, 0);
    }

    function test_PriceWad_MatchesTwapTick() public {
        (, UniswapV3TwapOracle oracle) = _deploy(TICK_NORMAL, TICK_NORMAL);
        uint256 expected = OracleLibrary.getQuoteAtTick(TICK_NORMAL, 1e18, LONG, WETH);
        assertEq(oracle.priceWad(), expected, "price uses TWAP tick");
        assertApproxEqRel(oracle.priceWad(), 1e15, 1e15, "~1e-3 ETH/LONG"); // ~0.1%
    }

    /// @notice A spot move (flash manipulation) must NOT move the TWAP price.
    function test_SpotMove_DoesNotMoveTwap() public {
        (MockUniswapV3Pool pool, UniswapV3TwapOracle oracle) = _deploy(TICK_NORMAL, TICK_NORMAL);
        uint256 before = oracle.priceWad();

        pool.setSpotTick(TICK_HIGH); // slam spot up ~1000x, TWAP tick unchanged

        assertEq(oracle.priceWad(), before, "TWAP ignores spot slam");
        assertGt(oracle.spotPriceWad(), oracle.priceWad(), "spot reflects the slam");
    }

    /// @notice A sustained move (reflected in the observed cumulative) DOES move price.
    function test_SustainedMove_UpdatesTwap() public {
        (MockUniswapV3Pool pool, UniswapV3TwapOracle oracle) = _deploy(TICK_NORMAL, TICK_NORMAL);
        uint256 low = oracle.priceWad();

        pool.setTwapTick(TICK_HIGH);

        assertGt(oracle.priceWad(), low, "TWAP tracks sustained move");
        assertApproxEqRel(oracle.priceWad(), 1e18, 1e15, "~1:1 after move");
    }

    /// @notice With no usable history, the oracle falls back to the spot tick.
    function test_FallsBackToSpot_WhenNoHistory() public {
        (MockUniswapV3Pool pool, UniswapV3TwapOracle oracle) = _deploy(TICK_NORMAL, TICK_HIGH);
        // Oldest observation is "now" => zero available window => use spot tick.
        pool.setOldestTimestamp(uint32(block.timestamp));

        uint256 spot = OracleLibrary.getQuoteAtTick(TICK_NORMAL, 1e18, LONG, WETH);
        assertEq(oracle.priceWad(), spot, "fell back to spot tick");
    }
}
