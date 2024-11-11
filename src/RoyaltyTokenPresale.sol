// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RoyaltyTokenPresale is Ownable {
    struct Sale {
        IERC20 saleToken;
        IERC721 nftToken;
        uint256 nftTokenId;
        uint256 tokenPrice;
        uint256 totalTokens;
        uint256 tokensSold;
        bool presaleActive;
        address creator;
        uint256 creatorProceeds;
    }

    Sale[] public sales;
    uint256 public nextSaleId;

    event SaleCreated(
        uint256 indexed saleId,
        address saleToken,
        address nftToken,
        uint256 nftTokenId
    );
    event PresaleEnded(uint256 indexed saleId);
    event TokensPurchased(
        uint256 indexed saleId,
        address buyer,
        uint256 amount
    );
    event CreatorProfitClaimed(uint256 indexed saleId, uint256 amount);

    constructor() Ownable(msg.sender) {}

    function createSale(
        address _saleToken,
        address _nftToken,
        uint256 _nftTokenId,
        uint256 _tokenPrice,
        address _creator
    ) external onlyOwner returns (uint256 saleId) {
        require(_saleToken != address(0), "Invalid sale token address");
        require(_nftToken != address(0), "Invalid NFT token address");
        require(_tokenPrice > 0, "Price must be greater than 0");

        IERC20 saleToken = IERC20(_saleToken);
        IERC721 nftToken = IERC721(_nftToken);

        saleId = nextSaleId++;
        sales.push(
            Sale({
                saleToken: saleToken,
                nftToken: nftToken,
                nftTokenId: _nftTokenId,
                tokenPrice: _tokenPrice,
                totalTokens: 0,
                tokensSold: 0,
                presaleActive: true,
                creator: _creator,
                creatorProceeds: 0
            })
        );

        Sale storage newSale = sales[saleId];

        // Store total tokens available for sale
        newSale.totalTokens = saleToken.balanceOf(address(this));
        require(newSale.totalTokens > 0, "No tokens available for sale");

        // Verify NFT ownership
        require(
            nftToken.ownerOf(_nftTokenId) == address(this),
            "Contract must own the NFT"
        );

        emit SaleCreated(saleId, _saleToken, _nftToken, _nftTokenId);
    }

    function endPresale(uint256 saleId) external onlyOwner {
        require(saleId < sales.length, "Invalid sale ID");
        Sale storage sale = sales[saleId];
        require(sale.presaleActive, "Presale not active");
        sale.presaleActive = false;
        emit PresaleEnded(saleId);
    }

    function buyTokens(uint256 saleId, uint256 amount) external payable {
        require(saleId < sales.length, "Invalid sale ID");
        Sale storage sale = sales[saleId];
        require(sale.presaleActive, "Presale is not active");
        require(amount > 0, "Amount must be greater than 0");
        require(
            sale.tokensSold + amount <= sale.totalTokens,
            "Not enough tokens available"
        );
        require(msg.value >= amount * sale.tokenPrice, "Insufficient payment");

        sale.tokensSold += amount;
        require(
            sale.saleToken.transfer(msg.sender, amount),
            "Token transfer failed"
        );

        uint256 payment = amount * sale.tokenPrice;
        sale.creatorProceeds += payment;

        // Refund excess payment if any
        uint256 excess = msg.value - payment;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }

        emit TokensPurchased(saleId, msg.sender, amount);
    }

    function withdrawProceeds(uint256 saleId) external onlyOwner {
        require(saleId < sales.length, "Invalid sale ID");
        Sale storage sale = sales[saleId];
        uint256 ownerProceeds = address(this).balance - sale.creatorProceeds;
        payable(owner()).transfer(ownerProceeds);
    }

    function withdrawUnsoldTokens(uint256 saleId) external onlyOwner {
        require(saleId < sales.length, "Invalid sale ID");
        Sale storage sale = sales[saleId];
        require(!sale.presaleActive, "Presale still active");
        uint256 remainingTokens = sale.saleToken.balanceOf(address(this));
        require(
            sale.saleToken.transfer(owner(), remainingTokens),
            "Token transfer failed"
        );
    }

    function claimCreatorProfit(uint256 saleId) external {
        require(saleId < sales.length, "Invalid sale ID");
        Sale storage sale = sales[saleId];
        require(msg.sender == sale.creator, "Only creator can claim profit");
        require(sale.creatorProceeds > 0, "No profit to claim");

        uint256 profit = sale.creatorProceeds;
        sale.creatorProceeds = 0;
        payable(sale.creator).transfer(profit);

        emit CreatorProfitClaimed(saleId, profit);
    }

    function getSale(uint256 saleId) external view returns (Sale memory) {
        require(saleId < sales.length, "Invalid sale ID");
        return sales[saleId];
    }

    function getAllSales() external view returns (Sale[] memory) {
        return sales;
    }
}
