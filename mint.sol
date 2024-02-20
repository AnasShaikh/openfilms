// independent registry
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// Importing IProjectRegistry interface
interface IProjectRegistry {
    function projectExists(string memory _name) external view returns (bool);
    function isProjOwner(string memory _name, address _address) external view returns (bool);
    function setAllTokensSold(string memory _name) external;
    function setProjectDetails(string memory _name, uint256 _tokenPrice, uint256 _totalTokens, uint256 _totalFunding) external;
    function addFunder(string memory _name, address _funder, uint256 _contribution) external;
}

contract ProjectNFT is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

     IProjectRegistry public projectRegistry;
    address public owner;
    address public pendingOwner;
    address public claimAddress; // Address where funds will go after NFT is bought
    bool public registryHasBeenSet = false;

    mapping(string => uint256) public nextTokenId;
    mapping(string => uint256) public availableTokens;
    mapping(string => uint256) public tokensSold;
    mapping(string => uint256) public nftPrice; // In wei
    mapping(string => uint256) public collectedFunding;
    mapping(uint256 => string) public tokenIdToProjectName;
    mapping(string => bool) public mintedProjects;
    mapping(string => uint256) public projectTotalFundingRequirement;


    event Minted(address indexed projectOwner, string indexed projectName, uint256 numberOfTokens, string tokenURI);
    event Purchased(address indexed buyer, string indexed projectName, uint256 tokenQuantity, uint256 totalCost);
    event RegistryAddressSet(address indexed setter, address indexed registryAddress);
    event ClaimAddressSet(address indexed setter, address indexed newClaimAddress);
    event OwnershipTransferInitiated(address indexed initialOwner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    constructor() ERC721("ProjectNFT", "PNFT") {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function setRegistryAddress(address _projectRegistryAddress) external onlyOwner {
        projectRegistry = IProjectRegistry(_projectRegistryAddress);
        emit RegistryAddressSet(msg.sender, _projectRegistryAddress);
    }
    
    function setClaimAddress(address _claimAddress) external onlyOwner {
        claimAddress = _claimAddress;
        emit ClaimAddressSet(msg.sender, _claimAddress);

    }

  function mintNFT(
        string memory projectName,
        uint256 totalFundingRequirement
            ) public {
        require(projectRegistry.projectExists(projectName), "Project does not exist");
        require(projectRegistry.isProjOwner(projectName, msg.sender), "Only the project owner can mint");
        require(!mintedProjects[projectName], "Tokens for this project have already been minted.");

        uint256 priceInWei = 0;
        nftPrice[projectName] = priceInWei; 
        projectTotalFundingRequirement[projectName] = totalFundingRequirement;

        projectRegistry.setProjectDetails(projectName, priceInWei, 1, totalFundingRequirement);
        mintedProjects[projectName] = true;
    }

    function buyNFT(string memory projectName) public payable {
        require(msg.value > 0, "Must send some Ether");
       // require(!mintedProjects[projectName], "You already own a token for this project");
        uint256 totalFundingRequirement = projectTotalFundingRequirement[projectName];
        uint256 contributionPercentage = (msg.value * 100) / totalFundingRequirement;
        uint256 combinedFunding = collectedFunding[projectName] + msg.value;
        require(combinedFunding <= totalFundingRequirement, "Project has reached its funding requirement");


        string memory tokenURI = getUriBasedOnContribution(contributionPercentage);

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        tokenIdToProjectName[newTokenId] = projectName;

        collectedFunding[projectName] += msg.value;
        address payable destination = payable(claimAddress);
        require(destination != address(0), "Claim address not set");
        destination.transfer(msg.value);

        // If the project reaches or exceeds its funding requirement, set the areAllTokensSold flag in the registry
        if(collectedFunding[projectName] >= totalFundingRequirement) {
        projectRegistry.setAllTokensSold(projectName);
        }

        projectRegistry.addFunder(projectName, msg.sender, msg.value);
        emit Purchased(msg.sender, projectName, 1, msg.value);
    }

    function getUriBasedOnContribution(uint256 percentage) internal pure returns (string memory) {
        if (percentage >= 75) return "uri_for_75_and_above";
        if (percentage >= 50) return "uri_for_50_to_74";
        if (percentage >= 25) return "uri_for_25_to_49";
        return "uri_for_less_than_25";
    }


    function getTokensSold(string memory projectName) public view returns (uint256) {
        return tokensSold[projectName];
    }

    function getCollectedFunding(string memory projectName) public view returns (uint256) {
        return collectedFunding[projectName];
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

}

