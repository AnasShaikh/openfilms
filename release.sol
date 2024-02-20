
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProjectRegistry {
    function getTotalFundingOfProject(string memory _name) view external returns (uint256);
    function isFunderOfProject(string memory _name, address _funder) view external returns (bool);
    function getFunderOwnership(string memory _name) external view returns (uint8);
    function isProjOwner(string memory _name, address _address) external view returns (bool);
    function getFundersContribution(string memory _name, address _funder) external view returns (uint256);
}

contract ReleaseContract {
    struct Movie {
        string ipfsHash;
        uint256 viewCost;
        uint256 totalRevenue;
        address[] viewers;
    }

    struct RevenueLedger {
    uint256 creatorShare;
    uint256 fundersPool;
    uint256 OFShare;
    }


    address public owner;
    address public pendingOwner;
    IProjectRegistry public projectRegistry;
    mapping(string => Movie) public movies;
    uint256 constant OF_SHARE_PERCENTAGE = 5;  // Sample percentage for OpenAI Foundation
    mapping(string => RevenueLedger) public revenueLedgers;
    mapping(string => mapping(address => uint256)) public funderWithdrawnAmount;
    uint256 public totalOFShare;
    string[] private allMovieNames; // Array to keep track of all movie names


    event MovieReleased(string projectName, string ipfsHash);
    event MovieWatched(string projectName, address viewer);
    event CreatorWithdrawal(string projectName, address indexed creator, uint256 amount);
    event FunderWithdrawal(string projectName, address indexed funder, uint256 amount);
    event MovieDetailsUpdated(string projectName, string newIpfsHash, uint256 newViewCost);
    event OwnershipTransferInitiated(address indexed initialOwner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
    owner = msg.sender;
     }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }


    function setProjectRegistryAddress(address _projectRegistryAddress) public onlyOwner {
        projectRegistry = IProjectRegistry(_projectRegistryAddress);
    }

    function releaseMovie(string memory _projectName, string memory _ipfsHash, uint256 _viewCost) public {
    // Check if movie already exists or not
    require(bytes(movies[_projectName].ipfsHash).length == 0, "Movie already released");
    require(projectRegistry.isProjOwner(_projectName, msg.sender), "Only the project owner can release the movie");

    // Create and store the new movie
    movies[_projectName] = Movie({
        ipfsHash: _ipfsHash,
        viewCost: _viewCost,
        totalRevenue: 0,
        viewers: new address[](0)
    });

    // Add movie name to the list of all movies
    allMovieNames.push(_projectName);

    emit MovieReleased(_projectName, _ipfsHash);
}


function watch(string memory _projectName) public payable {
    require(msg.value == movies[_projectName].viewCost, "Incorrect view cost provided");
    
    uint8 funderOwnershipPercentage = projectRegistry.getFunderOwnership(_projectName);
    uint256 ofShare = (msg.value * OF_SHARE_PERCENTAGE) / 100;
    uint256 fundersShare = (msg.value * funderOwnershipPercentage) / 100;
    uint256 creatorsShare = msg.value - (ofShare + fundersShare);

    movies[_projectName].totalRevenue += msg.value - ofShare;
    movies[_projectName].viewers.push(msg.sender);

    revenueLedgers[_projectName].creatorShare += creatorsShare;
    revenueLedgers[_projectName].fundersPool += fundersShare;
    revenueLedgers[_projectName].OFShare += ofShare;

    totalOFShare += ofShare;

    emit MovieWatched(_projectName, msg.sender);
    }

    function withdrawAsCreator(string memory _projectName) public {
    require(projectRegistry.isProjOwner(_projectName, msg.sender), "Only the project owner can withdraw");

    uint256 creatorsShare = revenueLedgers[_projectName].creatorShare;
    payable(msg.sender).transfer(creatorsShare);

    emit CreatorWithdrawal(_projectName, msg.sender, creatorsShare);
    revenueLedgers[_projectName].creatorShare = 0;
    }   




  function withdrawAsFunder(string memory _projectName) public {
    require(projectRegistry.isFunderOfProject(_projectName, msg.sender), "Not a funder for this project");

    uint256 individualFundersContribution = projectRegistry.getFundersContribution(_projectName, msg.sender);
    uint256 totalFunding = projectRegistry.getTotalFundingOfProject(_projectName);
    uint256 fundersPool = revenueLedgers[_projectName].fundersPool;
    
    uint256 funderSharePercentage = (individualFundersContribution * 100) / totalFunding;
    uint256 funderEntitledAmount = (fundersPool * funderSharePercentage) / 100;
    
    uint256 withdrawableAmount = funderEntitledAmount - funderWithdrawnAmount[_projectName][msg.sender];

    require(withdrawableAmount > 0, "No amount available to withdraw");

    payable(msg.sender).transfer(withdrawableAmount);
    emit FunderWithdrawal(_projectName, msg.sender, withdrawableAmount);
    
    funderWithdrawnAmount[_projectName][msg.sender] += withdrawableAmount;
}



    function OFWithdraw() public onlyOwner {
    payable(owner).transfer(totalOFShare);
    totalOFShare = 0;
    }


     function updateMovieDetails(string memory _projectName, string memory _newIpfsHash, uint256 _newViewCost) public {
        require(projectRegistry.isProjOwner(_projectName, msg.sender), "Only the project owner can update the movie details");
        require(bytes(movies[_projectName].ipfsHash).length != 0, "Movie not found");

        movies[_projectName].ipfsHash = _newIpfsHash;
        movies[_projectName].viewCost = _newViewCost;

        emit MovieDetailsUpdated(_projectName, _newIpfsHash, _newViewCost);
    }


    function isViewer(string memory _projectName, address _viewer) public view returns (bool) {
    require(bytes(movies[_projectName].ipfsHash).length != 0, "Movie not found");
    
    for (uint i = 0; i < movies[_projectName].viewers.length; i++) {
        if (movies[_projectName].viewers[i] == _viewer) {
            return true;
        }
    }
    return false;
    }


    function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0) && newOwner != owner, "Invalid new owner address");
    pendingOwner = newOwner;
    emit OwnershipTransferInitiated(owner, pendingOwner);
    }   

    function claimOwnership() public  {
    require(msg.sender == pendingOwner, "Not the pending owner");
    emit OwnershipTransferred(owner, pendingOwner);
    owner = pendingOwner;
    pendingOwner = address(0);
    }

    function getAllMovies() public view returns (string[] memory, string[] memory) {
    uint256 movieCount = allMovieNames.length;
    string[] memory projectNames = new string[](movieCount);
    string[] memory ipfsHashes = new string[](movieCount);

    for (uint256 i = 0; i < movieCount; i++) {
        string memory projectName = allMovieNames[i];
        Movie storage movie = movies[projectName];
        projectNames[i] = projectName;
        ipfsHashes[i] = movie.ipfsHash;
    }

    return (projectNames, ipfsHashes);
}



}