// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./UsersContract.sol";

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

contract MarketplaceContract {
    address admin;
    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "NOT_AUTHORIZED");
        _;
    }
    
    IERC20 public token;
    UsersContract public userContract;

    uint8 totalTypes = 9;
    function updateTotalTypes(uint8 _types) external onlyAdmin {
        totalTypes = _types;
    }

    struct MarketListing {
        address seller;
        uint8 resourceType;
        uint256 amount;
        uint256 pricePerUnit;
        bool isActive;
    }
    mapping (uint256 => MarketListing) public marketListing;

    uint256 public nextListingId;

    struct ResourceAnalytics {
        uint256 totalUnitsSold;
        uint256 totalRevenue;
        uint256 averagePrice;
        uint256 lastPrice;
        uint256 minPrice;
        uint256 maxPrice;
        uint256 lastUpdatedTime;
    }

    mapping ( uint8 => ResourceAnalytics ) public resourceAnalytics;

    struct ListingAnalytics {
        uint256 totalUnitsListed;
        uint256 totalListingValue;
        uint256 totalListings;
        uint256 averageListingPrice;
        uint256 lastUpdatedTime;
    }

    mapping ( uint8 => ListingAnalytics ) public listingAnalytics;

    struct PricePoint {
        uint256 price;
        uint256 timestamp;
    }

    mapping ( uint8 => PricePoint[] ) public priceHistory;

    struct DailyPriceSummary {
        uint256 low;
        uint256 high;
        uint256 total;
        uint256 count;
        uint256 average;
    }

    mapping ( uint8 => mapping ( uint256 => DailyPriceSummary ) ) public dailyPriceSummary;

    function listItems(
        uint8 _resourceType,
        uint32 _amount,
        uint256 _pricePerUnit
    ) public {
        require( _amount > 0, "Amount must be greater than 0");
        uint256 amount = userContract.getUserInventory(msg.sender, _resourceType);
        require(amount > _amount, "Not enough resources");
        userContract.updateInventory(msg.sender, _resourceType, _amount, false);

        marketListing[nextListingId] = MarketListing({
            seller: msg.sender,
            resourceType: _resourceType,
            amount: _amount,
            pricePerUnit: _pricePerUnit,
            isActive: true
        });

        ListingAnalytics storage la = listingAnalytics[_resourceType];
        la.totalUnitsListed += _amount;
        la.totalListingValue += (_pricePerUnit * _amount);
        la.totalListings += 1;
        la.lastUpdatedTime = block.timestamp;
        nextListingId++;

        if (la.totalUnitsListed > 0) {
            la.averageListingPrice = la.totalListingValue / la.totalUnitsListed;
        }
    }

    function buyListedResource( uint256 listingId, uint32 buyAmount ) external {
        MarketListing storage listing = marketListing[listingId];
        require(listing.isActive, "Listing not available");
        require(buyAmount > 0 && buyAmount <= listing.amount, "INVALID_BUY_AMOUNT");
        uint256 totalCost = listing.pricePerUnit * buyAmount;
        require(
            token.transferFrom(msg.sender, listing.seller, totalCost), "TOKEN_TRASFER_FAILED"
        );

        userContract.updateInventory(msg.sender, listing.resourceType, buyAmount, true);

        marketListing[listingId].amount -= buyAmount;
        if ( marketListing[listingId].amount == 0 ) {
            marketListing[listingId].isActive = false;
        }

        ResourceAnalytics storage ra = resourceAnalytics[listing.resourceType];
        ra.totalUnitsSold += buyAmount;
        ra.totalRevenue += totalCost;
        ra.lastPrice = listing.pricePerUnit;
        ra.lastUpdatedTime = block.timestamp;

        if ( ra.minPrice == 0 || listing.pricePerUnit < ra.minPrice ) {
            ra.minPrice = listing.pricePerUnit;
        }
        if ( listing.pricePerUnit > ra.maxPrice ) {
            ra.maxPrice = listing.pricePerUnit;
        }
        if ( ra.totalUnitsSold > 0 ) {
            ra.averagePrice = ra.totalRevenue / ra.totalUnitsSold;
        }

        PricePoint memory point = PricePoint({
            price: listing.pricePerUnit,
            timestamp: block.timestamp
        });

        priceHistory[listing.resourceType].push(point);
        uint256 day = block.timestamp / 1 days;
        DailyPriceSummary storage summary = dailyPriceSummary[listing.resourceType][day];

        if ( summary.count == 0 ) {
            summary.low = listing.pricePerUnit;
            summary.high = listing.pricePerUnit;
        } else {
            if ( listing.pricePerUnit < summary.low ) summary.low = listing.pricePerUnit;
            if ( listing.pricePerUnit > summary.high ) summary.high = listing.pricePerUnit;
        }

        summary.total += listing.pricePerUnit;
        summary.count += 1;
        summary.average = summary.total / summary.count;        
    }


    

}
