// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// https://github.com/smartcontractkit/chainlink/blob/master/contracts/src/v0.8/
// https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/contracts

/* Imports*/

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/* Errors */

error NftMarketplace1__PriceMustBeAboveZero();
error NftMarketplace1__NotApprovedForMarketplace();
error NftMarketplace1__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketplace1__NotOwner();
error NftMarketplace1__NotListed(address nftAddress, uint256 tokenId);
error NftMarketplace1__PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error NftMarketplace1__NoProceeds();
error NftMarketplace1__TransferFailed();

contract NftMarketplace1 {
	struct Listing {
		uint256 price;
		address seller;
	}

	mapping(address => mapping(uint256 => Listing)) private s_listings;
	mapping(address => uint256) private s_proceeds;

	event ItemListed(
		address indexed seller,
		address indexed nftAddress,
		uint256 indexed tokenId,
		uint256 price
	);

	event ItemBought(
		address indexed buyer,
		address indexed nftAddress,
		uint256 indexed tokenId,
		uint256 price
	);

	event ItemCancelled(address indexed seller, address nftAddress, uint256 tokenId);

	modifier notListed(
		address nftAddress,
		uint256 tokenId,
		address owner
	) {
		Listing memory listing = s_listings[nftAddress][tokenId];
		if (listing.price > 0) {
			revert NftMarketplace1__AlreadyListed(nftAddress, tokenId);
		}
		_;
	}

	modifier isOwner(
		address nftAddress,
		uint256 tokenId,
		address spender
	) {
		IERC721 nft = IERC721(nftAddress);
		address owner = nft.ownerOf(tokenId);
		if (owner != spender) {
			revert NftMarketplace1__NotOwner();
		}
		_;
	}

	modifier isListed(address nftAddress, uint256 tokenId) {
		Listing memory listing = s_listings[nftAddress][tokenId];
		if (listing.price <= 0) {
			revert NftMarketplace1__NotListed(nftAddress, tokenId);
		}
		_;
	}

	constructor() {}

	function listItem(
		address nftAddress,
		uint256 tokenId,
		uint256 price
	)
		external
		notListed(nftAddress, tokenId, msg.sender)
		isOwner(nftAddress, tokenId, msg.sender)
	{
		if (price <= 0) {
			revert NftMarketplace1__PriceMustBeAboveZero();
		}

		IERC721 nft = IERC721(nftAddress);
		if (nft.getApproved(tokenId) != address(this)) {
			revert NftMarketplace1__NotApprovedForMarketplace();
		}

		s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
		emit ItemListed(msg.sender, nftAddress, tokenId, price);
	}

	function buyItem(address nftAddress, uint256 tokenId)
		external
		payable
		isListed(nftAddress, tokenId)
	{
		Listing memory listedItem = s_listings[nftAddress][tokenId];
		if (msg.value < listedItem.price) {
			revert NftMarketplace1__PriceNotMet(nftAddress, tokenId, listedItem.price);
		}
		s_proceeds[listedItem.seller] = s_proceeds[listedItem.seller] + msg.value;
		delete (s_listings[nftAddress][tokenId]);
		IERC721(nftAddress).safeTransferFrom(listedItem.seller, msg.sender, tokenId);

		emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
	}

	function cancelListing(address nftAddress, uint256 tokenId)
		external
		isOwner(nftAddress, tokenId, msg.sender)
		isListed(nftAddress, tokenId)
	{
		delete (s_listings[nftAddress][tokenId]);
		emit ItemCancelled(msg.sender, nftAddress, tokenId);
	}

	function updateListing(
		address nftAddress,
		uint256 tokenId,
		uint256 newPrice
	) external isListed(nftAddress, tokenId) isOwner(nftAddress, tokenId, msg.sender) {
		s_listings[nftAddress][tokenId].price = newPrice;
		emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
	}

	function withdrawProceeds() external {
		uint256 proceeds = s_proceeds[msg.sender];

		if (proceeds <= 0) {
			revert NftMarketplace1__NoProceeds();
		}

		s_proceeds[msg.sender] = 0;
		(bool success, ) = payable(msg.sender).call{value: proceeds}("");
		if (!success) {
			revert NftMarketplace1__TransferFailed();
		}
	}

	// Getter

	function getListing(address nftAddress, uint256 tokenId) public view returns (Listing memory) {
		return s_listings[nftAddress][tokenId];
	}

	function getProceeds(address seller) public view returns (uint256) {
		return s_proceeds[seller];
	}
}
