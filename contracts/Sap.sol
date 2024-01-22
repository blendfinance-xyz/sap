// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { IBlast } from "../interfaces/IBlast.sol";

contract Sap is Ownable, ERC20 {
  struct Asset {
    address token;
    bytes32 pythPriceId;
    uint8 decimals;
  }

  struct InitAsset {
    address token;
    bytes32 pythPriceId;
  }

  address private _pyth;
  address private _uniswapRouter;
  Asset[] private _assets;
  bool private _initialized = false;

  event Init(uint256 amount, uint256 price);
  event Buy(address indexed account, uint256 amount, uint256 price);
  event Sell(address indexed account, uint256 amount, uint256 price);

  /**
   * @notice the first asset must be usdt or usdc
   * @notice the price id should be asset.token to usd
   */
  constructor(
    string memory name_,
    string memory symbol_,
    address pyth_,
    address uniswapRouter_,
    InitAsset[] memory assets_
  ) Ownable(msg.sender) ERC20(name_, symbol_) {
    _pyth = pyth_;
    _uniswapRouter = uniswapRouter_;
    for (uint256 i = 0; i < assets_.length; i++) {
      _assets.push(
        Asset({
          token: assets_[i].token,
          pythPriceId: assets_[i].pythPriceId,
          decimals: ERC20(assets_[i].token).decimals()
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
    revert("Sap: asset not found");
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
  function getAssetPythPriceId(uint256 index) public view returns (bytes32) {
    return _assets[index].pythPriceId;
  }

  /**
   * @dev initialize the pool
   * @notice this function should be called only once
   * @param amounts_ the amounts of the assets
   * @param amount_ the amount of sap
   */
  function init(uint256[] memory amounts_, uint256 amount_) external onlyOwner {
    require(!_initialized, "Sap: already initialized");
    require(amounts_.length == _assets.length, "Sap: invalid amounts");
    for (uint256 i = 0; i < _assets.length; i++) {
      Asset memory asset = _assets[i];
      IERC20 tc = IERC20(asset.token);
      tc.transferFrom(msg.sender, address(this), amounts_[i]);
    }
    _mint(msg.sender, amount_);
    _initialized = true;
    emit Init(getPrice(), amount_);
  }

  function _getAssetPriceFromPyth(
    Asset memory asset,
    uint8 targetDecimals
  ) internal view returns (uint256) {
    PythStructs.Price memory price = IPyth(_pyth).getPrice(asset.pythPriceId);
    require(price.price > 0, "SAP: invalid price");
    require(price.expo < 0, "SAP: invalid price expo");
    require(price.expo > -255, "SAP: invalid price expo");
    uint8 priceDecimals = uint8(uint32(-1 * price.expo));
    if (priceDecimals >= targetDecimals) {
      return
        _safeDiv(
          uint(uint64(price.price)),
          10 ** (priceDecimals - targetDecimals)
        );
    } else {
      return
        _safeMul(
          uint(uint64(price.price)),
          10 ** (targetDecimals - priceDecimals)
        );
    }
  }

  function _getAssetPriceFromUniswap(
    Asset memory asset,
    uint8 targetDecimals
  ) internal view returns (uint256) {
    address[] memory path = new address[](2);
    path[0] = asset.token;
    path[1] = _assets[0].token;
    uint8 decimals = _assets[0].decimals;
    uint256[] memory amounts = IUniswapV2Router02(_uniswapRouter).getAmountsOut(
      10 ** asset.decimals,
      path
    );
    if (decimals >= targetDecimals) {
      return _safeDiv(amounts[1], 10 ** (decimals - targetDecimals));
    } else {
      return _safeMul(amounts[1], 10 ** (targetDecimals - decimals));
    }
  }

  function _getAssetPrice(
    Asset memory asset,
    uint8 targetDecimals
  ) internal view returns (uint256) {
    if (asset.pythPriceId == 0x0000000000000000000000000000000000000000000000000000000000000000) {
      return _getAssetPriceFromUniswap(asset, targetDecimals);
    } else {
      return _getAssetPriceFromPyth(asset, targetDecimals);
    }
  }

  /**
   * @dev get the price of the asset
   * @param index the index of the asset
   */
  function getAssetPrice(uint256 index) public view returns (uint256) {
    return _getAssetPrice(_assets[index], decimals());
  }

  /**
   * @dev get the price of the pool, the price has same decimals with sap
   */
  function getPrice() public view returns (uint256) {
    require(_initialized, "Sap: not initialized");
    uint256 volumn = 0;
    for (uint256 i = 0; i < _assets.length; i++) {
      Asset memory asset = _assets[i];
      uint256 assetPrice = _getAssetPrice(asset, decimals());
      IERC20 tc = IERC20(asset.token);
      uint256 assetBalance = Math.mulDiv(
        tc.balanceOf(address(this)),
        10 ** decimals(),
        10 ** asset.decimals
      );
      volumn += _safeMul(assetPrice, assetBalance);
    }
    return _safeDiv(volumn, totalSupply());
  }

  /**
   * @dev swap tokenIn to tokenOut
   * @param router_ uniswap router
   * @param amountIn the amount of tokenIn
   * @param path the path of swap
   */
  function swap(
    address router_,
    uint256 amountIn,
    address[] memory path
  ) external onlyOwner {
    require(_initialized, "Sap: not initialized");
    IUniswapV2Router02 router = IUniswapV2Router02(router_);
    Asset memory assetIn = _getAssetByToken(path[0]);
    IERC20 tc = IERC20(assetIn.token);
    tc.approve(router_, amountIn);
    // avoid swap to token not in assets
    _getAssetByToken(path[path.length - 1]);
    // do swap
    router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
      amountIn,
      0,
      path,
      address(this),
      block.timestamp + 60
    );
  }

  function _getBuyAmount(
    uint256 payAmount,
    address token
  ) internal view returns (Asset memory, uint256, uint256) {
    require(_initialized, "Sap: not initialized");
    // sap price
    uint256 price = getPrice();
    // asset price
    Asset memory asset = _getAssetByToken(token);
    uint256 assetPrice = _getAssetPrice(asset, decimals());
    uint256 buyAmount = Math.mulDiv(
      Math.mulDiv(payAmount, 10 ** decimals(), 10 ** asset.decimals),
      assetPrice,
      price
    );
    return (asset, buyAmount, price);
  }

  /**
   * @dev get the amount of sap will buy
   * @param payAmount the amount of token to pay
   * @param token the token to pay
   */
  function getBuyAmount(
    uint256 payAmount,
    address token
  ) public view returns (uint256) {
    (, uint256 buyAmount, ) = _getBuyAmount(payAmount, token);
    return buyAmount;
  }

  /**
   * @dev buy sap, could put in any token in the pool
   * @param payAmount paid amount
   * @param token the token to pay
   * @return the amount has bought
   */
  function buy(uint256 payAmount, address token) external returns (uint256) {
    (Asset memory asset, uint256 buyAmount, uint256 price) = _getBuyAmount(
      payAmount,
      token
    );
    IERC20 tc = IERC20(asset.token);
    tc.transferFrom(msg.sender, address(this), payAmount);
    _mint(msg.sender, buyAmount);
    emit Buy(msg.sender, buyAmount, price);
    return buyAmount;
  }

  function _getSellAmount(
    uint256 sellAmount,
    address token
  ) internal view returns (Asset memory, uint256, uint256) {
    require(_initialized, "Sap: not initialized");
    // sap price
    uint256 price = getPrice();
    // asset price
    Asset memory asset = _getAssetByToken(token);
    uint256 assetPrice = _getAssetPrice(asset, decimals());
    uint256 receiveAmount = Math.mulDiv(
      Math.mulDiv(sellAmount, price, assetPrice),
      10 ** asset.decimals,
      10 ** decimals()
    );
    return (asset, receiveAmount, price);
  }

  /**
   * @dev get the amount of token will receive
   * @param sellAmount the amount of sap to sell
   * @param token the token to get out
   */
  function getSellAmount(
    uint256 sellAmount,
    address token
  ) public view returns (uint256) {
    (, uint256 receiveAmount, ) = _getSellAmount(sellAmount, token);
    return receiveAmount;
  }

  /**
   * @dev sell sap, could get out any token in the pool
   * @param sellAmount the amount of sap to sell
   * @param token the token to get out
   * @return the amount of token received
   */
  function sell(uint256 sellAmount, address token) external returns (uint256) {
    (Asset memory asset, uint256 receiveAmount, uint256 price) = _getSellAmount(
      sellAmount,
      token
    );
    _burn(msg.sender, sellAmount);
    IERC20 tc = IERC20(asset.token);
    tc.transfer(msg.sender, receiveAmount);
    emit Sell(msg.sender, sellAmount, price);
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
    require(isMathSafe, "Sap: math error");
    return c;
  }

  function _safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
    bool isMathSafe = false;
    uint256 c = 0;
    (isMathSafe, c) = Math.trySub(a, b);
    require(isMathSafe, "Sap: math error");
    return c;
  }

  function _safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
    bool isMathSafe = false;
    uint256 c = 0;
    (isMathSafe, c) = Math.tryMul(a, b);
    require(isMathSafe, "Sap: math error");
    return c;
  }

  function _safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    bool isMathSafe = false;
    uint256 c = 0;
    (isMathSafe, c) = Math.tryDiv(a, b);
    require(isMathSafe, "Sap: math error");
    return c;
  }
}
