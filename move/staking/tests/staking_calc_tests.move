#[test_only]
module staking::staking_calc_tests;

use staking::staking_calc;
use sui::test_scenario;
use sui::test_utils::{Self, assert_eq};

#[test]
fun basic_stake_withdraw() {
    let admin = @0x1;
    let mut scenario = test_scenario::begin(admin);
    let ctx = scenario.ctx();

    let mut pool_state = staking_calc::create_pool_state(100, ctx);
    let alpha = @0xA;
    let beta = @0xB;
    pool_state.stake(alpha, 10, 1);
    pool_state.stake(beta, 20, 2);
    pool_state.stake(alpha, 30, 3);
    let reward_B = pool_state.withdraw(beta, 20, 4);
    let reward_A = pool_state.withdraw(alpha, 40, 5);
    assert_eq(reward_B, 99);
    assert_eq(reward_A, 299);

    test_utils::destroy(pool_state);
    scenario.end();
}
