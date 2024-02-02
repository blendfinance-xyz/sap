// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IBlast } from "../interfaces/IBlast.sol";

contract Staking is Ownable {
  struct Member {
    uint256 stakeTimestamp;
    uint256 balance;
  }

  mapping(uint256 => uint256) private _rewardRates;
  mapping(address => mapping(uint256 => Member)) private _members;
  mapping(address => uint256) private _stakes;
  uint256 private _totalStaked;

  IERC20 private _token;

  event Stake(address indexed account, uint256 lockupTime, uint256 amount);
  event Unstaking(
    address indexed account,
    uint256 lockupTime,
    uint256 amount,
    uint256 reward
  );
  event Abort(address indexed account, uint256 lockupTime, uint256 amount);

  constructor(address token_) Ownable(msg.sender) {
    _token = IERC20(token_);
    // remark this line before test, because blast is not available on local
    // IBlast(0x4300000000000000000000000000000000000002).configureClaimableGas();
  }

  /**
   * @dev Throws if called with a lockup time that is not available.
   * @param lockupTime_ which lockup time class
   */
  modifier checkRewardRate(uint256 lockupTime_) {
    require(
      _rewardRates[lockupTime_] > 0,
      "Staking: this lockup time is not available"
    );
    _;
  }

  /**
   * @dev Gets the token address.
   * @return token
   */
  function token() public view returns (address) {
    return address(_token);
  }

  /**
   * @dev Gets the reward rate for a given lockup time.
   * @param lockupTime_ which lockup time class
   * @return reward rate
   */
  function rewardRate(uint256 lockupTime_) public view returns (uint256) {
    return _rewardRates[lockupTime_];
  }

  /**
   * @dev Sets the reward rate for a given lockup time.
   * @param lockupTime_ which lockup time class
   * @param rewardRate_ reward rate
   */
  function setRewardRate(
    uint256 lockupTime_,
    uint256 rewardRate_
  ) external onlyOwner {
    require(lockupTime_ > 0, "Staking: lock time must be greater than 0");
    if (rewardRate_ == 0) {
      delete _rewardRates[lockupTime_];
    } else {
      _rewardRates[lockupTime_] = rewardRate_;
    }
  }

  function _findMember(
    address account_,
    uint256 lockupTime_
  ) internal view returns (Member storage) {
    return _members[account_][lockupTime_];
  }

  /**
   * @dev Gets the staked balance for a given account.
   * @param account_ account who staked token
   * @return how much token staked
   */
  function balanceOf(address account_) public view returns (uint256) {
    return _stakes[account_];
  }

  /**
   * @dev Gets the staked balance for a given lockup time and account.
   * @param account_ account who staked token
   * @param lockupTime_ which lockup time class
   * @return how much token staked
   */
  function balanceOfOne(
    address account_,
    uint256 lockupTime_
  ) public view returns (uint256) {
    Member memory member = _findMember(account_, lockupTime_);
    return member.balance;
  }

  /**
   * @dev Gets the total staked balance.
   */
  function totalStaked() public view returns (uint256) {
    return _totalStaked;
  }

  /**
   * @dev Gets the left lockup time
   * @param account_ account who staked token
   * @param lockupTime_ which lockup time class
   * @return left time, in second
   */
  function leftLockupTime(
    address account_,
    uint256 lockupTime_
  ) public view returns (uint256) {
    Member memory member = _findMember(account_, lockupTime_);
    uint256 timeElapsed = block.timestamp - member.stakeTimestamp;
    return _safeSub(lockupTime_, timeElapsed);
  }

  function _stake(uint256 amount_) internal {
    _stakes[msg.sender] = _safeAdd(_stakes[msg.sender], amount_);
    _totalStaked = _safeAdd(_totalStaked, amount_);
    _token.transferFrom(msg.sender, address(this), amount_);
  }

  /**
   * @dev Stakes a given amount for a given lockup time.
   * @param lockupTime_ which lockup time class
   * @param amount_ amount of token to stake
   */
  function stake(
    uint256 lockupTime_,
    uint256 amount_
  ) external checkRewardRate(lockupTime_) {
    require(amount_ > 0, "Staking: amount must be greater than 0");
    // member
    Member storage member = _findMember(msg.sender, lockupTime_);
    require(
      member.balance == 0,
      "Staking: account already has a stake for this lockup time"
    );
    _stake(amount_);
    member.stakeTimestamp = block.timestamp;
    member.balance = amount_;
    _members[msg.sender][lockupTime_] = member;
    emit Stake(msg.sender, lockupTime_, amount_);
  }

  function _calculateReward(
    uint256 amount,
    uint256 rewardRate_,
    uint256 timeElapsed
  ) internal pure returns (uint256) {
    return
      Math.mulDiv(
        amount,
        _safeMul(rewardRate_, timeElapsed),
        _safeMul(365 days, 10 ** 6)
      );
  }

  function _unstake(uint256 amount, uint256 reward) internal {
    _stakes[msg.sender] = _safeSub(_stakes[msg.sender], amount);
    _totalStaked = _safeSub(_totalStaked, amount);
    _token.transfer(msg.sender, _safeAdd(amount, reward));
  }

  /**
   * @dev Unstakes all amount and reward from a given lockup time.
   * @param lockupTime_ which lockup time class
   */
  function unstake(uint256 lockupTime_) external checkRewardRate(lockupTime_) {
    // member
    Member storage member = _findMember(msg.sender, lockupTime_);
    require(
      member.balance > 0,
      "Staking: account does not have a stake for this lockup time"
    );
    require(
      block.timestamp - member.stakeTimestamp >= lockupTime_,
      "Staking: lockup time has not been reached"
    );
    uint256 reward = _calculateReward(
      member.balance,
      rewardRate(lockupTime_),
      lockupTime_
    );
    _unstake(member.balance, reward);
    delete _members[msg.sender][lockupTime_];

    emit Unstaking(msg.sender, lockupTime_, member.balance, reward);
  }

  /**
   * @dev Gets the reward value for a given lockup time and account.
   * @param account_ account who staked token
   * @param lockupTime_ which lockup time class
   * @return how much reward will get
   */
  function getReward(
    address account_,
    uint256 lockupTime_
  ) public view checkRewardRate(lockupTime_) returns (uint256) {
    Member memory member = _findMember(account_, lockupTime_);
    require(
      member.balance > 0,
      "Staking: account does not have a stake for this lockup time"
    );
    return
      _calculateReward(member.balance, rewardRate(lockupTime_), lockupTime_);
  }

  /**
   * @dev Aborts a stake and returns the amount to the account.
   * @param lockupTime_ which lockup time class
   */
  function abort(uint256 lockupTime_) external {
    // member
    Member storage member = _findMember(msg.sender, lockupTime_);
    require(
      member.balance > 0,
      "Staking: account does not have a stake for this lockup time"
    );
    _unstake(member.balance, 0);
    delete _members[msg.sender][lockupTime_];
    emit Abort(msg.sender, lockupTime_, member.balance);
  }

  function claimAllGas() external onlyOwner {
    IBlast(0x4300000000000000000000000000000000000002).claimAllGas(
      address(this),
      msg.sender
    );
  }

  function _safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
    (bool isMathSafe, uint256 c) = Math.tryAdd(a, b);
    require(isMathSafe, "Sap: math error");
    return c;
  }

  function _safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
    (bool isMathSafe, uint256 c) = Math.trySub(a, b);
    require(isMathSafe, "Sap: math error");
    return c;
  }

  function _safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
    (bool isMathSafe, uint256 c) = Math.tryMul(a, b);
    require(isMathSafe, "Sap: math error");
    return c;
  }

  function _safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    (bool isMathSafe, uint256 c) = Math.tryDiv(a, b);
    require(isMathSafe, "Sap: math error");
    return c;
  }
}
