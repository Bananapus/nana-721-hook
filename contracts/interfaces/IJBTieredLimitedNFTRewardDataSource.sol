// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './../structs/JBNFTRewardTier.sol';

interface IJBTieredLimitedNFTRewardDataSource {
  event Mint(
    uint256 indexed tokenId,
    uint256 indexed tierId,
    address indexed beneficiary,
    uint256 totalAmountContributed,
    uint256 numRewards,
    address caller
  );

  event Burn(uint256 indexed tokenId, address owner, address caller);

  function numberOfTiers() external view returns (uint256);

  function contributionToken() external view returns (address);

  function tierIdOfToken(uint256 _tokenId) external view returns (uint256);

  function mint(
    address _beneficiary,
    uint256 _tierId,
    uint256 _tokenNumber
  ) external returns (uint256 tokenId);

  function burn(address _owner, uint256 _tokenId) external;
}
