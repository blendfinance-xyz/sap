// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

/// @title this contract is used to mock the pyth contract
contract Pyth is IPyth {
  mapping(bytes32 => PythStructs.Price) _prices;

  function getValidTimePeriod()
    external
    view
    override
    returns (uint validTimePeriod)
  {}

  function getPrice(
    bytes32 id
  ) external view override returns (PythStructs.Price memory price) {
    return _prices[id];
  }

  function getEmaPrice(
    bytes32 id
  ) external view override returns (PythStructs.Price memory price) {}

  function getPriceUnsafe(
    bytes32 id
  ) external view override returns (PythStructs.Price memory price) {
    return _prices[id];
  }

  function getPriceNoOlderThan(
    bytes32 id,
    uint age
  ) external view override returns (PythStructs.Price memory price) {}

  function getEmaPriceUnsafe(
    bytes32 id
  ) external view override returns (PythStructs.Price memory price) {}

  function getEmaPriceNoOlderThan(
    bytes32 id,
    uint age
  ) external view override returns (PythStructs.Price memory price) {}

  function updatePriceFeeds(
    bytes[] calldata updateData
  ) external payable override {}

  function updatePriceFeedsIfNecessary(
    bytes[] calldata updateData,
    bytes32[] calldata priceIds,
    uint64[] calldata publishTimes
  ) external payable override {}

  function getUpdateFee(
    bytes[] calldata updateData
  ) external view override returns (uint feeAmount) {}

  function parsePriceFeedUpdates(
    bytes[] calldata updateData,
    bytes32[] calldata priceIds,
    uint64 minPublishTime,
    uint64 maxPublishTime
  )
    external
    payable
    override
    returns (PythStructs.PriceFeed[] memory priceFeeds)
  {}

  function parsePriceFeedUpdatesUnique(
    bytes[] calldata updateData,
    bytes32[] calldata priceIds,
    uint64 minPublishTime,
    uint64 maxPublishTime
  )
    external
    payable
    override
    returns (PythStructs.PriceFeed[] memory priceFeeds)
  {}

  function putPrice(bytes32 id, int64 price, int32 expo) external {
    _prices[id] = PythStructs.Price(price, 0, expo, block.timestamp);
  }
}
