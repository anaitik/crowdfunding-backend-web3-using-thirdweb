pragma solidity ^0.8.9;

contract CrowdFunding {
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
    address public owner;
    bool public paused;

    modifier onlyOwner(uint256 _id) {
        if (_id != 0) {
            require(msg.sender == campaigns[_id].owner, "Only the owner can perform this action");
        } else {
            require(msg.sender == owner, "Only the owner can perform this action");
        }
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    event CampaignCreated(address indexed owner, uint256 indexed campaignId, string title, uint256 target, uint256 deadline);
    event DonationMade(address indexed donator, uint256 indexed campaignId, uint256 amount);
    event RefundMade(address indexed donator, uint256 indexed campaignId, uint256 amountRefunded);

    constructor() {
        owner = msg.sender;
    }

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

        (bool sent,) = payable(campaign.owner).call{value: amount}("");

        if(sent) {
            campaign.amountCollected += amount;
            emit DonationMade(msg.sender, _id, amount);
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

    function refund(uint256 _id) public onlyOwner(_id) {
        Campaign storage campaign = campaigns[_id];

        require(block.timestamp >= campaign.deadline, "The deadline has not been reached yet");

        if (campaign.amountCollected < campaign.target) {
            for (uint i = 0; i < campaign.donators.length; i++) {
                payable(campaign.donators[i]).transfer(campaign.donations[i]);
                emit RefundMade(campaign.donators[i], _id, campaign.donations[i]);
            }
        }
    }

    function extendDeadline(uint256 _id, uint256 _newDeadline) public onlyOwner(_id) {
        require(block.timestamp < campaigns[_id].deadline, "The current deadline has already passed");
        require(_newDeadline > campaigns[_id].deadline, "New deadline should be after the current deadline");

        campaigns[_id].deadline = _newDeadline;
    }

    function withdrawFunds(uint256 _id) public onlyOwner(_id) {
        Campaign storage campaign = campaigns[_id];

        require(campaign.amountCollected >= campaign.target, "Target not met yet");

        payable(campaign.owner).transfer(campaign.amountCollected);
        campaign.amountCollected = 0;
    }

    function pause() public onlyOwner(0) {
        paused = true;
    }

    function resume() public onlyOwner(0) {
        paused = false;
    }
}
