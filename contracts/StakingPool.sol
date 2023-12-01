// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract StakingPool is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 public myToken;
    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public rewards;
    uint256 public lastRewardTimestamp;

    event Staked(address indexed staker, uint256 amount);
    event Withdrawn(address indexed staker, uint256 amount);
    event ClaimedRewards(address indexed staker, uint256 amount);

    constructor(address _myToken) {
        myToken = IERC20(_myToken);
        lastRewardTimestamp = block.timestamp;
    }

    function stake(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");

        distributeRewards(); // Distribute rewards before staking

        myToken.safeTransferFrom(msg.sender, address(this), _amount);
        stakedBalances[msg.sender] = stakedBalances[msg.sender].add(_amount);
        totalStaked = totalStaked.add(_amount);

        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external {
        require(_amount > 0 && _amount <= stakedBalances[msg.sender], "Invalid withdrawal amount");

        distributeRewards(); // Distribute rewards before withdrawal

        stakedBalances[msg.sender] = stakedBalances[msg.sender].sub(_amount);
        totalStaked = totalStaked.sub(_amount);
        myToken.safeTransfer(msg.sender, _amount);

        emit Withdrawn(msg.sender, _amount);
    }

    function claimRewards() external {
        distributeRewards(); // Distribute rewards before claiming

        uint256 pendingRewards = rewards[msg.sender];
        require(pendingRewards > 0, "No rewards to claim");

        rewards[msg.sender] = 0;
        myToken.safeTransfer(msg.sender, pendingRewards);

        emit ClaimedRewards(msg.sender, pendingRewards);
    }

    function distributeRewards() internal {
        uint256 elapsedTime = block.timestamp.sub(lastRewardTimestamp);
        uint256 monthlyRewards = totalStaked.mul(10).div(100); // 10% monthly reward

        if (elapsedTime >= 30 days) {
            for (uint256 i = 0; i < totalStaked; i++) {
                address staker = getStakerAtIndex(i);
                rewards[staker] = rewards[staker].add(stakedBalances[staker].mul(monthlyRewards).div(totalStaked));
            }
            lastRewardTimestamp = block.timestamp;
        }
    }

    function calculatePendingRewards(address _staker) public view returns (uint256) {
        uint256 stakerBalance = stakedBalances[_staker];
        uint256 stakerShare = stakerBalance.mul(1e18).div(totalStaked);

        return rewards[_staker].add(stakerShare);
    }

    // Owner function to distribute rewards to the staking pool
    function distributeAdditionalRewards(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");

        myToken.safeTransferFrom(msg.sender, address(this), _amount);
        for (uint256 i = 0; i < totalStaked; i++) {
            address staker = getStakerAtIndex(i);
            rewards[staker] = rewards[staker].add(stakedBalances[staker].mul(_amount).div(totalStaked));
        }
    }

    // Helper function to get staker address at a given index
    function getStakerAtIndex(uint256 _index) public view returns (address) {
        require(_index < totalStaked, "Index out of bounds");
        address[] memory stakers = getStakers();
        return stakers[_index];
    }

    // Helper function to get all stakers
    function getStakers() public view returns (address[] memory) {
        address[] memory stakers = new address[](totalStaked);
        uint256 count = 0;
        for (uint256 i = 0; i < totalStaked; i++) {
            if (stakedBalances[getStakerAtIndex(i)] > 0) {
                stakers[count] = getStakerAtIndex(i);
                count++;
            }
        }
        return stakers;
    }
}
