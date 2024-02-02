// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract FeeDiscount is Ownable {
  struct Discount {
    uint256 amount;
    uint256 discount;
  }

  Discount[5] private _feeDiscounts;

  constructor() Ownable(msg.sender) {}

  function setFeeDiscounts(
    uint256[] memory staked,
    uint256[] memory discount
  ) external onlyOwner {
    require(
      staked.length <= 5,
      "Fee Discount: staked length should be less than or equal to 5"
    );
    require(
      staked.length == discount.length,
      "Fee Discount: staked length not equal to discount length"
    );
    for (uint256 i = 0; i < _feeDiscounts.length; i++) {
      if (i > staked.length - 1) {
        _feeDiscounts[i] = Discount(0, 0);
      } else {
        _feeDiscounts[i] = Discount(staked[i], discount[i]);
      }
    }
  }

  /**
   * @dev get fee discount
   * @param staked amount
   * @return fee discount
   */
  function getFeeDiscount(uint256 staked) public view returns (uint256) {
    for (uint256 i = 0; i < _feeDiscounts.length; i++) {
      if (staked >= _feeDiscounts[i].amount) {
        return _feeDiscounts[i].discount;
      }
    }
    return 0;
  }

  /**
   * @dev get fee discounted amount
   * @param staked staked amount
   * @param amount amount in
   * @return amount out
   */
  function getFeeDiscountedAmount(
    uint256 staked,
    uint256 amount
  ) public view returns (uint256) {
    return
      _safeSub(amount, Math.mulDiv(amount, getFeeDiscount(staked), 10 ** 6));
  }

  function _safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
    (bool isMathSafe, uint256 c) = Math.trySub(a, b);
    require(isMathSafe, "Fee discount: math error");
    return c;
  }
}
