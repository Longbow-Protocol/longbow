// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LongToken} from "../../src/LongToken.sol";
import {PositionManager} from "../../src/PositionManager.sol";
import {UniswapV3TwapOracle} from "../../src/oracle/UniswapV3TwapOracle.sol";
import {UniswapV3LiquiditySink} from "../../src/periphery/UniswapV3LiquiditySink.sol";
import {INonfungiblePositionManager, IUniswapV3Pool, IWETH9} from "../../src/interfaces/IUniswapV3.sol";
import {FullMath} from "../../src/libraries/FullMath.sol";
import {TickMath} from "../../src/libraries/TickMath.sol";
import {MockPriceOracle} from "../mocks/MockPriceOracle.sol";

/// @notice Integration tests against the REAL Uniswap V3 deployment on Robinhood
///         Chain. These validate what unit tests can only mock: creating + seeding
///         a real V3 pool, the TWAP oracle reading the pool's observations, and the
///         liquidity sink zapping ETH into a locked full-range position.
///
/// @dev Gated on `FORK_RPC_URL`. Run with:
///        FORK_RPC_URL=https://rpc.mainnet.chain.robinhood.com \
///          forge test --match-path 'test/fork/*'
///      When the env var is unset (e.g. offline CI), every test skips cleanly.
contract RobinhoodForkTest is Test {
    // Uniswap V3 on Robinhood Chain (4663) — reconfirm on Blockscout before mainnet use.
    address internal constant POSITION_MANAGER = 0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3;
    address internal constant SWAP_ROUTER = 0xCaf681a66D020601342297493863E78C959E5cb2;
    address internal constant WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
    uint24 internal constant FEE = 10_000;

    uint256 internal constant SUPPLY = 1_000_000_000 ether;
    uint256 internal constant HALF = SUPPLY / 2;
    uint256 internal constant SEED_ETH = 10 ether;
    uint32 internal constant PERIOD = 30 minutes;

    bool internal enabled;
    LongToken internal long;
    address internal pool;
    bool internal longIsToken0;

    receive() external payable {}

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", string(""));
        if (bytes(rpc).length == 0) return; // stays disabled -> tests skip
        vm.createSelectFork(rpc);
        require(POSITION_MANAGER.code.length > 0, "NPM not present on fork");
        enabled = true;

        long = new LongToken(SUPPLY, address(this));
        vm.deal(address(this), 100 ether);
        longIsToken0 = address(long) < WETH;

        pool = _createAndSeedPool();
    }

    function _createAndSeedPool() internal returns (address p) {
        (address token0, address token1) = longIsToken0 ? (address(long), WETH) : (WETH, address(long));
        uint160 sqrtPriceX96 = longIsToken0 ? _encodeSqrtPriceX96(SEED_ETH, HALF) : _encodeSqrtPriceX96(HALF, SEED_ETH);

        p = INonfungiblePositionManager(POSITION_MANAGER)
            .createAndInitializePoolIfNecessary(token0, token1, FEE, sqrtPriceX96);
        IUniswapV3Pool(p).increaseObservationCardinalityNext(200);

        IWETH9(WETH).deposit{value: SEED_ETH}();
        IERC20(address(long)).approve(POSITION_MANAGER, HALF);
        IERC20(WETH).approve(POSITION_MANAGER, SEED_ETH);

        int24 spacing = IUniswapV3Pool(p).tickSpacing();
        INonfungiblePositionManager(POSITION_MANAGER)
            .mint(
                INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: FEE,
                tickLower: (TickMath.MIN_TICK / spacing) * spacing,
                tickUpper: (TickMath.MAX_TICK / spacing) * spacing,
                amount0Desired: longIsToken0 ? HALF : SEED_ETH,
                amount1Desired: longIsToken0 ? SEED_ETH : HALF,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
            );
    }

    function test_Fork_TwapReflectsSeededPrice() public {
        if (!enabled) {
            vm.skip(true);
            return;
        }

        UniswapV3TwapOracle oracle = new UniswapV3TwapOracle(pool, address(long), PERIOD);

        // Expected genesis price P0 = SEED_ETH / HALF (ETH per LONG), in WAD.
        uint256 expected = (SEED_ETH * 1e18) / HALF;

        skip(PERIOD + 1);
        assertApproxEqRel(oracle.priceWad(), expected, 1e16, "TWAP ~ seeded price"); // 1%
    }

    function test_Fork_SinkDonateGrowsLockedLiquidity() public {
        if (!enabled) {
            vm.skip(true);
            return;
        }

        UniswapV3LiquiditySink sink =
            new UniswapV3LiquiditySink(SWAP_ROUTER, POSITION_MANAGER, pool, address(long), 500); // 5% slippage
        uint128 liqBefore = IUniswapV3Pool(pool).liquidity();

        sink.donate{value: 1 ether}();

        assertGt(IUniswapV3Pool(pool).liquidity(), liqBefore, "locked liquidity grew");
        assertGt(sink.positionId(), 0, "sink minted a locked position");
        assertEq(address(sink).balance, 0, "sink holds no leftover ETH");
    }

    function test_Fork_LiquidationDonatesIntoRealLp() public {
        if (!enabled) {
            vm.skip(true);
            return;
        }

        MockPriceOracle oracle = new MockPriceOracle(1e15);
        UniswapV3LiquiditySink sink =
            new UniswapV3LiquiditySink(SWAP_ROUTER, POSITION_MANAGER, pool, address(long), 500);
        PositionManager pm = new PositionManager(
            address(long), address(oracle), address(sink), address(this), 10 ether, 500, 100, 0.01 ether
        );
        long.transfer(address(pm), 100_000_000 ether); // reserve

        address user = makeAddr("user");
        vm.deal(user, 10 ether);
        vm.prank(user);
        uint256 id = pm.openPosition{value: 1 ether}(2 ether);

        oracle.setPrice(1e15 / 2); // drop 50% -> liquidatable at 2x

        uint128 liqBefore = IUniswapV3Pool(pool).liquidity();
        pm.liquidate(id); // this contract acts as keeper
        assertGt(IUniswapV3Pool(pool).liquidity(), liqBefore, "liquidation locked new liquidity");
        assertFalse(pm.getPosition(id).open, "position closed");
    }

    function _encodeSqrtPriceX96(uint256 amount1, uint256 amount0) internal pure returns (uint160) {
        uint256 ratioX192 = FullMath.mulDiv(amount1, 1 << 192, amount0);
        uint256 s = _sqrt(ratioX192);
        require(s <= type(uint160).max, "sqrtPrice overflow");
        return uint160(s);
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
