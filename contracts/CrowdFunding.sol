// CrowdFunding.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MyToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CrowdFunding is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct Campaign {
        address owner;
        string title;
        string description;
        uint256 target;
        uint256 deadline;
        uint256 amountCollected;
        string image;
        address[] donators;
        uint256[] donations;
    }

    mapping(uint256 => Campaign) public campaigns;

    uint256 public numberOfCampaigns = 0;
    bool public paused;

    MyToken public token;
    uint256 public rewardRate;
    uint256 public lastRewardTimestamp;

    constructor() {
        token = new MyToken();
        rewardRate = 4; // 4% compound interest for rewards
        lastRewardTimestamp = block.timestamp;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    event CampaignCreated(address indexed owner, uint256 indexed campaignId, string title, uint256 target, uint256 deadline);
    event DonationMade(address indexed donator, uint256 indexed campaignId, uint256 amount, uint256 reward);
    event RefundMade(address indexed donator, uint256 indexed campaignId, uint256 amountRefunded);

    function createCampaign(string memory _title, string memory _description, uint256 _target, uint256 _deadline, string memory _image) public whenNotPaused returns (uint256) {
        Campaign storage campaign = campaigns[numberOfCampaigns];

        require(_deadline > block.timestamp, "The deadline should be a date in the future.");

        campaign.owner = msg.sender;
        campaign.title = _title;
        campaign.description = _description;
        campaign.target = _target;
        campaign.deadline = _deadline;
        campaign.amountCollected = 0;
        campaign.image = _image;

        numberOfCampaigns++;

        emit CampaignCreated(msg.sender, numberOfCampaigns - 1, _title, _target, _deadline);

        return numberOfCampaigns - 1;
    }

    function donateToCampaign(uint256 _id) public payable whenNotPaused {
        uint256 amount = msg.value;

        Campaign storage campaign = campaigns[_id];

        campaign.donators.push(msg.sender);
        campaign.donations.push(amount);

        // Calculate reward with compound interest
        uint256 daysPassed = (block.timestamp.sub(lastRewardTimestamp)).div(1 days);
        uint256 compoundInterest = (100 - rewardRate**daysPassed);
        uint256 rewardAmount = compoundInterest.mul(21).div(100);

        // Ensure the reward amount does not go below 0.2 MyToken
        if (rewardAmount < 0.2 * 10**18) {
            rewardAmount = 0.2 * 10**18;
        }

        // Mint rewards for the donor
        token.mint(rewardAmount);

        (bool sent,) = payable(campaign.owner).call{value: amount}("");

        if(sent) {
            campaign.amountCollected += amount;
            emit DonationMade(msg.sender, _id, amount, rewardAmount);
        }
    }

    function getDonators(uint256 _id) view public returns (address[] memory, uint256[] memory) {
        return (campaigns[_id].donators, campaigns[_id].donations);
    }

    function getCampaigns() public view returns (Campaign[] memory) {
        Campaign[] memory allCampaigns = new Campaign[](numberOfCampaigns);

        for(uint i = 0; i < numberOfCampaigns; i++) {
            Campaign storage item = campaigns[i];
            allCampaigns[i] = item;
        }

        return allCampaigns;
    }

    function refund(uint256 _id) public onlyOwner {
        Campaign storage campaign = campaigns[_id];

        require(block.timestamp >= campaign.deadline, "The deadline has not been reached yet");

        if (campaign.amountCollected < campaign.target) {
            for (uint i = 0; i < campaign.donators.length; i++) {
                address donator = campaign.donators[i];
                uint256 amount = campaign.donations[i];

                // Transfer rewards back to the donator
                uint256 daysPassed = (block.timestamp.sub(lastRewardTimestamp)).div(1 days);
                uint256 compoundInterest = (100 - rewardRate**daysPassed);
                uint256 refundAmount = compoundInterest.mul(21).div(100);

                // Ensure the refund amount does not go below 0.2 MyToken
                if (refundAmount < 0.2 * 10**18) {
                    refundAmount = 0.2 * 10**18;
                }

                token.transfer(donator, refundAmount);

                // Transfer ether back to the donator
                payable(donator).transfer(amount);

                emit RefundMade(donator, _id, amount);
            }
        }
    }

    function extendDeadline(uint256 _id, uint256 _newDeadline) public onlyOwner {
        require(block.timestamp < campaigns[_id].deadline, "The current deadline has already passed");
        require(_newDeadline > campaigns[_id].deadline, "New deadline should be after the current deadline");

        campaigns[_id].deadline = _newDeadline;
    }

    function withdrawFunds(uint256 _id) public onlyOwner {
        Campaign storage campaign = campaigns[_id];

        require(campaign.amountCollected >= campaign.target, "Target not met yet");

        // Transfer tokens to the campaign owner
        token.transfer(campaign.owner, campaign.amountCollected);

        // Transfer ether to the campaign owner
        payable(campaign.owner).transfer(campaign.amountCollected);

        campaign.amountCollected = 0;
    }

    function pause() public onlyOwner {
        paused = true;
    }

    function resume() public onlyOwner {
        paused = false;
    }
}
