import Principal "mo:base/Principal";
import Time "mo:base/Time";

module {
  public type AccountIdentifier = Text;
  public type Address = Text; // Legacy account identifier or ICRC-1 account

  public type Duration = {
    #nanoseconds : Nat;
    #seconds : Nat;
    #minutes : Nat;
    #hours : Nat;
    #days : Nat;
    #none;
  };

  public type WhitelistSlot = {
    start : Time.Time;
    end : Time.Time;
  };

  public type PriceInfo = {
    ledger : Principal;
    price : Nat64; // e8s
  };

  public type PriceInfoWithLimit = PriceInfo and {
    limit : ?Nat;
  };

  public type Whitelist = {
    name : Text;
    prices : [PriceInfo];
    addresses : [AccountIdentifier];
    oneTimeOnly : Bool; // Whitelist addresses are removed after purchase
    startTime : Time.Time;
    endTime : ?Time.Time;
  };

  public type DutchAuction = {
    target : {
      #everyone; // dutch auction for everyone
      #whitelist; // dutch auction for whitelist(tier price is ignored), then salePrice for public sale
      #publicSale; // tier price for whitelist, then dutch auction for public sale
    };
    startPrice : Nat64; // start price for dutch auction
    intervalPriceDrop : Nat64; // drop price every interval
    reservePrice : Nat64; // reserve price
    interval : Time.Time; // nanoseconds
  };

  public type InitArgs = {
    name : Text;
    sale : {
      #supply: Nat; // fixed collection size
      #duration: Duration; // no definite collection size and can be minted within a given time (starting after 'publicSaleStart')
    };
    salePrices : [PriceInfoWithLimit];
    publicSaleStart : Time.Time;
    salesDistribution : [(Address, Nat64)];
    royalties : [(Address, Nat64)];
    marketplaces : [(Text, AccountIdentifier, Nat64)]; // first marketplace is default
    // How long to delay assets shuffling and reveal (starting after 'publicSaleStart')
    // 0 - assets will be revealed immediately and assets shuffling will be disabled
    revealDelay : Duration;
    airdrop : [AccountIdentifier];
    whitelists : [Whitelist]; // order from lower price to higher price
    dutchAuction: ?DutchAuction;
    // true - the entire collection will consists of only one asset, meaning all NFTs look the same
    // false - there are at least two different assets in the collection
    singleAssetCollection : ?Bool;
    escrowDelay : ?Duration; // default 2 minutes
    marketDelay : ?Duration; // How long to delay market opening (2 days after whitelist sale started or when sold out) (default 2 days)
    test : ?Bool; // must be null
    restoreEnabled : ?Bool; // must be null (see backup/README.md for details)
    timersInterval : ?Duration; // default 60 seconds
    legacyPlaceholder : ?Bool; // legacy placeholder is stored in the first asset (we need this because of getTokenToAssetMapping())
  };

  public type Config = InitArgs and {
    canister: Principal;
    minter: Principal;
  };
};