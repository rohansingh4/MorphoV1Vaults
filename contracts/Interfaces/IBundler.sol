// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct Call {
    address to;
    bytes data;
    uint256 value;
    bool skipRevert;
    bytes32 callbackHash;
}

interface IBundler3 {
    function multicall(Call[] calldata calls) external payable;
}
