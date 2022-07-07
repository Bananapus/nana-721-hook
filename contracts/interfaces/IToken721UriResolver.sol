// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IToken721UriResolver {
  function tokenURI(uint256) external view returns (string memory);
}
