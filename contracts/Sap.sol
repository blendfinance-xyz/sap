// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { IBlast } from "../interfaces/IBlast.sol";

contract Sap is Ownable, ERC20 {
  struct Asset {
    address token;
    bytes32 priceId;
    ERC20 tokenContract;
  }

  IPyth private _pyth;
  Asset[] private _assets;

  constructor(
    string memory name_,
    string memory symbol_,
    address pyth_,
    address[] memory tokens_,
    bytes32[] memory priceIds_
  ) Ownable(msg.sender) ERC20(name_, symbol_) {
    _pyth = IPyth(pyth_);
    for (uint256 i = 0; i < tokens_.length; i++) {
      _assets.push(
        Asset({
          token: tokens_[i],
          priceId: priceIds_[i],
          tokenContract: ERC20(tokens_[i])
        })
      );
    }
    // remark this line before test, because blast is not available on local
    // IBlast(0x4300000000000000000000000000000000000002).configureClaimableGas();
  }

  /**
   * @dev get the pyth address
   * @return the pyth address
   */
  function getPyth() public view returns (address) {
    return address(_pyth);
  }

  function _getAssetByToken(
    address token
  ) internal view returns (Asset memory) {
    for (uint256 i = 0; i < _assets.length; i++) {
      if (_assets[i].token == token) {
        return _assets[i];
      }
    }
    revert("Staking: asset not found");
  }

  /**
   * @dev get the asset token address
   * @param index the index of the asset
   * @return the asset token address
   */
  function getAssetToken(uint256 index) public view returns (address) {
    return _assets[index].token;
  }

  /**
   * @dev get the asset price id
   * @param index the index of the asset
   * @return the asset price id
   */
  function getAssetPriceId(uint256 index) public view returns (bytes32) {
    return _assets[index].priceId;
  }

  function _calculateAssetPrice(
    PythStructs.Price memory price,
    uint8 targetDecimals
  ) internal pure returns (uint256) {
    require(price.price > 0, "SAP: invalid price");
    require(price.expo < 0, "SAP: invalid price expo");
    require(price.expo > -255, "SAP: invalid price expo");
    uint8 priceDecimals = uint8(uint32(-1 * price.expo));
    if (priceDecimals >= targetDecimals) {
      return uint(uint64(price.price)) * 10 ** (priceDecimals - targetDecimals);
    } else {
      return uint(uint64(price.price)) / 10 ** (targetDecimals - priceDecimals);
    }
  }

  /**
   * @dev calculate the price of the pool
   */
  function calculatePrice() public view returns (uint256) {
    uint256 volumn = 0;
    for (uint256 i = 0; i < _assets.length; i++) {
      Asset memory asset = _assets[i];
      uint256 assetPrice = _calculateAssetPrice(
        _pyth.getPrice(asset.priceId),
        decimals()
      );
      uint256 assetBalance = asset.tokenContract.balanceOf(address(this));
      volumn += Math.mulDiv(
        assetPrice,
        assetBalance,
        10 ** asset.tokenContract.decimals()
      );
    }
    return _safeDiv(volumn, totalSupply());
  }

  /**
   * @dev deposit token to the pool, could only deposit the first token
   */
  function deposit(uint256 amount) external onlyOwner returns (uint256) {
    Asset memory asset = _assets[0];
    asset.tokenContract.transferFrom(msg.sender, address(this), amount);
    // asset price
    uint256 assetPrice = _calculateAssetPrice(
      _pyth.getPrice(asset.priceId),
      decimals()
    );
    // sap price
    uint256 price = calculatePrice();
    uint256 mintAmount = Math.mulDiv(amount, assetPrice, price);
    _mint(msg.sender, mintAmount);
    return mintAmount;
  }

  /**
   * @dev swap tokenIn to tokenOut
   * @param router_ uniswap router
   * @param amountIn the amount of tokenIn
   * @param tokenIn the token to put
   * @param tokenOut the token to get
   */
  function swap(
    address router_,
    uint256 amountIn,
    address tokenIn,
    address tokenOut
  ) external onlyOwner {
    IUniswapV2Router02 router = IUniswapV2Router02(router_);
    address[] memory path = new address[](2);
    path[0] = tokenIn;
    path[1] = tokenOut;
    router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
      amountIn,
      0,
      path,
      address(this),
      block.timestamp + 60
    );
  }

  /**
   * @dev buy sap, could put in any token in the pool
   * @param amount the amount of sap to buy
   * @param token the token to pay
   * @return the amount of token paied
   */
  function buy(uint256 amount, address token) external returns (uint256) {
    // sap price
    uint256 price = calculatePrice();
    // asset price
    Asset memory asset = _getAssetByToken(token);
    uint256 assetPrice = _calculateAssetPrice(
      _pyth.getPrice(asset.priceId),
      decimals()
    );
    uint256 payAmount = Math.mulDiv(amount, price, assetPrice);
    asset.tokenContract.transferFrom(msg.sender, address(this), payAmount);
    _mint(msg.sender, amount);
    return payAmount;
  }

  /**
   * @dev sell sap, could get out any token in the pool
   * @param amount the amount of sap to sell
   * @param token the token to get out
   * @return the amount of token received
   */
  function sell(uint256 amount, address token) external returns (uint256) {
    // sap price
    uint256 price = calculatePrice();
    // asset price
    Asset memory asset = _getAssetByToken(token);
    uint256 assetPrice = _calculateAssetPrice(
      _pyth.getPrice(asset.priceId),
      decimals()
    );
    uint256 receiveAmount = Math.mulDiv(amount, assetPrice, price);
    _burn(msg.sender, amount);
    asset.tokenContract.transfer(msg.sender, receiveAmount);
    return receiveAmount;
  }

  function claimAllGas() external onlyOwner {
    IBlast(0x4300000000000000000000000000000000000002).claimAllGas(
      address(this),
      msg.sender
    );
  }

  function _safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
    bool isMathSafe = false;
    uint256 c = 0;
    (isMathSafe, c) = Math.tryAdd(a, b);
    require(isMathSafe, "Staking: math error");
    return c;
  }

  function _safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
    bool isMathSafe = false;
    uint256 c = 0;
    (isMathSafe, c) = Math.trySub(a, b);
    require(isMathSafe, "Staking: math error");
    return c;
  }

  function _safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
    bool isMathSafe = false;
    uint256 c = 0;
    (isMathSafe, c) = Math.tryMul(a, b);
    require(isMathSafe, "Staking: math error");
    return c;
  }

  function _safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    bool isMathSafe = false;
    uint256 c = 0;
    (isMathSafe, c) = Math.tryDiv(a, b);
    require(isMathSafe, "Staking: math error");
    return c;
  }
}
