/**
 *Submitted for verification at mumbai.polygonscan.com on 2023-10-29
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProjectRegistry {
    function isProjOwner(string memory _name, address _address) external view returns (bool);
    function isFunderOfProject(string memory _name, address _address) external view returns (bool);
    function areAllTokensSold(string memory _name) external view returns (bool);
    function getTotalFundersOfProject(string memory _name) external view returns (uint256);
    function getTotalFundingOfProject(string memory _name) external view returns (uint256);
    function getProjectFunders(string memory _name) external view returns (address[] memory);
}

contract Claim {

    IProjectRegistry public projectRegistry;
    address public owner;
    address public pendingOwner;

    mapping(string => uint256) public projectMilestones; // Mapping project name to its milestone
    mapping(string => uint256) public votes;
    mapping(string => mapping(address => bool)) public hasVotedForM1;
    mapping(string => mapping(address => bool)) public hasVotedForM2;
    mapping(string => mapping(address => bool)) public hasVotedForM3;
    mapping(string => uint256) public releasedFunding;

    event Voted(string indexed projectName, address indexed voter, bool approval, uint currentMilestone);
    event FundsClaimed(string indexed projectName, uint256 amount, uint currentMilestone);
    event VotesReset(string indexed projectName, uint currentMilestone, address indexed resetBy);
    event OwnershipTransferInitiated(address indexed initialOwner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EmergencyClaimMade(address indexed owner, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function setRegistryAddress(address _projectRegistryAddress) external onlyOwner {
        projectRegistry = IProjectRegistry(_projectRegistryAddress);
    }

    function getReleasedFunding(string memory projectName) public view returns (uint256) {
        return releasedFunding[projectName];
    }

    function vote(string memory projectName, bool approveVote) public {
    require(projectMilestones[projectName] < 4, "Voting not allowed after 3 milestones"); // Added this check
    require(projectRegistry.isFunderOfProject(projectName, msg.sender), "Only a funder can vote");
    if (projectMilestones[projectName] == 1) {
        require(!hasVotedForM1[projectName][msg.sender], "Funder has already voted for M1");
        hasVotedForM1[projectName][msg.sender] = true;
    } else if (projectMilestones[projectName] == 2) {
        require(!hasVotedForM2[projectName][msg.sender], "Funder has already voted for M2");
        hasVotedForM2[projectName][msg.sender] = true;
    } else if (projectMilestones[projectName] == 3) {
        require(!hasVotedForM3[projectName][msg.sender], "Funder has already voted for M3");
        hasVotedForM3[projectName][msg.sender] = true;
    }
    
    if (approveVote) {
        votes[projectName]++;
    }
    emit Voted(projectName, msg.sender, approveVote, projectMilestones[projectName]);
}


    function claim(string memory projectName) public {
    require(releasedFunding[projectName] < projectRegistry.getTotalFundingOfProject(projectName), "All funding has been claimed"); // Added this check
    require(projectRegistry.isProjOwner(projectName, msg.sender), "Only the project owner can claim");

    if (projectMilestones[projectName] == 0 && projectRegistry.areAllTokensSold(projectName)) {
        initialClaim(projectName);
    } else if (projectRegistry.getTotalFundersOfProject(projectName) == 1 && votes[projectName] == 1) {
        singleFunderClaim(projectName);
    } else {
        subsequentClaim(projectName);
    }
}

    function initialClaim(string memory projectName) internal { 
    require(projectRegistry.isProjOwner(projectName, msg.sender), "Only the project owner can claim");
    require(projectMilestones[projectName] == 0, "Initial milestone already claimed.");
    require(projectRegistry.areAllTokensSold(projectName), "All tokens must be sold for the initial claim.");

    uint256 totalFunding = projectRegistry.getTotalFundingOfProject(projectName);
    uint256 currentReleaseAmount = totalFunding / 4;

    payable(msg.sender).transfer(currentReleaseAmount);
    projectMilestones[projectName]++;
    releasedFunding[projectName] += currentReleaseAmount;
    }

    function singleFunderClaim(string memory projectName) internal {  require(projectRegistry.isProjOwner(projectName, msg.sender), "Only the project owner can claim");
    uint256 totalFunders = projectRegistry.getTotalFundersOfProject(projectName);
    require(totalFunders == 1, "This claim type is for projects with a single funder only.");
    require(votes[projectName] == 1, "Single funder has not voted positively.");

    uint256 totalFunding = projectRegistry.getTotalFundingOfProject(projectName);
    uint256 currentReleaseAmount = totalFunding / 4;

    payable(msg.sender).transfer(currentReleaseAmount);
    projectMilestones[projectName]++;
    releasedFunding[projectName] += currentReleaseAmount;
    votes[projectName] = 0;  // Reset votes 
    emit FundsClaimed(projectName, currentReleaseAmount, projectMilestones[projectName]);
    }

function subsequentClaim(string memory projectName) internal {  
    require(projectRegistry.isProjOwner(projectName, msg.sender), "Only the project owner can claim");
    require(projectMilestones[projectName] > 0 && projectMilestones[projectName] < 4, "Claim not possible at this milestone.");

    uint256 totalFunding = projectRegistry.getTotalFundingOfProject(projectName);
    uint256 currentReleaseAmount = totalFunding / 4;
    uint256 totalFunders = projectRegistry.getTotalFundersOfProject(projectName);

    require(votes[projectName] > totalFunders / 2, "Not enough votes to claim at this milestone");
    payable(msg.sender).transfer(currentReleaseAmount);
    projectMilestones[projectName]++;
    releasedFunding[projectName] += currentReleaseAmount;
    votes[projectName] = 0; 
    emit FundsClaimed(projectName, currentReleaseAmount, projectMilestones[projectName]);
    }

function resetVotes(string memory projectName) public {
    require(projectRegistry.isProjOwner(projectName, msg.sender), "Only the project owner can reset votes");
    
    // Reset total votes for the project
    votes[projectName] = 0;

    // Retrieve the list of funders for the project
    address[] memory funders = projectRegistry.getProjectFunders(projectName);

    // Determine the current milestone to reset the voting status
    if (projectMilestones[projectName] == 1) {
        // Resetting votes for Milestone 1
        for(uint256 i = 0; i < funders.length; i++) {
            hasVotedForM1[projectName][funders[i]] = false;
        }
    } else if (projectMilestones[projectName] == 2) {
        // Resetting votes for Milestone 2
        for(uint256 i = 0; i < funders.length; i++) {
            hasVotedForM2[projectName][funders[i]] = false;
        }
    } else if (projectMilestones[projectName] == 3) {
        // Resetting votes for Milestone 3
        for(uint256 i = 0; i < funders.length; i++) {
            hasVotedForM3[projectName][funders[i]] = false;
        }
    }
    emit VotesReset(projectName, projectMilestones[projectName], msg.sender);
    }


    function emergencyClaim(uint256 amount) external onlyOwner {
    require(address(this).balance >= amount, "Insufficient balance in contract");
    payable(owner).transfer(amount);
    emit EmergencyClaimMade(owner, amount);
    }

    function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0) && newOwner != owner, "Invalid new owner address");
    pendingOwner = newOwner;
    emit OwnershipTransferInitiated(owner, pendingOwner);
    }

    function claimOwnership() public {
    require(msg.sender == pendingOwner, "Not the pending owner");
    emit OwnershipTransferred(owner, pendingOwner);
    owner = pendingOwner;
    pendingOwner = address(0);
    }

// Function to allow the contract to accept ether
    receive() external payable {}
    fallback() external payable {}
}