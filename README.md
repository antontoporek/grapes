![BP_FPDAO_Logo_BlackOnWhite_sRGB_2](https://user-images.githubusercontent.com/32162112/221128811-5484d430-c357-49e8-8b25-0f04695a5691.svg)

# power equalizer 🌼

## pre launch

- [ ] adapt `initArgs.did` to your needs (see [CONFIG.md](CONFIG.md))
- [ ] add canister to [DAB](https://docs.google.com/forms/d/e/1FAIpQLSc-0BL9FMRtI0HhWj4g7CCYjf3TMr4_K_qqmagjzkUH_CKczw/viewform)
- [ ] send collection details to entrepot via form
- [ ] top canister up with cycles
- [ ] run off chain backup script with mainnet canister id
- [ ] setup auto topup of canisters

## Assets

Placeholder is optional.

Extension can be any.

`assets` folder structure:
```
assets/
  metadata.json
  placeholder.svg
  1.svg
  1_thumbnail.svg
  2.svg
  2_thumbnail.svg
  ...
```

## Deploy
For local deployment run extra commands:
```
npm run replica
npm run deploy:ledger
npm run vite
```

Deploy
```
npm run deploy <network>
```

`<network>` - local | test | staging | production

`local` and `test` deployed locally

`staging` and `production` deployed to IC mainnet

### Examples

Deploy production
```
npm run deploy production
```

Clean deploy locally
```
npm run deploy local -- --mode reinstall
```

Deploy staging with small amount of cycles (for example to test the creation of canisters)
```
npm run deploy staging -- --mode reinstall
```

## Upgrade main canister
```
dfx canister deploy production --netowork ic
```

## launch

- run `make deploy-production-ic-full`
- check if all assets uploaded correctly by calling the canisters `getTokenToAssetMapping()` method

## deploy 📚

We are using a makefile to simplify the deployment of canisters for different scenarios.

```
# makefile
deploy-locally:
	./deploy.zsh

deploy-staging-ic:
	./deploy.zsh ic

deploy-staging-ic-full:
	./deploy.zsh ic 7777

deploy-production-ic-full:
	./deploy.zsh ic 7777 production
```

```
# check the asset that are linked to the tokens
for i in {0..9}
do
    tokenid=$(ext tokenid $(dfx canister --network $network id $mode) $i | sed -n  2p)
		tokenid=$(echo $tokenid | tr -dc '[:alnum:]-')
		tokenid="${tokenid:3:-2}"
    if [[ "$network" == "ic" ]]
    then
      echo "https://$(dfx canister --network $network id $mode).raw.ic0.app/?tokenid=$tokenid"
    else
      echo "http://127.0.0.1:4943/?canisterId=$(dfx canister --network $network id $mode)&tokenid=$tokenid"
    fi
done

# after assets are shuffled and revealed
# check the assets again to see if we now indeed
# see the correct assets
# for i in {0..9}
# do
#         tokenid=$(ext tokenid $(dfx canister --network ic id staging) $i | sed -n  2p)
# 		tokenid=$(echo $tokenid | tr -dc '[:alnum:]-')
# 		tokenid="${tokenid:3:-2}"
# 		curl "$(dfx canister --network ic id staging).raw.ic0.app/?tokenid=$tokenid"
# 		echo "\n"
# done
```


## caveats 🕳

- The canister code is written in a way that the seed animation _ALWAYS_ has to be the first asset uploaded to the canister if you are doing a `revealDelay > 0`
- The seed animation video needs to be encoded in a way that it can be played on iOS devices, use `HandBrake` for that or `ffmpeg`

## vessel 🚢

- Run `vessel verify --version 0.8.1` to verify everything still builds correctly after adding a new depdenceny
- To use `vessels`s moc version when deploying, use `DFX_MOC_PATH="$(vessel bin)/moc" dfx deploy`

## shuffle 🔀

- The shuffle uses the random beacon to derive a random seed for the PRNG
- It basically shuffles all the assets in the `assets` stable variable
- The linking inside the canister is

```
tokenIndex -> assetIndex
asset[assetIndex] -> NFT
```

- by shuffling the assets, we are actually changing the mapping from `tokenIndex` to `NFT`
- initially the `tokenIndex` matches the `assetIndex` (`assetIndex` = `tokenIndex+1`) and the `assetIndex` matches the `NFT` (`NFT` = `assetIndex+1`)
- but after the shuffle the `assetIndex` and the `NFT` mint number no longer match
- so so token at `tokenIndex` still points to the same asset at `assetIndex`, but this asset no longer has the same `NFT` mint number
- we can always retrieve the `NFT` mint number from the `_asset[index].name` property which we specify when adding an asset to the canister

## off-chain backup ⛓

We use the `getRegistry` (`tokenIndex -> AccountIdentifier`) and `getTokenToAssetMapping` (`tokenIndex -> NFT`) canister methods to backup state offchain. Therefore we simply use a script that queries the afore mentioned methods every 60 minutes and saves the responses on a server. You can find the script in `state_backup`. We are also submitting every transaction to `CAP`, which again offers off-chain backups of their data.

Note that the indices of the json outputs represent the indices of the internal storage. E.g. index `0` means it is the first item in the array. In the UI (entrepot or stoic wallet) those indices are incremented by one, so they start with `1` and not with `0`.

To have the same token identifiers for the same tokens, it is important to keep the order of the minting when reinstantiating the canister.

So when executing `mintNFT`, the `to` address is taken from `registry.json` and the `asset` is taken from `tokens.json`. It's important here that the uploading of the assets is on order (start with flower 1, end with flower 2009) and that the `assets` index 0 is used by something other than an NFT asset (before it was the seed animation)!

## Testing 🧪

Each test suite is deployed with its own env settings.

You need to switch to an anonymous identity to run the tests.

```
dfx identity use anonymouse
```

First, start a local replica and deploy

```
npm run replica
npm run deploy-local
```

To deploy and run all tests

```
npm run test
```

To deploy and run specific tests

```
npm run test pending-sale
```

To run tests without deployment (useful when writing tests)

```
npm run vitest
```

or

```
npm run vitest:watch
```

or to run specific test suite

```
npm run vitest pending-sale
```

## manual testing 🧪

deploy the canister with

```
dfx deploy
```

use the following command to upload an asset that fits into a single message

```
dfx canister call btcflower addAsset '(record {name = "privat";payload = record {ctype = "text/html"; data = vec {blob "hello world!"} } })'
```

use the following command to mint a token

```
dfx canister call btcflower mintNFT '(record {to = "75c52c5ee26d10c7c3da77ec7bc2b4c75e1fdc2b92e01d3da6986ba67cfa1703"; asset = 0 : nat32})'
```

run icx-proxy to be able to user query parameters locally

```
$(dfx cache show)/icx-proxy --address 127.0.0.1:8453 -vv
```

---

**NOTE**

you can also use `http://127.0.0.1:8000/?canisterId=rrkah-fqaaa-aaaaa-aaaaq-cai&asset=0` or `http://127.0.0.1:8000/1.svg?canisterId=rrkah-fqaaa-aaaaa-aaaaq-cai&asset=0` locally

---

add the following line to `/etc/hosts` if on mac

```
127.0.0.1       rrkah-fqaaa-aaaaa-aaaaq-cai.localhost
```

the canister can now be accesed with

```
http://rwlgt-iiaaa-aaaaa-aaaaa-cai.localhost:8453/?tokenid=rwlgt-iiaaa-aaaaa-aaaaa-cai
```

or via command line with

```
curl "rwlgt-iiaaa-aaaaa-aaaaa-cai.localhost:8453/?tokenid=rwlgt-iiaaa-aaaaa-aaaaa-cai"
```

<h2 id="ext">ext-cli 🔌</h2>

to get the tokenid from the canister and index do the following

1. clone https://github.com/Toniq-Labs/ext-cli and https://github.com/Toniq-Labs/ext-js in the same directory
2. run `npm i -g` from within `ext-cli`
3. run `ext token <canister_id> <index>`

## settlements

- if there's a settlement that didn't work, we can call the `settlements` query method and then `settle` using the index to settle the transaction

- if there a salesSettelemnts that didnt work, we call the `salesSettlements` query method and then `retrieve` using the address to settle the transaction
