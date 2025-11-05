#[test_only]
module staking::staking_tests;

use mock_token::mock::{Self, MOCK};
use staking::staking::{Self, AdminCap, Pool};
use sui::clock::{Clock, create_for_testing, destroy_for_testing};
use sui::coin::Coin;
use sui::test_scenario::{Self, Scenario};
use sui::test_utils::assert_eq;

const ENotEnoughSupplyFunds: u64 = 0;

// - A stakes 10 at time 1
// - B stakes 20 at time 2
// - A stakes 30 at time 3
// - B withdraws 20 at time 4
// - A withdraws 40 at time 5
#[test]
fun basic_stake_withdraw_full_flow() {
    let admin = @0x1;
    let alpha = @0xA;
    let beta = @0xB;
    let reward_rate = 10u64 * mock::whole_mock(); //per second
    let topup_amount = 1000u64 * mock::whole_mock();
    let alpha_pay_amount = 40u64 * mock::whole_mock();
    let beta_pay_amount = 20u64 * mock::whole_mock();
    let alpha_stake_amount_first = 10u64 * mock::whole_mock();
    let alpha_stake_amount_second = 30u64 * mock::whole_mock();
    let beta_stake_amount = 20u64 * mock::whole_mock();
    let alpha_stake_amount = alpha_stake_amount_first + alpha_stake_amount_second;
    let alpha_reward_amount = 29999970;
    let beta_reward_amount = 9999980;

    let mut scenario = test_scenario::begin(admin);
    let ctx = scenario.ctx();
    let mut clock = create_for_testing(ctx);
    clock.set_for_testing(0);

    //mint supply of mock tokens
    init_mock(&mut scenario, admin);

    //pay users
    pay_user(&mut scenario, alpha_pay_amount, admin, alpha);
    pay_user(&mut scenario, beta_pay_amount, admin, beta);

    //initialize pool and topup the pool payout balance
    init_pool_with_topup(&mut scenario, reward_rate, topup_amount, admin);

    //stake withdraw flow
    clock.set_for_testing(1);
    stake_for_testing(&mut scenario, alpha_stake_amount_first, alpha, &clock);
    clock.set_for_testing(2);
    stake_for_testing(&mut scenario, beta_stake_amount, beta, &clock);
    clock.set_for_testing(3);
    stake_for_testing(&mut scenario, alpha_stake_amount_second, alpha, &clock);
    clock.set_for_testing(4);
    withdraw_for_testing(&mut scenario, beta_stake_amount, beta, &clock);
    clock.set_for_testing(5);
    withdraw_for_testing(&mut scenario, alpha_stake_amount, alpha, &clock);

    //check user coins
    assert_eq(user_coin_value(&mut scenario, beta), beta_reward_amount + beta_stake_amount);
    assert_eq(user_coin_value(&mut scenario, alpha), alpha_reward_amount + alpha_stake_amount);

    clock.destroy_for_testing();
    scenario.end();
}

//=== Helpers ===//

fun init_mock(scenario: &mut Scenario, admin: address) {
    scenario.next_tx(admin);
    {
        let ctx = scenario.ctx();
        mock::init_for_testing(ctx);
    };
}

fun pay_user(scenario: &mut Scenario, pay_amount: u64, admin: address, user: address) {
    //transfer some of the mock supply to the user
    scenario.next_tx(admin);
    {
        let mut supply_coin = scenario.take_from_address<Coin<MOCK>>(admin);
        let ctx = scenario.ctx();
        let pay_coin = supply_coin.split(pay_amount, ctx);
        transfer::public_transfer(pay_coin, user);
        scenario.return_to_sender(supply_coin);
    };
}

fun topup_pool(scenario: &mut Scenario, topup_amount: u64, admin: address) {
    //topup pool with a balance
    //assumes the admin cap, mock supply coin, and pool are created
    scenario.next_tx(admin);
    {
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let mut supply_coin = scenario.take_from_address<Coin<MOCK>>(admin);
        assert!(supply_coin.value() >= topup_amount, ENotEnoughSupplyFunds);
        let ctx = scenario.ctx();
        let topup_coin = supply_coin.split(topup_amount, ctx);
        let mut pool = scenario.take_shared<Pool>();
        staking::topup(&admin_cap, &mut pool, topup_coin);

        scenario.return_to_sender(admin_cap);
        scenario.return_to_sender(supply_coin);
        test_scenario::return_shared(pool);
    };
}

fun init_pool_with_topup(scenario: &mut Scenario, reward_rate: u64, topup_amount: u64, admin: address) {
    //create admin cap
    scenario.next_tx(admin);
    {
        let ctx = scenario.ctx();
        staking::init_for_testing(ctx);
    };
    //initialize pool
    scenario.next_tx(admin);
    {
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let ctx = scenario.ctx();
        staking::create_and_share_pool(&admin_cap, reward_rate, ctx);
        scenario.return_to_sender(admin_cap);
    };
    //topup pool for the first time
    topup_pool(scenario, topup_amount, admin);
}

fun stake_for_testing(scenario: &mut Scenario, amount: u64, user: address, clock: &Clock) {
    //assumes the pool is created
    scenario.next_tx(user);
    {
        let mut pool = scenario.take_shared<Pool>();
        let mut user_coin = scenario.take_from_address<Coin<MOCK>>(user);
        let ctx = scenario.ctx();
        let stake_coin = user_coin.split(amount, ctx);
        staking::stake(&mut pool, stake_coin, clock, ctx);
        scenario.return_to_sender(user_coin);
        test_scenario::return_shared(pool);
    };
}

fun withdraw_for_testing(scenario: &mut Scenario, amount: u64, user: address, clock: &Clock) {
    //assumes the pool is created
    scenario.next_tx(user);
    {
        let mut pool = scenario.take_shared<Pool>();
        let mut user_coin = scenario.take_from_address<Coin<MOCK>>(user);
        let ctx = scenario.ctx();
        let withdraw_coin = staking::withdraw(&mut pool, amount, clock, ctx);
        user_coin.join(withdraw_coin);
        scenario.return_to_sender(user_coin);
        test_scenario::return_shared(pool);
    };
}

fun user_coin_value(scenario: &mut Scenario, user: address): u64 {
    let value;
    scenario.next_tx(user);
    {
        let user_coin = scenario.take_from_address<Coin<MOCK>>(user);
        value = user_coin.value();
        scenario.return_to_sender(user_coin);
    };
    value
}
