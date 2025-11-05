module mock_token::mock_tests;

use mock_token::mock;
use sui::test_scenario;

#[test]
fun basic_mint() {
    let admin = @0x1;
    let mut scenario = test_scenario::begin(admin);

    mock::init_for_testing(scenario.ctx());

    scenario.end();
}
