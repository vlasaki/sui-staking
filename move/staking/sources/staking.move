module staking::staking;

use mock_token::mock::MOCK;
use staking::staking_calc::{Self, PoolState};

use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::{Self, Coin};

//=== Errors ===//

const ENotEnoughPoolFunds: u64 = 0;

//=== Structs ===//

///The admin cap for admin operations
public struct AdminCap has key, store { id: UID }

///The staking pool object
public struct Pool has key, store {
    id: UID,
    pool_state: PoolState,
    payout_balance: Balance<MOCK>,
}

//=== Init ===//

fun init(ctx: &mut TxContext) {
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };
    transfer::public_transfer(admin_cap, ctx.sender());
}

//=== Admin Functions ===//

///Create the staking pool object and make shared
public fun create_and_share_pool(_: &AdminCap, reward_rate: u64, ctx: &mut TxContext) {
    let pool = Pool {
        id: object::new(ctx),
        pool_state: staking_calc::create_pool_state(reward_rate, ctx),
        payout_balance: coin::zero<MOCK>(ctx).into_balance(),
    };
    //share pool
    transfer::share_object(pool);
}

public fun topup(_: &AdminCap, pool: &mut Pool, coin: Coin<MOCK>) {
    let topup_balance = coin.into_balance();
    pool.payout_balance.join(topup_balance);
}

//=== Public Functions ===//

public fun stake(pool: &mut Pool, coin: Coin<MOCK>, clock: &Clock, ctx: &mut TxContext) {
    //do stake calculations
    let user = ctx.sender();
    let amount = coin.value();
    let now = clock.timestamp_ms();
    staking_calc::stake(&mut pool.pool_state, user, amount, now);

    //add user coin to pool
    pool.payout_balance.join(coin.into_balance());
}

public fun withdraw(pool: &mut Pool, amount: u64, clock: &Clock, ctx: &mut TxContext): Coin<MOCK> {
    //do withdraw calculations
    let user = ctx.sender();
    let now = clock.timestamp_ms();
    let reward = staking_calc::withdraw(&mut pool.pool_state, user, amount, now);

    //payout user with coin
    let withdraw_amount = amount + reward;
    assert!(pool.payout_balance.value() >= withdraw_amount, ENotEnoughPoolFunds);
    let withdraw_balance = pool.payout_balance.split(withdraw_amount);
    let coin = coin::from_balance(withdraw_balance, ctx);
    coin
}

//=== Test Functions ===//

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
