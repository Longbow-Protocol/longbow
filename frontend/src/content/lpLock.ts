export const LP_LOCK_META = {
  title: "The LP Lock",
  eyebrow: "[ PERMANENT LIQUIDITY ]",
  intro:
    "Launch LP for $LONG is burned into a one-way locker. The Uniswap V3 position NFT can never leave. The only callable path after lock is fee collection — and only by the immutable owner.",
  github:
    "https://github.com/Longbow-Finance/contracts/blob/main/src/periphery/UniswapV3LpLocker.sol",
  owner: "0x9096437b3002DC8a14E27A421C094EfCeFD145ae",
} as const;

export const GUARANTEES = [
  {
    tag: "ONE WAY",
    title: "No unlock path",
    body: "There is no decreaseLiquidity, no transferOut, no burn-of-principal. Once burnLP succeeds, the NFT stays in the contract forever.",
  },
  {
    tag: "OWNER ONLY",
    title: "Two gated functions",
    body: "burnLP and safeClaim both require msg.sender == owner. The owner address is immutable — set once in the constructor.",
  },
  {
    tag: "FEES ONLY",
    title: "Collect, never principal",
    body: "safeClaim calls Uniswap’s collect and sends token0/token1 fees to the owner. Liquidity stays in the pool.",
  },
  {
    tag: "SINGLE NFT",
    title: "Lock once",
    body: "positionId can be set only once. A second burnLP reverts with AlreadyLocked — no swapping the locked position later.",
  },
] as const;

export const SURFACE = [
  {
    name: "burnLP",
    sig: "burnLP(uint256 tokenId)",
    who: "owner",
    what: "Pulls the Uniswap V3 position NFT into the locker and records it. Reverts if already locked or tokenId is zero.",
    code: `function burnLP(uint256 tokenId) external onlyOwner {
    if (positionId != 0) revert AlreadyLocked();
    if (tokenId == 0) revert BadToken();

    IERC721(address(positionManager))
        .transferFrom(msg.sender, address(this), tokenId);
    positionId = tokenId;
    emit Locked(tokenId);
}`,
  },
  {
    name: "safeClaim",
    sig: "safeClaim()",
    who: "owner",
    what: "Collects accrued V3 trading fees to the owner. Does not touch liquidity. Reverts if nothing is locked yet.",
    code: `function safeClaim() external onlyOwner
    returns (uint256 amount0, uint256 amount1)
{
    uint256 id = positionId;
    if (id == 0) revert NothingLocked();

    (amount0, amount1) = positionManager.collect(
        CollectParams({
            tokenId: id,
            recipient: owner,
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        })
    );
    emit Claimed(amount0, amount1);
}`,
  },
] as const;

export const ABSENT = [
  "decreaseLiquidity",
  "transfer / safeTransfer of the NFT",
  "setOwner / renounce with a new fee sink",
  "emergency withdraw",
  "pause that freezes fee routing to someone else",
] as const;

export const FULL_SOURCE = `// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {INonfungiblePositionManager} from "../interfaces/IUniswapV3.sol";

contract UniswapV3LpLocker {
    address public immutable owner;
    INonfungiblePositionManager public immutable positionManager;

    uint256 public positionId;

    error NotOwner();
    error ZeroAddress();
    error AlreadyLocked();
    error NothingLocked();
    error BadToken();

    event Locked(uint256 indexed tokenId);
    event Claimed(uint256 amount0, uint256 amount1);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address positionManager_, address owner_) {
        if (positionManager_ == address(0) || owner_ == address(0)) {
            revert ZeroAddress();
        }
        positionManager = INonfungiblePositionManager(positionManager_);
        owner = owner_;
    }

    function burnLP(uint256 tokenId) external onlyOwner {
        if (positionId != 0) revert AlreadyLocked();
        if (tokenId == 0) revert BadToken();

        IERC721(address(positionManager))
            .transferFrom(msg.sender, address(this), tokenId);
        positionId = tokenId;
        emit Locked(tokenId);
    }

    function safeClaim() external onlyOwner
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 id = positionId;
        if (id == 0) revert NothingLocked();

        (amount0, amount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: id,
                recipient: owner,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        emit Claimed(amount0, amount1);
    }
}`;
