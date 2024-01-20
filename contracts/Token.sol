// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20, Ownable {
  mapping(address => uint256) private _lastClaimTimes;
  uint256 private _claimAmount = 100 * 10 ** decimals();

  constructor(
    string memory name,
    string memory symbol
  ) ERC20(name, symbol) Ownable(msg.sender) {}

  function mint(address to, uint256 amount) external onlyOwner {
    _mint(to, amount);
  }

  function getClaimAmount() public view returns (uint256) {
    return _claimAmount;
  }

  function claim() external {
    uint256 lastClaimTime = _lastClaimTimes[msg.sender];
    require(
      (block.timestamp - lastClaimTime) > 1 days,
      "Token: you have claimed, please come back after 24 hours"
    );
    _mint(msg.sender, _claimAmount);
    _lastClaimTimes[msg.sender] = block.timestamp;
  }
}
