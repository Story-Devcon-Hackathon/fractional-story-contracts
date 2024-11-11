// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPAssetRegistry} from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import {LicensingModule} from "@storyprotocol/core/modules/licensing/LicensingModule.sol";
import {RoyaltyModule} from "@storyprotocol/core/modules/royalty/RoyaltyModule.sol";
import {PILicenseTemplate} from "@storyprotocol/core/modules/licensing/PILicenseTemplate.sol";
import {PILFlavors} from "@storyprotocol/core/lib/PILFlavors.sol";
import {RoyaltyPolicyLAP} from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import {SUSD} from "../mocks/SUSD.sol";

import {FractionalERC721} from "./FractionalERC721.sol";
import {RoyaltyTokenPresale} from "./RoyaltyTokenPresale.sol";

/// @notice Attach a Selected Programmable IP License Terms to an IP Account.
contract RegisterRoyaltyTokens {
    IPAssetRegistry public immutable IP_ASSET_REGISTRY;
    LicensingModule public immutable LICENSING_MODULE;
    RoyaltyModule public immutable ROYALTY_MODULE;
    PILicenseTemplate public immutable PIL_TEMPLATE;
    RoyaltyPolicyLAP public immutable ROYALTY_POLICY_LAP;
    SUSD public immutable SUSD_TOKEN;
    RoyaltyTokenPresale public immutable ROYALTY_TOKEN_PRESALE;

    constructor(
        address ipAssetRegistry,
        address licensingModule,
        address royaltyModule,
        address pilTemplate,
        address royaltyPolicyLAP,
        address susd
    ) {
        IP_ASSET_REGISTRY = IPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = LicensingModule(licensingModule);
        ROYALTY_MODULE = RoyaltyModule(royaltyModule);
        PIL_TEMPLATE = PILicenseTemplate(pilTemplate);
        ROYALTY_POLICY_LAP = RoyaltyPolicyLAP(royaltyPolicyLAP);
        SUSD_TOKEN = SUSD(susd);
        ROYALTY_TOKEN_PRESALE = new RoyaltyTokenPresale();
    }

    function createNFTWithRoyaltyTokensAndStartPresale(
        string memory _name,
        string memory _symbol,
        string memory _tokenURI,
        uint256 ltAmount,
        address ltRecipient
    )
        external
        returns (
            FractionalERC721 nft,
            address ipId,
            uint256 tokenId,
            uint256 licenseTermsId
        )
    {
        FractionalERC721 nft = new FractionalERC721(
            _name,
            _symbol,
            _tokenURI,
            address(this)
        );

        tokenId = FractionalERC721(nft).mint(address(this));

        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(nft), tokenId);

        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10 * 10 ** 6, // 10%
                royaltyPolicy: address(ROYALTY_POLICY_LAP),
                currencyToken: address(SUSD_TOKEN)
            })
        );

        LICENSING_MODULE.attachLicenseTerms(
            ipId,
            address(PIL_TEMPLATE),
            licenseTermsId
        );

        LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: ltAmount,
            receiver: ltRecipient,
            royaltyContext: "" // for PIL, royaltyContext is empty string
        });

        address royaltyERC20 = ROYALTY_MODULE.ipRoyaltyVaults(ipId);

        nft.setRoyaltyToken(tokenId, royaltyERC20);

        address presale = address(ROYALTY_TOKEN_PRESALE);

        IERC20(royaltyERC20).transfer(
            presale,
            IERC20(royaltyERC20).balanceOf(address(this))
        );

        FractionalERC721(nft).transferFrom(address(this), presale, tokenId);

        ROYALTY_TOKEN_PRESALE.createSale(
            royaltyERC20,
            address(nft),
            tokenId,
            1 ether, // Set price to 1 ETH, can be adjusted as needed
            msg.sender
        );

        ROYALTY_TOKEN_PRESALE.transferOwnership(msg.sender);
    }
}
