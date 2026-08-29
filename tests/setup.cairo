use etheracts::ethrx::interface::ConstructorArgs;
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::signature::stark_curve::{
    StarkCurveKeyPairImpl, StarkCurveSignerImpl, StarkCurveVerifierImpl,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ClassHash, ContractAddress};
use crate::ethrxV2::InitializerV2Args;
use crate::mock_erc20::{IMintableDispatcher, IMintableDispatcherTrait};
use crate::utils::{EthrxFacade, EthrxFacadeImpl};


/// Consts ///
pub const ALICE: ContractAddress = 'alice'.try_into().unwrap();
pub const BOB: ContractAddress = 'bob'.try_into().unwrap();
pub const BYSTANDER: ContractAddress = 'bystander'.try_into().unwrap();
pub const OWNER: ContractAddress = 'owner'.try_into().unwrap();
pub const MINT_PRICE: u256 = 100_000_000;
pub const MAX_SUPPLY: u256 =
    211; // Must be > 111 to allow minting in tests (111 minted in constructor)
pub fn NAME() -> ByteArray {
    "Etheracts"
}
pub fn SYMBOL() -> ByteArray {
    "Ethrx"
}
pub fn BASE_URI() -> ByteArray {
    "http://novemberfork.io/etheracts/URI/"
}
pub fn CONTRACT_URI() -> ByteArray {
    "https://novemberfork.io/etheracts/URI/contract"
}

/// Utils ///

pub fn mint(token: ContractAddress, to: ContractAddress, amount: u256) {
    let token_dispatcher = IMintableDispatcher { contract_address: token };
    token_dispatcher.mint(to, amount);
}

pub fn approve(
    token: ContractAddress, owner: ContractAddress, spender: ContractAddress, amount: u256,
) {
    let token_dispatcher = IERC20Dispatcher { contract_address: token };
    start_cheat_caller_address(token, owner);
    token_dispatcher.approve(spender, amount);
    stop_cheat_caller_address(token);
}

/// Contract Deployment ///
pub fn deploy_erc20(name: ByteArray, symbol: ByteArray) -> IERC20Dispatcher {
    let mock_erc20_contract = declare("MockERC20").unwrap().contract_class();
    let mut ctor_calldata: Array<felt252> = array![];
    name.serialize(ref ctor_calldata);
    symbol.serialize(ref ctor_calldata);

    let (erc20_address, _) = mock_erc20_contract.deploy(@ctor_calldata).unwrap();

    IERC20Dispatcher { contract_address: erc20_address }
}

pub fn deploy_ethrx(mint_token: ContractAddress) -> ContractAddress {
    let ethrx_contract = declare("Ethrx").unwrap().contract_class();
    let mut ctor_calldata: Array<felt252> = array![];

    let args = ConstructorArgs {
        owner: OWNER,
        name: NAME(),
        symbol: SYMBOL(),
        base_uri: BASE_URI(),
        contract_uri: CONTRACT_URI(),
        mint_token,
        mint_price: MINT_PRICE,
        max_supply: MAX_SUPPLY,
    };

    args.serialize(ref ctor_calldata);

    let (ethrx_address, _) = ethrx_contract.deploy(@ctor_calldata).unwrap();

    ethrx_address
    //IEthrxABIDispatcher { contract_address: ethrx_address }
}

pub fn declare_v2() -> ClassHash {
    let ethrx_contract = declare("EthrxV2").unwrap().contract_class();
    let mut ctor_calldata: Array<felt252> = array![];

    let args = InitializerV2Args { new_feature: 'hello world' };

    args.serialize(ref ctor_calldata);

    *ethrx_contract.class_hash
}


pub fn setup() -> (EthrxFacade, IERC20Dispatcher) {
    let (ethrx, token) = setup_without_enabling_minting();

    // Enable minting for existing tests (to avoid rewriting them)
    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.set_minting(true);
    stop_cheat_caller_address(ethrx.contract_address);

    (ethrx, token)
}

pub fn setup_without_enabling_minting() -> (EthrxFacade, IERC20Dispatcher) {
    let token = deploy_erc20("Mock Token", "NF");
    let ethrx_address = deploy_ethrx(token.contract_address);
    let ethrx = EthrxFacadeImpl::new(ethrx_address);

    // Mint some tokens to ALICE for testing
    mint(token.contract_address, ALICE, 1111 * (ethrx.mint_price() * ethrx.max_supply()));
    mint(token.contract_address, BOB, 1111 * (ethrx.mint_price() * ethrx.max_supply()));
    mint(token.contract_address, BYSTANDER, 1111 * (ethrx.mint_price() * ethrx.max_supply()));

    // Do NOT enable minting - used for testing disabled minting logic
    (ethrx, token)
}
