module staking::staking_calc;

use sui::table::{Self, Table};

//=== Constants ===//
const SCALE: u64 = 1_000_000;

//=== Error codes ===//
const ENullStake: u64 = 0;
const ENullWithdraw: u64 = 1;
const ENotEnoughFunds: u64 = 2;

//=== Structs ===//

/// The pool state used in the staking calculations
public struct PoolState has key, store {
    id: UID,
    user_balances: Table<address, u64>,
    user_rewards_per_token_paid: Table<address, u64>,
    user_rewards: Table<address, u64>,
    reward_rate: u64,
    reward_per_token_stored: u64,
    total_supply: u64,
    last_update_ts: u64,
}

//=== Constructors ===//

/// Create a new pool state object
///
/// This is called when the pool is created
public(package) fun create_pool_state(reward_rate: u64, ctx: &mut TxContext): PoolState {
    PoolState {
        id: object::new(ctx),
        user_balances: table::new<address, u64>(ctx),
        user_rewards_per_token_paid: table::new<address, u64>(ctx),
        user_rewards: table::new<address, u64>(ctx),
        reward_rate,
        reward_per_token_stored: 0,
        total_supply: 0,
        last_update_ts: 0,
    }
}

//=== Public functions ===//

public(package) fun stake(pool_state: &mut PoolState, user: address, amount: u64, now: u64): u64 {
    assert!(amount > 0, ENullStake);
    //calculate reward
    let user_reward = pool_state.calculate_reward(user, now);
    //update balances
    let user_balance = pool_state.user_balances.borrow_mut(user);
    *user_balance = *user_balance + amount;
    pool_state.total_supply = pool_state.total_supply + amount;
    //update last updated ts
    pool_state.last_update_ts = now;

    user_reward
}

public(package) fun withdraw(pool_state: &mut PoolState, user: address, amount: u64, now: u64): u64 {
    assert!(amount > 0, ENullWithdraw);
    assert!pool_state.user_balances.contains(user) && pool_state.user_balances[user] >= amount,
        ENotEnoughFunds,
    );
    //calculate reward
    let user_reward = pool_state.calculate_reward(user, now);
    //update balances
    let user_balance = pool_state.user_balances.borrow_mut(user);
    *user_balance = *user_balance - amount;
    pool_state.total_supply = pool_state.total_supply - amount;
    //update last updated ts
    pool_state.last_update_ts = now;

    user_reward
}

//=== Private functions ===//

fun calculate_reward(pool_state: &mut PoolState, user: address, now: u64): u64 {
    let first_time_called = pool_state.last_update_ts == 0;
    if (first_time_called) {
        pool_state.last_update_ts = now;
    };

    //calculate reward per token stored
    let dt = now - pool_state.last_update_ts;
    let reward_rate = pool_state.reward_rate;
    let total_supply = pool_state.total_supply;
    let reward_per_token_stored = &mut pool_state.reward_per_token_stored;
    if (total_supply > 0) {
        *reward_per_token_stored =
            *reward_per_token_stored + (reward_rate * dt * SCALE) / total_supply;
    };

    //calculate user reward and set state
    //set state for the first time
    if (!pool_state.user_balances.contains(user)) {
        pool_state.user_balances.add(user, 0);
        pool_state.user_rewards.add(user, 0);
        pool_state.user_rewards_per_token_paid.add(user, *reward_per_token_stored);
    }
    //update state
    else {
        let paid = pool_state.user_rewards_per_token_paid[user];
        let delta_reward_per_token = *reward_per_token_stored - paid;
        let user_reward = pool_state.user_rewards.borrow_mut(user);
        *user_reward =
            *user_reward + (pool_state.user_balances[user] * delta_reward_per_token) / SCALE;
        let user_rewards_per_token_paid = pool_state.user_rewards_per_token_paid.borrow_mut(user);
        *user_rewards_per_token_paid = *reward_per_token_stored;
    };

    pool_state.user_rewards[user]
}
