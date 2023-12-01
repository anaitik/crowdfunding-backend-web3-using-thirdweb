// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract TokenSwapper is Ownable {
    using SafeERC20 for IERC20;

    IUniswapV2Router02 public uniswapRouter;
    address public myTokenAddress; // Address of MyToken
    address public otherTokenAddress; // Address of the other ERC-20 token

    constructor(address _uniswapRouter, address _myTokenAddress, address _otherTokenAddress) {
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        myTokenAddress = _myTokenAddress;
        otherTokenAddress = _otherTokenAddress;

        // Approve the Uniswap router to spend MyToken
        IERC20(myTokenAddress).approve(_uniswapRouter, type(uint256).max);
    }

    function swapMyTokenForOtherToken(uint256 _amount) external onlyOwner {
        // Ensure the contract has enough MyToken balance
        require(IERC20(myTokenAddress).balanceOf(address(this)) >= _amount, "Insufficient MyToken balance");

        // Perform the swap using Uniswap
        address[] memory path = new address[](2);
        path[0] = myTokenAddress;
        path[1] = otherTokenAddress;

        // Perform the swap on Uniswap
        uniswapRouter.swapExactTokensForTokens(_amount, 0, path, address(this), block.timestamp);

        // You may want to perform additional actions with the swapped tokens here
        // For example, send them to a specific address or contract.

        // Note: Ensure that the other ERC-20 token is compatible with Uniswap and
        // can be traded against MyToken on the configured Uniswap pair.
    }

    // This function allows the owner to withdraw any ERC-20 tokens that may be sent to this contract
    function withdrawTokens(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    // This function allows the owner to withdraw any ETH that may be sent to this contract
    function withdrawEther(uint256 _amount) external onlyOwner {
        payable(msg.sender).transfer(_amount);
    }
}
