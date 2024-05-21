import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Random "mo:base/Random";
import Result "mo:base/Result";
import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Debug "mo:base/Debug";

import AviateAccountIdentifier "mo:accountid/AccountIdentifier";
import Root "mo:cap/Root";
import Fuzz "mo:fuzz";
import Account "mo:account";
import LedgerTypes "mo:ledger-types";
import ICRC1 "mo:icrc1-types";

import Types "types";
import RootTypes "../types";
import Utils "../utils";

module {
  public class Factory(config : RootTypes.Config, deps : Types.Dependencies) {
    let openEdition = switch (config.sale) {
      case (#supply(_)) false;
      case (#duration(_)) true;
    };

    /*********
    * STATE *
    *********/

    var _saleTransactions = Buffer.Buffer<Types.SaleTransactionV3>(0);
    var _salesSettlements = TrieMap.TrieMap<Types.Address, Types.SaleV3>(Text.equal, Text.hash);
    var _failedSales = Buffer.Buffer<Types.SaleV3>(0);
    var _tokensForSale = Buffer.Buffer<Types.TokenIndex>(0);
    var _whitelistSpots = TrieMap.TrieMap<Types.WhitelistSpotId, Types.RemainingSpots>(Text.equal, Text.hash);
    var _soldByLedger = TrieMap.TrieMap<Principal, Nat64>(Principal.equal, Principal.hash);
    var _soldIcp = 0 : Nat64;
    var _sold = 0 : Nat;
    var _totalToSell = 0 : Nat;
    var _nextSubAccount = 0 : Nat;

    public func getChunkCount(chunkSize : Nat) : Nat {
      var count : Nat = _saleTransactions.size() / chunkSize;
      if (_saleTransactions.size() % chunkSize != 0) {
        count += 1;
      };
      Nat.max(1, count);
    };

    public func toStableChunk(chunkSize : Nat, chunkIndex : Nat) : Types.StableChunk {
      null;
      // let start = Nat.min(_saleTransactions.size(), chunkSize * chunkIndex);
      // let count = Nat.min(chunkSize, _saleTransactions.size() - start);
      // let saleTransactionChunk = if (_saleTransactions.size() == 0 or count == 0) {
      //   [];
      // } else {
      //   Buffer.toArray(Buffer.subBuffer(_saleTransactions, start, count));
      // };

      // if (chunkIndex == 0) {
      //   ? #v2({
      //     saleTransactionCount = _saleTransactions.size();
      //     saleTransactionChunk;
      //     salesSettlements = Iter.toArray(_salesSettlements.entries());
      //     failedSales = Buffer.toArray(_failedSales);
      //     tokensForSale = Buffer.toArray(_tokensForSale);
      //     whitelistSpots = Iter.toArray(_whitelistSpots.entries());
      //     soldIcp = _soldIcp;
      //     sold = _sold;
      //     totalToSell = _totalToSell;
      //     nextSubAccount = _nextSubAccount;
      //   });
      // } else if (chunkIndex < getChunkCount(chunkSize)) {
      //   return ? #v2_chunk({ saleTransactionChunk });
      // } else {
      //   null;
      // };
    };

    public func loadStableChunk(chunk : Types.StableChunk) {
      // switch (chunk) {
      //   // v1
      //   case (? #v1(data)) {
      //     _saleTransactions := Buffer.Buffer<Types.SaleTransaction>(data.saleTransactionCount);
      //     _saleTransactions.append(Buffer.fromArray(data.saleTransactionChunk));
      //     // _salesSettlements := TrieMap.fromEntries(data.salesSettlements.vals(), AID.equal, AID.hash);
      //     _failedSales := Buffer.fromArray<(Types.AccountIdentifier, Types.SubAccount)>(data.failedSales);
      //     _tokensForSale := Buffer.fromArray<Types.TokenIndex>(data.tokensForSale);
      //     // _whitelistSpots := data.whitelist??; leaving empty for ended sales
      //     _soldIcp := data.soldIcp;
      //     _sold := data.sold;
      //     _totalToSell := data.totalToSell;
      //     _nextSubAccount := data.nextSubAccount;
      //   };
      //   case (? #v1_chunk(data)) {
      //     _saleTransactions.append(Buffer.fromArray(data.saleTransactionChunk));
      //   };
      //   // v2
      //   case (? #v2(data)) {
      //     _saleTransactions := Buffer.Buffer<Types.SaleTransaction>(data.saleTransactionCount);
      //     _saleTransactions.append(Buffer.fromArray(data.saleTransactionChunk));
      //     _salesSettlements := TrieMap.fromEntries(data.salesSettlements.vals(), AID.equal, AID.hash);
      //     _failedSales := Buffer.fromArray<(Types.AccountIdentifier, Types.SubAccount)>(data.failedSales);
      //     _tokensForSale := Buffer.fromArray<Types.TokenIndex>(data.tokensForSale);
      //     _whitelistSpots := TrieMap.fromEntries(data.whitelistSpots.vals(), Text.equal, Text.hash);
      //     _soldIcp := data.soldIcp;
      //     _sold := data.sold;
      //     _totalToSell := data.totalToSell;
      //     _nextSubAccount := data.nextSubAccount;
      //   };
      //   case (? #v2_chunk(data)) {
      //     _saleTransactions.append(Buffer.fromArray(data.saleTransactionChunk));
      //   };
      //   case (null) {};
      // };
    };

    public func grow(n : Nat) : Nat {
      let fuzz = Fuzz.Fuzz();

      for (i in Iter.range(1, n)) {
        _saleTransactions.add({
          tokens = [fuzz.nat32.random()];
          seller = fuzz.principal.randomPrincipal(10);
          price = fuzz.nat64.random();
          ledger = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");
          buyer = fuzz.text.randomAlphanumeric(32);
          time = fuzz.int.randomRange(1670000000000000000, 2670000000000000000);
        });
      };

      _saleTransactions.size();
    };

    // *** ** ** ** ** ** ** ** ** * * PUBLIC INTERFACE * ** ** ** ** ** ** ** ** ** ** /

    // updates
    public func initMint(caller : Principal) : Result.Result<(), Text> {
      assert (caller == config.minter);

      if (deps._Tokens.getNextTokenId() != 0) {
        return #err("already minted");
      };

      // Mint
      mintCollection();

      // turn whitelists into TrieMap for better performance
      for (whitelist in config.whitelists.vals()) {
        for (address in whitelist.addresses.vals()) {
          addWhitelistSpot(whitelist, address);
        };
      };

      // get initial token indices (this will return all tokens as all of them are owned by "0000")
      _tokensForSale := switch (deps._Tokens.getTokensFromOwner("0000")) {
        case (?t) t;
        case (_) Buffer.Buffer<Types.TokenIndex>(0);
      };

      return #ok;
    };

    public func shuffleTokensForSale(caller : Principal) : async () {
      assert (caller == config.minter);
      switch (config.sale) {
        case (#supply(supplyCap)) {
          assert (supplyCap == _tokensForSale.size());
        };
        case (_) {};
      };
      // shuffle indices
      let seed : Blob = await Random.blob();
      Utils.shuffleBuffer(_tokensForSale, seed);
    };

    public func airdropTokens(caller : Principal) : () {
      assert (caller == config.minter and _totalToSell == 0);

      // airdrop tokens
      for (a in config.airdrop.vals()) {
        // nextTokens() updates _tokensForSale, removing consumed tokens
        deps._Tokens.transferTokenToUser(nextTokens(1)[0], a);
      };
    };

    public func enableSale(caller : Principal) : Nat {
      assert (caller == config.minter and _totalToSell == 0);
      _totalToSell := _tokensForSale.size();
      _tokensForSale.size();
    };

    public func reserve(caller : Principal, address : Types.Address, ledger : Principal) : Result.Result<(Types.Address, Nat64), Text> {
      switch (config.sale) {
        case (#duration(duration)) {
          if (Time.now() > config.publicSaleStart + Utils.toNanos(duration)) {
            return #err("The sale has ended");
          };
        };
        case (_) {};
      };

      // check if caller is owner of the address
      let addressAccountRes = Account.fromText(address);
      switch (addressAccountRes) {
        case (#ok(addressAccount)) {
          if (caller != addressAccount.owner) {
            return #err("Reserve can only be called by the owner of the address");
          };
        };
        case (#err(_)) {
          return #err("Invalid address. Please make sure the address is a valid principal");
        };
      };

      // check if the ledger is allowed
      if (_isLedgerAllowed(ledger)) {
        return #err("This ledger is not allowed");
      };

      let inPendingWhitelist = Option.isSome(getEligibleWhitelist(address, true));
      let inOngoingWhitelist = Option.isSome(getEligibleWhitelist(address, false));

      if (Time.now() < config.publicSaleStart) {
        if (inPendingWhitelist and not inOngoingWhitelist) {
          return #err("The sale has not started yet");
        } else if (not isWhitelisted(address)) {
          return #err("The public sale has not started yet");
        };
      };

      if (availableTokens() == 0) {
        return #err("No more NFTs available right now!");
      };

      let price = getAddressPrice(address, ledger);
      let subaccount = getNextSubAccount();
      let paymentAddress : Types.Address = Account.toText({ owner = config.canister; subaccount = ?Blob.fromArray(subaccount) });

      // we only reserve the tokens here, they deducted from the available tokens
      // after payment. otherwise someone could stall the sale by reserving all
      // the tokens without paying for them
      let tokens : [Types.TokenIndex] = tempNextTokens(1);
      _salesSettlements.put(
        paymentAddress,
        {
          tokens = tokens;
          price = price;
          ledger = ledger;
          subaccount = subaccount;
          buyer = address;
          expires = Time.now() + Utils.toNanos(Option.get(config.escrowDelay, #minutes(2)));
          whitelistName = switch (getEligibleWhitelist(address, false)) {
            case (?whitelist) ?whitelist.name;
            case (null) null;
          };
        },
      );

      // remove whitelist spot if one time only
      switch (getEligibleWhitelist(address, false)) {
        case (?whitelist) {
          if (whitelist.oneTimeOnly) {
            removeWhitelistSpot(whitelist, address);
          };
        };
        case (null) {};
      };

      #ok((paymentAddress, price));
    };

    public func retrieve(caller : Principal, paymentAddress : Types.Address, ledger : Principal) : async* Result.Result<(), Text> {
      if (Option.isNull(_salesSettlements.get(paymentAddress))) {
        return #err("Nothing to settle");
      };
      if (_isLedgerAllowed(ledger)) {
        return #err("This ledger is not allowed");
      };

      let paymentAccount : ICRC1.Account = switch (Account.fromText(paymentAddress)) {
        case (#ok(account)) account;
        case (#err(_)) {
          // this should never happen because payment accounts are always created from within the canister which should guarantee that they are valid
          _salesSettlements.delete(paymentAddress);
          return #err("Failed to decode payment address");
        };
      };

      let ledgerActor = actor(Principal.toText(ledger)) : ICRC1.Service;
      let ledgerFee = await* _getLedgerFee(ledger);
      let balance = Nat64.fromNat(await ledgerActor.icrc1_balance_of(paymentAccount));

      // because of the await above, we check again if there is a settlement available for the paymentAddress
      let settlement = switch (_salesSettlements.get(paymentAddress)) {
        case (?settlement) { settlement };
        case (null) {
          return #err("Nothing to settle");
        };
      };

      if (settlement.tokens.size() == 0) {
        _salesSettlements.delete(paymentAddress);
        return #err("Nothing tokens to settle for");
      };

      if (balance >= settlement.price) {
        if (settlement.tokens.size() > availableTokens()) {
          // Issue refund if not enough NFTs available
          deps._Disburser.addDisbursement({
            to = settlement.buyer;
            fromSubaccount = settlement.subaccount;
            amount = balance - ledgerFee;
            tokenIndex = 0;
          });
          _salesSettlements.delete(paymentAddress);

          return #err("Not enough NFTs - a refund will be sent automatically very soon");
        };

        var tokens = nextTokens(Nat64.fromNat(settlement.tokens.size()));

        // transfer tokens to buyer
        for (token in tokens.vals()) {
          deps._Tokens.transferTokenToUser(token, settlement.buyer);
        };

        _saleTransactions.add({
          tokens = tokens;
          seller = config.canister;
          price = settlement.price;
          ledger = settlement.ledger;
          buyer = settlement.buyer;
          time = Time.now();
        });
        _soldByLedger.put(settlement.ledger, Option.get<Nat64>(_soldByLedger.get(settlement.ledger), 0 : Nat64) + settlement.price);
        if (settlement.ledger == Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai")) {
          _soldIcp += settlement.price;
        };
        _sold += tokens.size();
        _salesSettlements.delete(paymentAddress);
        let event : Root.IndefiniteEvent = {
          operation = "mint";
          details = [
            ("to", #Text(settlement.buyer)),
            ("price_decimals", #U64(8)),
            ("price_currency", #Text(Principal.toText(ledger))),
            ("price", #U64(settlement.price)),
            // there can only be one token in tokens due to the reserve function
            ("token_id", #Text(Utils.indexToIdentifier(settlement.tokens[0], config.canister))),
          ];
          caller;
        };
        ignore deps._Cap.insert(event);
        // Payout
        // remove total transaction fee from balance to be splitted
        let bal : Nat64 = balance - (ledgerFee * Nat64.fromNat(config.salesDistribution.size()));

        // disbursement sales
        for (f in config.salesDistribution.vals()) {
          var _fee : Nat64 = bal * f.1 / 100000;
          deps._Disburser.addDisbursement({
            to = Utils.toAccountId(f.0);
            fromSubaccount = settlement.subaccount;
            amount = _fee;
            tokenIndex = 0;
          });
        };
        return #ok();
      } else {
        // if the settlement expired and they still didnt send the full amount, we add them to failedSales
        if (settlement.expires < Time.now()) {
          _failedSales.add(settlement);
          _salesSettlements.delete(paymentAddress);

          // add back to whitelist if one time only
          switch (settlement.whitelistName) {
            case (?whitelistName) {
              for (whitelist in config.whitelists.vals()) {
                if (whitelist.name == whitelistName and whitelist.oneTimeOnly) {
                  addWhitelistSpot(whitelist, settlement.buyer);
                };
              };
            };
            case (_) {};
          };
          return #err("Expired");
        } else {
          return #err("Insufficient funds sent");
        };
      };
    };

    public func cronSalesSettlements(caller : Principal) : async* () {
      // _saleSattlements can potentially be really big, we have to make sure
      // we dont get out of cycles error or error that outgoing calls queue is full.
      // This is done by adding the await statement.
      // For every message the max cycles is reset
      label settleLoop while (true) {
        switch (expiredSalesSettlements().entries().next()) {
          case (?(paymentAddress, settlement)) {
            try {
              ignore (await* retrieve(caller, paymentAddress, settlement.ledger));
            } catch (e) {
              break settleLoop;
            };
          };
          case null break settleLoop;
        };
      };
    };

    public func cronFailedSales() : async* () {
      label failedSalesLoop while (true) {
        let last = _failedSales.removeLast();
        switch (last) {
          case (?failedSale) {
            try {
              // check if subaccount holds tokens
              let ledgerActor = actor(Principal.toText(failedSale.ledger)) : ICRC1.Service;
              let ledgerFee = await* _getLedgerFee(failedSale.ledger);

              let balance = Nat64.fromNat(await ledgerActor.icrc1_balance_of({
                owner = config.canister;
                subaccount = ?Blob.fromArray(failedSale.subaccount);
              }));

              if (balance > ledgerFee) {
                let buyerAccount : ICRC1.Account = switch (Account.fromText(failedSale.buyer)) {
                  case (#ok(account)) account;
                  case (#err(_)) {
                    // this should never happen because payment accounts are always created from within the canister which should guarantee that they are valid
                    continue failedSalesLoop;
                  };
                };

                var res = await ledgerActor.icrc1_transfer({
                  memo = null;
                  amount = Nat64.toNat(balance - ledgerFee);
                  fee = ?Nat64.toNat(ledgerFee);
                  from_subaccount = ?Blob.fromArray(failedSale.subaccount);
                  to = buyerAccount;
                  created_at_time = null;
                });

                switch (res) {
                  case (#Ok(bh)) {};
                  case (#err(_)) {
                    // if the transaction fails for some reason, we add it back to the Buffer
                    _failedSales.add(failedSale);
                    break failedSalesLoop;
                  };
                };
              };
            } catch (e) {
              // if the transaction fails for some reason, we add it back to the Buffer
              _failedSales.add(failedSale);
              break failedSalesLoop;
            };
          };
          case (null) {
            break failedSalesLoop;
          };
        };
      };
    };

    public func getNextSubAccount() : Types.SubAccount {
      var _saOffset = 4294967296;
      _nextSubAccount += 1;
      return Utils.natToSubAccount(_saOffset +_nextSubAccount);
    };

    // queries
    public func salesSettlements() : [(Types.Address, Types.SaleV3)] {
      Iter.toArray(_salesSettlements.entries());
    };

    public func failedSales() : [Types.SaleV3] {
      Buffer.toArray(_failedSales);
    };

    public func saleTransactions() : [Types.SaleTransactionV3] {
      Buffer.toArray(_saleTransactions);
    };

    public func getSold() : Nat {
      _sold;
    };

    public func getTotalToSell() : Nat {
      _totalToSell;
    };

    public func salesSettings(address : Types.Address) : Types.SaleSettingsV3 {
      var startTime = config.publicSaleStart;
      var endTime : Time.Time = 0;

      switch (config.sale) {
        case (#duration(duration)) {
          endTime := config.publicSaleStart + Utils.toNanos(duration);
        };
        case (_) {};
      };

      // for whitelisted user return nearest and cheapest slot start time
      switch (getEligibleWhitelist(address, true)) {
        case (?whitelist) {
          startTime := whitelist.startTime;
          endTime := Option.get(whitelist.endTime, 0);
        };
        case (_) {};
      };

      let icpPriceInfoOpt = Array.find(config.salePrices, func(p : RootTypes.PriceInfo) : Bool {
        p.ledger == Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai")
      });
      let icpPriceOpt = Option.map(icpPriceInfoOpt, func(p : RootTypes.PriceInfo) : Nat64 { p.price; });

      return {
        price = getAddressPrice(address, Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai"));
        salePrice = Option.get(icpPriceOpt, 0 : Nat64);
        prices = getAddressPrices(address);
        salePrices = config.salePrices;
        remaining = availableTokens();
        sold = _sold;
        totalToSell = _totalToSell;
        startTime = startTime;
        endTime = endTime;
        whitelistTime = config.publicSaleStart;
        whitelist = isWhitelisted(address);
        openEdition = openEdition;
      } : Types.SaleSettingsV3;
    };

    /*******************
    * INTERNAL METHODS *
    *******************/

    // getters & setters
    public func availableTokens() : Nat {
      if (openEdition) {
        return 1;
      };
      _tokensForSale.size();
    };

    public func soldIcp() : Nat64 {
      _soldIcp;
    };

    // internals
    func tempNextTokens(qty : Nat64) : [Types.TokenIndex] {
      Array.freeze(Array.init<Types.TokenIndex>(Nat64.toNat(qty), 0));
    };

    func getAddressPrice(address : Types.Address, ledger : Principal) : Nat64 {
      let prices = getAddressPrices(address);
      let priceInfoOpt = Array.find(prices, func(p : RootTypes.PriceInfo) : Bool {
        p.ledger == ledger
      });
      switch (priceInfoOpt) {
        case (?priceInfo) priceInfo.price;
        case (null) {
          Debug.trap("Price not found for ledger " # Principal.toText(ledger) # " and address " # address);
        };
      };
    };

    func getAddressPrices(address : Types.Address) : [RootTypes.PriceInfo] {
      // dutch auction (only ICP ledger is supported for now)
      switch (config.dutchAuction) {
        case (?dutchAuction) {
          // dutch auction for everyone
          let everyone = dutchAuction.target == #everyone;
          // dutch auction for whitelist (tier price is ignored), then salePrice for public sale
          let whitelist = dutchAuction.target == #whitelist and isWhitelisted(address);
          // tier price for whitelist, then dutch auction for public sale
          let publicSale = dutchAuction.target == #publicSale and not isWhitelisted(address);

          if (everyone or whitelist or publicSale) {
            return [{
              ledger = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");
              price = getCurrentDutchAuctionPrice(dutchAuction);
            }];
          };
        };
        case (null) {};
      };

      // we have to make sure to only return prices that are available in the current whitelist slot
      // if i had a wl in the first slot, but now we are in slot 2, i should not be able to buy at the price of slot 1

      // this method assumes the wl prices are added in ascending order, so the cheapest wl price in the earliest slot
      // is always the first one.
      switch (getEligibleWhitelist(address, true)) {
        case (?whitelist) {
          return whitelist.prices;
        };
        case (_) {};
      };

      return config.salePrices;
    };

    func getCurrentDutchAuctionPrice(dutchAuction : RootTypes.DutchAuction) : Nat64 {
      let start = if (dutchAuction.target == #publicSale or config.whitelists.size() == 0) {
        config.publicSaleStart;
      } else {
        config.whitelists[0].startTime;
      };
      let timeSinceStart : Int = Time.now() - start; // how many nano seconds passed since the auction began
      // in the event that this function is called before the auction has started, return the starting price
      if (timeSinceStart < 0) {
        return dutchAuction.startPrice;
      };
      let priceInterval = timeSinceStart / dutchAuction.interval; // how many intervals passed since the auction began
      // what is the discount from the start price in this interval
      let discount = Nat64.fromIntWrap(priceInterval) * dutchAuction.intervalPriceDrop;
      // to prevent trapping, we check if the start price is bigger than the discount
      if (dutchAuction.startPrice > discount) {
        return dutchAuction.startPrice - discount;
      } else {
        return dutchAuction.reservePrice;
      };
    };

    func nextTokens(qty : Nat64) : [Types.TokenIndex] {
      if (openEdition) {
        deps._Tokens.mintNextToken();
        _tokensForSale := switch (deps._Tokens.getTokensFromOwner("0000")) {
          case (?t) t;
          case (_) Buffer.Buffer<Types.TokenIndex>(0);
        };
      };

      if (_tokensForSale.size() >= Nat64.toNat(qty)) {
        var ret : List.List<Types.TokenIndex> = List.nil();
        while (List.size(ret) < Nat64.toNat(qty)) {
          switch (_tokensForSale.removeLast()) {
            case (?token) {
              ret := List.push(token, ret);
            };
            case _ return [];
          };
        };
        List.toArray(ret);
      } else {
        [];
      };
    };

    func getWhitelistSpotId(whitelist : Types.Whitelist, address : Types.Address) : Types.WhitelistSpotId {
      whitelist.name # ":" # address;
    };

    func addWhitelistSpot(whitelist : Types.Whitelist, address : Types.Address) {
      let remainingSpots = Option.get(_whitelistSpots.get(getWhitelistSpotId(whitelist, address)), 0);
      _whitelistSpots.put(getWhitelistSpotId(whitelist, address), remainingSpots + 1);
    };

    func removeWhitelistSpot(whitelist : Types.Whitelist, address : Types.Address) {
      let remainingSpots = Option.get(_whitelistSpots.get(getWhitelistSpotId(whitelist, address)), 0);
      if (remainingSpots > 0) {
        _whitelistSpots.put(getWhitelistSpotId(whitelist, address), remainingSpots - 1);
      } else {
        _whitelistSpots.delete(getWhitelistSpotId(whitelist, address));
      };
    };

    // get a whitelist that has started, hasn't expired, and hasn't been used by an address
    func getEligibleWhitelist(address : Types.Address, allowNotStarted : Bool) : ?Types.Whitelist {
      for (whitelist in config.whitelists.vals()) {
        let spotId = getWhitelistSpotId(whitelist, address);
        let remainingSpots = Option.get(_whitelistSpots.get(spotId), 0);
        let whitelistStarted = Time.now() >= whitelist.startTime;
        let endTime = Option.get(whitelist.endTime, 0);
        let whitelistNotExpired = Time.now() <= endTime or endTime == 0;

        if (remainingSpots > 0 and (allowNotStarted or whitelistStarted) and whitelistNotExpired) {
          return ?whitelist;
        };
      };
      return null;
    };

    // this method is time sensitive now and only returns true, iff the address is whitelist in the current slot
    func isWhitelisted(address : Types.Address) : Bool {
      Option.isSome(getEligibleWhitelist(address, false));
    };

    func mintCollection() {
      deps._Tokens.mintCollection();
    };

    func expiredSalesSettlements() : TrieMap.TrieMap<Types.Address, Types.SaleV3> {
      TrieMap.mapFilter<Types.Address, Types.SaleV3, Types.SaleV3>(
        _salesSettlements,
        Text.equal,
        Text.hash,
        func(a : (Types.Address, Types.SaleV3)) : ?Types.SaleV3 {
          switch (a.1.expires < Time.now()) {
            case (true) {
              ?a.1;
            };
            case (false) {
              null;
            };
          };
        },
      );
    };

    func _isLedgerAllowed(ledger : Principal) : Bool {
      Array.find(config.salePrices, func(p : RootTypes.PriceInfo) : Bool {
        p.ledger == ledger
      }) == null;
    };


    var _feeByLedger = TrieMap.TrieMap<Principal, Nat64>(Principal.equal, Principal.hash);

    func _getLedgerFee(ledger : Principal) : async* Nat64 {
      switch (_feeByLedger.get(ledger)) {
        case (?fee) {
          fee;
        };
        case (null) {
          let ledgerActor = actor(Principal.toText(ledger)) : ICRC1.Service;
          let fee = Nat64.fromNat(await ledgerActor.icrc1_fee());
          _feeByLedger.put(ledger, fee);
          fee;
        };
      };
    };
  };
};
