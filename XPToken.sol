// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract XPToken is ERC1155, Ownable {
    uint256 public constant XP = 0;
    uint256 public constant LEVEL = 1;
    address public _rewardMechanismAddress;
    modifier onlyRewardMechanism { require(msg.sender == _rewardMechanismAddress); _;}

    constructor(string memory uri_) ERC1155(uri_) Ownable(msg.sender) {
        // The URI above should point to a metadata API for token information
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        external
        onlyRewardMechanism
    {
        _mint(account, id, amount, data);
    }

    function mintBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyRewardMechanism {
        _mintBatch(account, ids, amounts, data);
    }

    function setRewardMechanismAddress(address rewardMechanismAddress) external onlyOwner returns(bool) {
        _rewardMechanismAddress = rewardMechanismAddress;
        return true;
    }
}
