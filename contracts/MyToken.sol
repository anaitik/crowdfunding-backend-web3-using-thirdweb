// MyToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MyToken is ERC20, Ownable {
    using SafeMath for uint256;

    uint256 public constant MAX_SUPPLY = 100 * 10**30; // 100 decillion (100e30)
    uint256 public constant FINAL_SUPPLY = 21 * 10**6; // 21 million (21e6)
    uint256 public mintedSupply;
    uint256 public burnRate;
    uint256 public lastBurnTimestamp;

    constructor() ERC20("MyToken", "MTK") {
        mintedSupply = 0;
        burnRate = 10; // 10% compound interest
        lastBurnTimestamp = block.timestamp;
    }

    function mint(uint256 amount) external onlyOwner {
        require(mintedSupply.add(amount) <= MAX_SUPPLY, "Exceeds maximum supply");
        _mint(msg.sender, amount);
        mintedSupply = mintedSupply.add(amount);
    }

    function burn() external onlyOwner {
        require(block.timestamp > lastBurnTimestamp, "Cannot burn more than once per day");

        // Calculate burn amount with compound interest
        uint256 daysPassed = (block.timestamp.sub(lastBurnTimestamp)).div(1 days);
        uint256 compoundInterest = (burnRate**daysPassed).sub(1);

        uint256 burnAmount = mintedSupply.mul(compoundInterest).div(100);
        if (mintedSupply.sub(burnAmount) < FINAL_SUPPLY) {
            burnAmount = mintedSupply.sub(FINAL_SUPPLY);
        }

        _burn(msg.sender, burnAmount);
        mintedSupply = mintedSupply.sub(burnAmount);
        lastBurnTimestamp = block.timestamp;
    }
}
