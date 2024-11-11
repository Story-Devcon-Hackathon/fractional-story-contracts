// forge test --fork-url https://rpc.odyssey.storyrpc.io/ --match-path test/RegisterRoyaltyTokens.t.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {RegisterRoyaltyTokens} from "../src/RegisterRoyaltyTokens.sol";
import {FractionalERC721} from "../src/FractionalERC721.sol";
import {RoyaltyTokenPresale} from "../src/RoyaltyTokenPresale.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RegisterRoyaltyTokensTest is Test {
    // For addresses, see https://docs.storyprotocol.xyz/docs/deployed-smart-contracts
    address internal ipAssetRegistryAddr =
        0x28E59E91C0467e89fd0f0438D47Ca839cDfEc095;
    address internal licensingModuleAddr =
        0x5a7D9Fa17DE09350F481A53B470D798c1c1aabae;
    address internal royaltyModuleAddr =
        0xEa6eD700b11DfF703665CCAF55887ca56134Ae3B;
    address internal pilTemplateAddr =
        0x58E2c909D557Cd23EF90D14f8fd21667A5Ae7a93;
    address internal royaltyPolicyLAPAddr =
        0x28b4F70ffE5ba7A26aEF979226f77Eb57fb9Fdb6;
    address internal susdAddr = 0xC0F6E387aC0B324Ec18EAcf22EE7271207dCE3d5;

    RegisterRoyaltyTokens public registerRoyaltyTokens;
    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = address(0x1);

        registerRoyaltyTokens = new RegisterRoyaltyTokens(
            ipAssetRegistryAddr,
            licensingModuleAddr,
            royaltyModuleAddr,
            pilTemplateAddr,
            royaltyPolicyLAPAddr,
            susdAddr
        );

        // Add labels for better trace output
        vm.label(ipAssetRegistryAddr, "IPAssetRegistry");
        vm.label(licensingModuleAddr, "LicensingModule");
        vm.label(royaltyModuleAddr, "RoyaltyModule");
        vm.label(pilTemplateAddr, "PILicenseTemplate");
        vm.label(royaltyPolicyLAPAddr, "RoyaltyPolicyLAP");
        vm.label(susdAddr, "SUSD");
    }

    function testCreateNFTWithRoyaltyTokensAndStartPresale() public {
        string memory name = "Test NFT";
        string memory symbol = "TNFT";
        string memory tokenURI = "test-uri";
        uint256 ltAmount = 100;
        address ltRecipient = user;

        (
            FractionalERC721 nft,
            address ipId,
            uint256 tokenId,
            uint256 licenseTermsId
        ) = registerRoyaltyTokens.createNFTWithRoyaltyTokensAndStartPresale(
                name,
                symbol,
                tokenURI,
                ltAmount,
                ltRecipient
            );

        // Verify NFT was created correctly
        assertEq(nft.name(), name);
        assertEq(nft.symbol(), symbol);
        assertEq(nft.tokenURI(tokenId), tokenURI);

        // Verify token ownership transferred to presale contract
        assertEq(
            nft.ownerOf(tokenId),
            address(registerRoyaltyTokens.ROYALTY_TOKEN_PRESALE())
        );

        // Verify presale was created and active
        RoyaltyTokenPresale presale = registerRoyaltyTokens
            .ROYALTY_TOKEN_PRESALE();
        (
            IERC20 saleToken,
            ,
            ,
            uint256 tokenPrice,
            uint256 totalTokens,
            uint256 tokensSold,
            bool presaleActive,
            address creator,

        ) = presale.sales(0);

        assertTrue(address(saleToken) != address(0));
        assertEq(tokenPrice, 1 ether);
        assertGt(totalTokens, 0);
        assertEq(tokensSold, 0);
        assertTrue(presaleActive);

        // Verify presale ownership transferred
        assertEq(presale.owner(), address(this));
    }
}
