module mock_token::mock;

use sui::coin::{Self};
use sui::url;
use std::u64::{Self};


//=== Constants ===//

const DECIMALS: u8 = 6;
const SYMBOL: vector<u8> = b"MOCK";
const NAME: vector<u8> = b"MOCK_TOKEN";
const DESCRIPTION: vector<u8> = b"Mock token etc.";
const ICON_URL: vector<u8> = b"";
const WHOLE_MAX_SUPPLY: u64 = 1_000_000_000;

//=== Structs ===//

/// mock token One-Time Witness
public struct MOCK has drop {}

//=== Init ===//

fun init(otw: MOCK, ctx: &mut TxContext) {
    let (mut treasury_cap, metadata) = coin::create_currency(
        otw,
        DECIMALS,
        SYMBOL,
        NAME,
        DESCRIPTION,
        option::some(url::new_unsafe_from_bytes(ICON_URL)),
        ctx,
    );

    //mint and transfer max supply
    let max_supply = WHOLE_MAX_SUPPLY * u64::pow(10, DECIMALS);
    coin::mint_and_transfer(&mut treasury_cap, max_supply, ctx.sender(), ctx);

    //freeze metadata
    transfer::public_freeze_object(metadata);

    //transfer treasury cap
    //should burn upon receipt in order to maintain the max supply
    transfer::public_transfer(treasury_cap, ctx.sender());
}

//=== Public Functions ===//

public fun whole_mock(): u64 {
   u64::pow(10, DECIMALS)
}

//=== Test Functions ===//

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(MOCK{}, ctx);
}

