These are the 4 main contracts for the OpenFilms project under BollyCoin.

The name and functions of the contracts are as follows:
1. Registry - This contract is essentially a DB of all the projects and the key pieces of information related to all projects is stored in this contract. This contract also interfaces with all other contracts when a user is taking a critical action for a project in the other 3 contracts. Obviously you'll have to go through the contracts in detail to know more about what is being talked about here. 
2. Minter - This contract allows the founder of the project to mint NFTs and issues an NFT to the investor of a project when they fund the project.
3. Claimer - This contract allows the owner of a project to claim the accumulated funds given by the investors in an accountable way. It also allows the investors to control/ restrict the disbursement of the funds to the owner by a voting mechanism.
4. Release - This contract allows the owner to release his film on the openfilms platform, the viewer to pay for the content before accessing it and the owner to claim revenue generated from the views.

After one deploys these contracts on Ethereum or Polygon. He will have to do the interface the contracts with each other for them to work. Instructions for doing that are as follows:
1. Register contract - Call the setNFTContractAddress function with the address of the Minter contract and setClaimContractAddress with the address of the claim contract.
2. Minter contract - Call setRegistryAddress & setClaimAddress functions with their respective addresses.
3. Claim contract - Call setRegistryAddress function with the address of the registry contract.
4. Release contract - Call setProjectRegistryAddress function with the address of the registry contract.

Note that the above functions can only be called by the owner of the contracts. The deployer can transfer ownership of the contract after deploying them

 
