// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FractionalERC721 is ERC721, Ownable {
    uint256 public nextTokenId;
    uint256 public redeemableShare = 8000;
    string private tokenURI_;
    mapping(uint256 => IERC20) public tokenShares;
    address public immutable registerRoyaltyTokensContract;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _tokenURI,
        address _registerRoyaltyTokensContract
    ) ERC721(_name, _symbol) Ownable(msg.sender) {
        tokenURI_ = _tokenURI;
        registerRoyaltyTokensContract = _registerRoyaltyTokensContract;
    }

    function tokenURI(uint256) public view override returns (string memory) {
        return tokenURI_;
    }

    function setRedeemableShare(uint256 _newShare) public onlyOwner {
        require(
            _newShare <= 10000,
            "Share must be less than or equal to 10000"
        );
        redeemableShare = _newShare;
    }

    function mint(address _to) public onlyOwner returns (uint256) {
        uint256 tokenId = nextTokenId++;
        _mint(_to, tokenId);
        return tokenId;
    }

    function setRoyaltyToken(uint256 _tokenId, address _sharesToken) public {
        require(
            msg.sender == registerRoyaltyTokensContract,
            "Only RegisterRoyaltyTokens contract can set token shares"
        );
        tokenShares[_tokenId] = IERC20(_sharesToken);
    }

    function redeem(uint256 _tokenId, uint256 _amount) public {
        IERC20 shareToken = tokenShares[_tokenId];
        require(
            address(shareToken) != address(0),
            "No share token set for this NFT"
        );

        uint256 totalSupply = shareToken.totalSupply();
        uint256 requiredAmount = (totalSupply * redeemableShare) / 10000;

        require(_amount >= requiredAmount, "Insufficient shares to redeem");

        require(
            shareToken.transferFrom(msg.sender, address(this), _amount),
            "Transfer of shares failed"
        );

        address currentOwner = ownerOf(_tokenId);
        _transfer(currentOwner, msg.sender, _tokenId);
    }
}
