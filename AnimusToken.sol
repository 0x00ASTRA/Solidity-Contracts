// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AnimusToken is ERC20Capped, Ownable {
    address public _rewardMechanismAddress;

    constructor(uint256 cap) ERC20("Animus", "ANIMUS") ERC20Capped(cap) Ownable(msg.sender) {}

    event supplyDecrease(address fromAddress, uint256 amount);
    event supplyIncrease(address recipient, uint256 amount, uint256 totalSupply);

    modifier onlyRewardMechanism { require(msg.sender == _rewardMechanismAddress); _;}

    // Override transfer function to implement deflationary mechanism
    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        // Burn 3% of the transferred amount
        uint256 burnAmount = (amount * 3) / 100;
        uint256 transferAmount = amount - burnAmount;

        super.transfer(recipient, transferAmount);

        // Burn the specified amount
        _burn(msg.sender, burnAmount);

        return true;
    }

    function transferFrom(address from, address recipient, uint256 amount) public virtual override returns(bool) {
        // Burn 3% of the transferred amount
        uint256 burnAmount = (amount * 3) / 100;
        uint256 transferAmount = amount - burnAmount;

        return super.transferFrom(from, recipient, transferAmount);
    }

    function burn(uint256 amount) public virtual  {
        require(msg.sender.balance >= amount, "Insufficient Balance");
        _burn(msg.sender, amount);
    }

    function mint(uint256 amount, address recipient) public onlyOwner onlyRewardMechanism {
        _mint(recipient, amount);
        emit supplyIncrease(recipient, amount, this.totalSupply());
    }

    function setRewardMechanismAddress(address rewardMechanismAddress) external onlyOwner returns(bool) {
        _rewardMechanismAddress = rewardMechanismAddress;
        return true;
    }
}
