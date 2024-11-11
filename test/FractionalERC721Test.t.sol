// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FractionalERC721} from "../src/FractionalERC721.sol";

import "forge-std/Test.sol";

contract FractionalERC721Test is Test {
    using stdStorage for StdStorage;

    FractionalERC721 public nft;
    address public owner;
    address public user;
    MockERC20 public shareToken;

    function setUp() public {
        owner = address(this);
        user = address(0x1);
        nft = new FractionalERC721("Test NFT", "TNFT", "test-uri", owner);
        shareToken = new MockERC20("Share Token", "ST");
    }

    function testInitialState() public {
        assertEq(nft.name(), "Test NFT");
        assertEq(nft.symbol(), "TNFT");
        assertEq(nft.tokenURI(0), "test-uri");
        assertEq(nft.owner(), owner);
        assertEq(nft.nextTokenId(), 0);
        assertEq(nft.redeemableShare(), 8000);
        assertEq(nft.registerRoyaltyTokensContract(), owner);
    }

    function testMint() public {
        uint256 tokenId = nft.mint(user);
        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), user);
        assertEq(nft.nextTokenId(), 1);
    }

    function testSetRedeemableShare() public {
        nft.setRedeemableShare(5000);
        assertEq(nft.redeemableShare(), 5000);
    }

    function testSetRedeemableShareMaxValue() public {
        vm.expectRevert("Share must be less than or equal to 10000");
        nft.setRedeemableShare(10001);
    }

    function testSetRoyaltyToken() public {
        uint256 tokenId = nft.mint(user);
        nft.setRoyaltyToken(tokenId, address(shareToken));
        assertEq(address(nft.tokenShares(tokenId)), address(shareToken));
    }

    function testSetRoyaltyTokenOnlyRegisterContract() public {
        uint256 tokenId = nft.mint(user);
        vm.prank(user);
        vm.expectRevert(
            "Only RegisterRoyaltyTokens contract can set token shares"
        );
        nft.setRoyaltyToken(tokenId, address(shareToken));
    }

    function testRedeem() public {
        // Setup
        uint256 tokenId = nft.mint(owner);
        nft.setRoyaltyToken(tokenId, address(shareToken));
        shareToken.mint(user, 100 ether);

        // Calculate required shares (80% of total supply)
        uint256 requiredShares = (shareToken.totalSupply() *
            nft.redeemableShare()) / 10000;

        // Approve shares transfer
        vm.prank(user);
        shareToken.approve(address(nft), requiredShares);

        // Redeem NFT
        vm.prank(user);
        nft.redeem(tokenId, requiredShares);

        // Verify ownership transfer
        assertEq(nft.ownerOf(tokenId), user);
        assertEq(shareToken.balanceOf(address(nft)), requiredShares);
    }

    function testRedeemInsufficientShares() public {
        uint256 tokenId = nft.mint(owner);
        nft.setRoyaltyToken(tokenId, address(shareToken));
        shareToken.mint(user, 50 ether);

        uint256 requiredShares = (shareToken.totalSupply() *
            nft.redeemableShare()) / 10000;

        vm.prank(user);
        shareToken.approve(address(nft), requiredShares);

        vm.prank(user);
        vm.expectRevert("Insufficient shares to redeem");
        nft.redeem(tokenId, requiredShares - 1);
    }

    function testRedeemNoShareToken() public {
        uint256 tokenId = nft.mint(owner);

        vm.prank(user);
        vm.expectRevert("No share token set for this NFT");
        nft.redeem(tokenId, 100 ether);
    }
}

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) public {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(
            allowance[from][msg.sender] >= amount,
            "Insufficient allowance"
        );
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }
}
