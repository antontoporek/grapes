import { Principal } from "@dfinity/principal";
import { expect } from "vitest";
import { User } from "./user";

import canisterIds from '../../.dfx/local/canister_ids.json';
import { AccountIdentifier, SubAccount } from "@dfinity/ledger-icp";
import { decodeIcrcAccount } from '@dfinity/ledger-icrc';

export function feeOf(amount: bigint, fee: bigint) {
  return amount * fee / 100_000n;
}

export function applyFees(amount: bigint, fees: bigint[]) {
  let result = amount;
  for (let fee of fees) {
    result -= amount * fee / 100_000n;
  }
  return result;
}

export async function buyFromSale(user: User) {
  let settings = await user.mainActor.salesSettings(user.address);
  let res = await user.mainActor.reserve(user.address, Principal.fromText('ryjl3-tyaaa-aaaaa-aaaba-cai'));

  expect(res).toHaveProperty('ok');

  if ('ok' in res) {
    let paymentAddress = res.ok[0];
    let paymentAmount = res.ok[1];
    expect(paymentAddress.length).toBeGreaterThanOrEqual(38);
    expect(paymentAmount).toBe(settings.price);

    await user.sendICP(paymentAddress, paymentAmount);
    let retrieveRes = await user.mainActor.retrieve(paymentAddress);
    expect(retrieveRes).toHaveProperty('ok');
  }
}

export async function buyFromMarketplace(user: User, tokenId: string, price: bigint, frontendIdentifier: [string] | []) {
  let lockRes = await user.mainActor.lock(tokenId, price, user.accountId, new Uint8Array, frontendIdentifier);
  expect(lockRes).toHaveProperty('ok');

  let paytoAddress: string = lockRes['ok'];
  await user.sendICP(paytoAddress, price);

  let res = await user.mainActor.settle(tokenId);
  expect(res).toHaveProperty('ok');
}


export async function checkTokenCount(user: User, count: number) {
  let tokensRes = await user.mainActor.tokens(user.accountId);
  expect(tokensRes).toHaveProperty('ok');
  if ('ok' in tokensRes) {
    expect(tokensRes.ok.length).toBe(count);
    if (count > 0) {
      let tokenIndex = tokensRes.ok.at(-1);
      expect(tokenIndex).toBeGreaterThan(0);
    }
  }
}

// https://github.com/Toniq-Labs/ext-cli/blob/main/src/utils.js#L62-L66
export let to32bits = (num) => {
  let b = new ArrayBuffer(4);
  new DataView(b).setUint32(0, num);
  return Array.from(new Uint8Array(b));
}

// https://github.com/Toniq-Labs/ext-cli/blob/main/src/extjs.js#L20-L45
export let tokenIdentifier = (index) => {
  let padding = Buffer.from("\x0Atid");
  let array = new Uint8Array([
      ...padding,
      ...Principal.fromText(canisterIds.test.local).toUint8Array(),
      ...to32bits(index),
  ]);
  return Principal.fromUint8Array(array).toText();
};

export let toAccount = (address: string) => {
  if (address.length !== 64) {
    let account = decodeIcrcAccount(address);
    let subaccount = account.subaccount ? SubAccount.fromBytes(Uint8Array.from(account.subaccount)) : undefined;
    if (subaccount instanceof Error) {
      throw new Error("Invalid subaccount. " + subaccount.message);
    }
    return { account: AccountIdentifier.fromPrincipal({principal: account.owner, subAccount: subaccount}).toNumbers() };
  }
  return { account: AccountIdentifier.fromHex(address).toNumbers() };
}