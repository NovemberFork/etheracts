use alexandria_bytes::Bytes;
use core::num::traits::Zero;
use etheracts::ethrx::contract::Ethrx;
use etheracts::ethrx::interface::{
    IEthrxDispatcherTrait, IEthrxSafeDispatcher, IEthrxSafeDispatcherTrait,
};
use etheracts::types::engraving::{Artifact, Engraving, INITIAL_ENGRAVINGS};
use openzeppelin_access::ownable::interface::IOwnableDispatcherTrait;
use openzeppelin_token::erc20::ERC20Component;
use openzeppelin_token::erc20::interface::IERC20DispatcherTrait;
use openzeppelin_token::erc721::ERC721Component;
use openzeppelin_token::erc721::interface::IERC721DispatcherTrait;
use snforge_std::{
    EventSpyAssertionsTrait, EventSpyTrait, spy_events, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use crate::ethrxV2::{IEthrxV2Dispatcher, IEthrxV2DispatcherTrait, InitializerV2Args};
use crate::setup::{
    ALICE, BASE_URI, BOB, BYSTANDER, CONTRACT_URI, MAX_SUPPLY, MINT_PRICE, NAME, OWNER, SYMBOL,
    declare_v2, setup, setup_without_enabling_minting,
};
use crate::utils::{
    EthrxFacade, EthrxFacadeImpl, EthrxFacadeImplV2, EthrxTrait, EthrxV2Facade, EthrxV2Trait,
};

fn upgrade(input: EthrxFacade) -> EthrxV2Facade {
    let class_hash = declare_v2();

    start_cheat_caller_address(input.contract_address, input.owner());
    input.dispatcher.upgrade_contract(class_hash);
    stop_cheat_caller_address(input.contract_address);

    let EthrxFacade {
        dispatcher: dispatcherV1,
        safe_dispatcher: safe_dispatcherV1,
        erc721_metadata,
        erc721,
        erc721_enumerable,
        ownable,
        contract_address,
    } = input;

    let dispatcher = IEthrxV2Dispatcher { contract_address };

    EthrxV2Facade {
        dispatcher,
        dispatcherV1,
        safe_dispatcherV1,
        erc721_metadata,
        erc721,
        erc721_enumerable,
        ownable,
        contract_address,
    }
}

fn upgrade_no_mocking(input: EthrxFacade) -> EthrxV2Facade {
    let class_hash = declare_v2();

    input.dispatcher.upgrade_contract(class_hash);

    let EthrxFacade {
        dispatcher: dispatcherV1,
        safe_dispatcher: safe_dispatcherV1,
        erc721_metadata,
        erc721,
        erc721_enumerable,
        ownable,
        contract_address,
    } = input;

    let dispatcher = IEthrxV2Dispatcher { contract_address };

    EthrxV2Facade {
        dispatcher,
        dispatcherV1,
        safe_dispatcherV1,
        erc721_metadata,
        erc721,
        erc721_enumerable,
        ownable,
        contract_address,
    }
}

fn initializerV2(self: EthrxV2Facade) {
    let args = InitializerV2Args { new_feature: 'hello world' };

    start_cheat_caller_address(self.contract_address, self.ownable.owner());
    self.dispatcher.initializerV2(args);
    stop_cheat_caller_address(self.contract_address);
}

fn initializerV2_no_mocking(self: EthrxV2Facade) {
    let args = InitializerV2Args { new_feature: 'hello world' };

    self.dispatcher.initializerV2(args);
}

#[test]
fn test_ethrx_initializerV2() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);

    let pre = ethrx.dispatcher.get_new_feature();
    initializerV2(ethrx);
    let post = ethrx.dispatcher.get_new_feature();

    assert!(pre == '', "Pre initV2 wrong");
    assert!(post == 'hello world', "Post initV2 wrong");
}

#[test]
#[should_panic]
fn test_ethrx_initializerV2_only_once() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);

    initializerV2(ethrx);
    initializerV2(ethrx);
}

#[test]
#[should_panic]
fn test_ethrx_initializerV2_only_owner() {
    let (ethrx, _) = setup();

    let ethrx = upgrade(ethrx);

    initializerV2_no_mocking(ethrx);
}

#[test]
#[should_panic]
fn test_ethrx_upgrade_only_owner() {
    let (ethrx, _) = setup();

    upgrade_no_mocking(ethrx);
}

#[test]
fn test_new_feature() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    let pre = ethrx.dispatcher.get_new_feature();

    start_cheat_caller_address(ethrx.contract_address, ethrx.ownable.owner());
    ethrx.dispatcher.set_new_feature('asdf');
    stop_cheat_caller_address(ethrx.contract_address);

    let post = ethrx.dispatcher.get_new_feature();

    assert!(pre != post, "before and after wrong");
    assert!(post == 'asdf', "after wrong");
}

#[test]
#[should_panic]
fn test_new_feature_only_owner() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    ethrx.dispatcher.set_new_feature('asdf');
}


#[test]
fn test_ethrx_constructor_args() {
    let (ethrx, erc20) = setup();

    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    assert!(ethrx.owner() == OWNER, "owner mismatch");
    assert!(ethrx.name() == NAME(), "name mismatch");
    assert!(ethrx.symbol() == SYMBOL(), "symbol mismatch");
    assert!(ethrx.token_uri(1) == format!("{}{}", BASE_URI(), 1), "base uri mismatch");
    assert!(ethrx.contract_uri() == CONTRACT_URI(), "contract uri mismatch");
    assert!(ethrx.mint_token() == erc20.contract_address, "mint token mismatch");
    assert!(ethrx.mint_price() == MINT_PRICE, "mint price mismatch");
    assert!(ethrx.max_supply() == MAX_SUPPLY, "max supply mismatch");
}

#[test]
fn test_ethrx_constructor() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    assert!(ethrx.total_supply() == 111, "initial total supply should be 111");

    // Verify all tokens 1-111 are owned by OWNER
    for i in 1..=111_usize {
        assert!(ethrx.owner_of(i.into()) == OWNER, "token {i} should be owned by OWNER");
    }

    // Verify tokens 1-11 have initial engravings
    for i in 1..=11_usize {
        assert!(
            ethrx.get_artifact(i.into()) == INITIAL_ENGRAVINGS::INITIAL_ARTIFACT(i.into()),
            "token {i} should have initial artifact",
        );
    }

    // Verify tokens 12-111 are unengraved (all tags should be empty)
    for i in 12..=111_usize {
        let artifact = ethrx.get_artifact(i.into());
        assert!(artifact.collection.len() == 5, "token {i} should have all 5 official tags");

        // All engravings should have empty data
        for engraving in artifact.collection {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(
                data_ba == "", "token {i} tag {} should be empty (not engraved)", engraving.tag,
            );
        }
    }
}

#[test]
fn test_constructor_enumerable_state() {
    let (ethrx, _) = setup();

    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Verify total supply
    assert!(ethrx.total_supply() == 111, "total supply should be 111");

    // Verify all tokens are enumerable via token_by_index
    for i in 0..111_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
    }

    // Verify OWNER has all 111 tokens via token_of_owner_by_index
    assert!(ethrx.balance_of(OWNER) == 111, "OWNER should have 111 tokens");
    for i in 0..111_usize {
        let token_id = ethrx.token_of_owner_by_index(OWNER, i);
        assert!(token_id == (i + 1).into(), "OWNER's token at index {i} should be {}", i + 1);
    }
}

#[test]
fn test_constructor_engraved_tokens_details() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Verify tokens 1-11 have proper engravings with non-empty data
    for i in 1..=11_usize {
        let artifact = ethrx.get_artifact(i.into());
        let expected_artifact = INITIAL_ENGRAVINGS::INITIAL_ARTIFACT(i.into());

        // Verify artifact structure matches
        assert!(
            artifact.collection.len() == expected_artifact.collection.len(),
            "token {i} should have correct number of engravings",
        );

        // Verify each engraving matches
        for (engraving, expected_engraving) in artifact
            .collection
            .into_iter()
            .zip(expected_artifact.collection) {
            assert!(
                engraving.tag == expected_engraving.tag,
                "token {i} should have tag {}",
                expected_engraving.tag,
            );
            let data_ba: ByteArray = engraving.data.clone().into();
            let expected_data_ba: ByteArray = expected_engraving.data.clone().into();
            assert!(
                data_ba == expected_data_ba,
                "token {i} tag {} should match expected data",
                engraving.tag,
            );
        }
    }
}


/// Test Helpers ///

#[test]
fn test_mint() {
    let (ethrx, erc20) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    let owner_balance_before = erc20.balance_of(OWNER);
    let alice_balance_before = erc20.balance_of(ALICE);
    let bystander_balance_before = erc20.balance_of(BYSTANDER);

    // Mint 1 token to Alice on behalf of Bystander
    let mut spy = spy_events();
    start_cheat_caller_address(erc20.contract_address, BYSTANDER);
    ethrx.mint_star(ALICE);
    stop_cheat_caller_address(erc20.contract_address);

    let owner_balance_after = erc20.balance_of(OWNER);
    let alice_balance_after = erc20.balance_of(ALICE);
    let bystander_balance_after = erc20.balance_of(BYSTANDER);

    assert!(ethrx.total_supply() == 112, "total supply should be 112 after minting 1 token");
    assert!(ethrx.owner_of(112) == ALICE, "newly minted token owner should be Alice");
    assert!(
        owner_balance_after == owner_balance_before + MINT_PRICE,
        "owner should receive the mint price",
    );
    assert!(
        bystander_balance_after == bystander_balance_before - MINT_PRICE,
        "Bystander's balance should decrease by the mint price",
    );
    assert!(alice_balance_after == alice_balance_before, "Alice's balance should remain unchanged");

    // Assert erc20 event
    spy
        .assert_emitted(
            @array![
                (
                    erc20.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer { from: BYSTANDER, to: OWNER, value: MINT_PRICE },
                    ),
                ),
            ],
        );
    // Assert erc721 event
    spy
        .assert_emitted(
            @array![
                (
                    ethrx.contract_address,
                    ERC721Component::Event::Transfer(
                        ERC721Component::Transfer { from: Zero::zero(), to: ALICE, token_id: 112 },
                    ),
                ),
            ],
        );
}

#[test]
fn test_mint_batch() {
    let (ethrx, erc20) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    let owner_balance_before = erc20.balance_of(OWNER);
    let alice_balance_before = erc20.balance_of(ALICE);
    let bob_balance_before = erc20.balance_of(BOB);
    let bystander_balance_before = erc20.balance_of(BYSTANDER);

    let tos = array![ALICE, BOB];
    let amounts = array![2, 3];

    let mut spy = spy_events();
    ethrx.mint_batch_star(tos, amounts);

    let owner_balance_after = erc20.balance_of(OWNER);
    let alice_balance_after = erc20.balance_of(ALICE);
    let bob_balance_after = erc20.balance_of(BOB);
    let bystander_balance_after = erc20.balance_of(BYSTANDER);

    assert!(ethrx.total_supply() == 116, "total supply should be 116 after minting 5 tokens");
    for i in 112..=113_u256 {
        assert!(ethrx.owner_of(i) == ALICE, "token {i} owner should be Alice");
    }
    for i in 114..=116_u256 {
        assert!(ethrx.owner_of(i) == BOB, "token {i} owner should be Bob");
    }
    assert!(
        owner_balance_after == owner_balance_before + MINT_PRICE * 5,
        "owner should receive the mint price for 5 tokens",
    );
    assert!(
        bystander_balance_after == bystander_balance_before - MINT_PRICE * 5,
        "Alice's balance should decrease by the mint price for 3 tokens",
    );
    assert!(alice_balance_after == alice_balance_before, "Alice's balance should remain unchanged");
    assert!(bob_balance_after == bob_balance_before, "Bob's balance should remain unchanged");

    // Assert erc20 event
    spy
        .assert_emitted(
            @array![
                (
                    erc20.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: BYSTANDER, to: OWNER, value: MINT_PRICE * 2,
                        },
                    ),
                ),
                (
                    erc20.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: BYSTANDER, to: OWNER, value: MINT_PRICE * 3,
                        },
                    ),
                ),
            ],
        );
    // Assert erc721 events
    spy
        .assert_emitted(
            @array![
                (
                    ethrx.contract_address,
                    ERC721Component::Event::Transfer(
                        ERC721Component::Transfer { from: Zero::zero(), to: ALICE, token_id: 112 },
                    ),
                ),
                (
                    ethrx.contract_address,
                    ERC721Component::Event::Transfer(
                        ERC721Component::Transfer { from: Zero::zero(), to: ALICE, token_id: 113 },
                    ),
                ),
                (
                    ethrx.contract_address,
                    ERC721Component::Event::Transfer(
                        ERC721Component::Transfer { from: Zero::zero(), to: BOB, token_id: 114 },
                    ),
                ),
                (
                    ethrx.contract_address,
                    ERC721Component::Event::Transfer(
                        ERC721Component::Transfer { from: Zero::zero(), to: BOB, token_id: 115 },
                    ),
                ),
                (
                    ethrx.contract_address,
                    ERC721Component::Event::Transfer(
                        ERC721Component::Transfer { from: Zero::zero(), to: BOB, token_id: 116 },
                    ),
                ),
            ],
        );
}

#[test]
fn test_mint_over_supply() {
    let (ethrx, erc20) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    let total_supply_before = ethrx.total_supply();
    let owner_balance_before = erc20.balance_of(OWNER);
    let bystander_balance_before = erc20.balance_of(BYSTANDER);

    // Mint more than max supply (as bystander)
    let mut spy = spy_events();
    ethrx.mint_batch_star(array![ALICE, BOB], array![ethrx.max_supply(), ethrx.max_supply()]);

    let total_supply_after = ethrx.total_supply();
    let owner_balance_after = erc20.balance_of(OWNER);
    let bystander_balance_after = erc20.balance_of(BYSTANDER);

    assert!(
        total_supply_after == ethrx.max_supply(),
        "total supply should only increase up to max supply",
    );

    assert!(
        owner_balance_after == owner_balance_before
            + MINT_PRICE * (ethrx.max_supply() - total_supply_before),
        "owner should receive the mint price only for tokens minted up to max supply",
    );

    assert!(
        bystander_balance_after == bystander_balance_before
            - MINT_PRICE * (ethrx.max_supply() - total_supply_before),
        "Bystander's balance should decrease only by the mint price for tokens minted up to max supply",
    );

    spy
        .assert_emitted(
            @array![
                (
                    erc20.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: BYSTANDER,
                            to: OWNER,
                            value: MINT_PRICE * (ethrx.max_supply() - total_supply_before),
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[feature("safe_dispatcher")]
fn test_minting_no_allownace_or_funds() {
    let (ethrx, erc20) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    let ethrx = IEthrxSafeDispatcher { contract_address: ethrx.contract_address };

    // No allowance
    start_cheat_caller_address(ethrx.contract_address, BYSTANDER);
    let result = ethrx.mint(array![1, 2], array![ALICE, BOB]);
    assert!(result.is_err(), "minting without allowance should fail");
    assert!(
        *result.unwrap_err().at(0) == 'ERC20: insufficient allowance', "error message mismatch",
    );
    stop_cheat_caller_address(ethrx.contract_address);

    // No funds
    start_cheat_caller_address(erc20.contract_address, BYSTANDER);
    erc20.transfer(ALICE, erc20.balance_of(BYSTANDER)); // empty BYSTANDER's balance
    erc20.approve(ethrx.contract_address, MINT_PRICE * 10); // set allowance
    stop_cheat_caller_address(erc20.contract_address);

    start_cheat_caller_address(ethrx.contract_address, BYSTANDER);
    let result = ethrx.mint(array![1, 2], array![ALICE, BOB]);
    assert!(result.is_err(), "minting without funds should fail");
    assert!(*result.unwrap_err().at(0) == 'ERC20: insufficient balance', "error message mismatch");
}

fn build_engraving(tag: felt252, data: ByteArray) -> Engraving {
    Engraving { tag, data: data.to_bytes() }
}

#[test]
fn test_engraving() {
    let (ethrx, _) = setup();
    let new_artifact = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "a"), ethrx.build_engraving('MESSAGE', "b"),
            ethrx.build_engraving('URL', "x"), ethrx.build_engraving('X_HANDLE', "c"),
            ethrx.build_engraving('GITHUB_HANDLE', "d"),
        ],
    };
    ethrx.mint_star(ALICE);
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    let mut spy = spy_events();
    ethrx.engrave_star(112, new_artifact.clone());

    let artifact_id = ethrx.token_id_to_artifact_id(112);
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'TITLE') == 1, "TITLE nonce should be 1");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'MESSAGE') == 1, "MESSAGE nonce should be 1");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'URL') == 1, "URL nonce should be 1");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'X_HANDLE') == 1, "X_HANDLE nonce should be 1");
    assert!(
        ethrx.artifact_tag_nonce(artifact_id, 'GITHUB_HANDLE') == 1,
        "GITHUB_HANDLE nonce should be 1",
    );
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'RANDOM') == 0, "RANDOM nonce should be 0");
    assert!(ethrx.get_artifact(112) == new_artifact, "artifact data mismatch");
    // Assert engraving events
    spy
        .assert_emitted(
            @array![
                (
                    ethrx.contract_address,
                    Ethrx::Event::ArtifactEngraved(
                        Ethrx::ArtifactEngraved {
                            token_id: 112,
                            artifact_id,
                            tag: 'X_HANDLE',
                            nonce: 1,
                            new_data: ethrx.build_engraving('X_HANDLE', "c").data,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_engraving_wipe() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);
    ethrx.mint_star(ALICE);

    let new_artifact = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "a"), ethrx.build_engraving('MESSAGE', "b"),
            ethrx.build_engraving('URL', "x"), ethrx.build_engraving('X_HANDLE', "c"),
            ethrx.build_engraving('GITHUB_HANDLE', "d"),
        ],
    };

    ethrx.engrave_star(112, new_artifact.clone());
    assert!(ethrx.token_id_to_artifact_id(112).into() == 112, "token artifact id should be 112");

    ethrx.transfer_star(ALICE, BOB, 112);
    assert!(
        ethrx.token_id_to_artifact_id(112).into() == 113,
        "token artifact id should be set to 113 after transfer",
    );

    let artifact_id = ethrx.token_id_to_artifact_id(112);
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'TITLE') == 0, "TITLE nonce should be 0");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'MESSAGE') == 0, "MESSAGE nonce should be 0");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'URL') == 0, "URL nonce should be 0");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'X_HANDLE') == 0, "X_HANDLE nonce should be 0");
    assert!(
        ethrx.artifact_tag_nonce(artifact_id, 'GITHUB_HANDLE') == 0,
        "GITHUB_HANDLE nonce should be 0",
    );
    assert!(
        ethrx.artifact_tag_nonce(artifact_id, 'RANDOM') == 0, "RANDOM nonce should
        be 0",
    );
    let empty_artifact = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', ""), ethrx.build_engraving('MESSAGE', ""),
            ethrx.build_engraving('URL', ""), ethrx.build_engraving('X_HANDLE', ""),
            ethrx.build_engraving('GITHUB_HANDLE', ""),
        ],
    };
    assert!(ethrx.get_artifact(112) == empty_artifact, "engraving data mismatch");
}

#[test]
fn test_engraving_keep() {
    let (ethrx, _) = setup();
    ethrx.mint_star(ALICE);

    let new_artifact = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "a"), ethrx.build_engraving('MESSAGE', "b"),
            ethrx.build_engraving('URL', "x"), ethrx.build_engraving('X_HANDLE', "c"),
            ethrx.build_engraving('GITHUB_HANDLE', "d"),
        ],
    };

    ethrx.engrave_star(112, new_artifact.clone());

    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    ethrx.transfer_with_engraving_star(ALICE, BOB, 112);

    let artifact_id = ethrx.token_id_to_artifact_id(112);
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'TITLE') == 1, "TITLE nonce should be 1");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'MESSAGE') == 1, "MESSAGE nonce should be 1");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'URL') == 1, "URL nonce should be 1");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'X_HANDLE') == 1, "X_HANDLE nonce should be 1");
    assert!(
        ethrx.artifact_tag_nonce(artifact_id, 'GITHUB_HANDLE') == 1,
        "GITHUB_HANDLE nonce should be 1",
    );
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'RANDOM') == 0, "RANDOM nonce should be 0");
    assert!(ethrx.get_artifact(112) == new_artifact, "engraving data mismatch");
}

#[test]
fn test_engrave_noop_skips_event_and_nonce() {
    let (ethrx, _) = setup();
    ethrx.mint_star(ALICE);
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    let artifact = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "same"), ethrx.build_engraving('MESSAGE', "same"),
        ],
    };
    ethrx.engrave_star(112, artifact.clone());
    let artifact_id = ethrx.token_id_to_artifact_id(112);
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'TITLE') == 1, "TITLE nonce should be 1");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'MESSAGE') == 1, "MESSAGE nonce should be 1");

    let mut spy = spy_events();
    ethrx.engrave_star(112, artifact.clone());

    assert!(ethrx.artifact_tag_nonce(artifact_id, 'TITLE') == 1, "TITLE nonce should stay 1");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'MESSAGE') == 1, "MESSAGE nonce should stay 1");
    assert!(ethrx.get_artifact(112).collection.len() >= 2, "artifact should still be readable");
    assert!(spy.get_events().events.len() == 0, "no-op engrave must not emit");
}

#[test]
fn test_engrave_mixed_batch_only_changed_emits() {
    let (ethrx, _) = setup();
    ethrx.mint_star(ALICE);
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    ethrx
        .engrave_star(
            112,
            Artifact {
                collection: array![
                    ethrx.build_engraving('TITLE', "keep"), ethrx.build_engraving('MESSAGE', "old"),
                ],
            },
        );
    let artifact_id = ethrx.token_id_to_artifact_id(112);

    let mut spy = spy_events();
    ethrx
        .engrave_star(
            112,
            Artifact {
                collection: array![
                    ethrx.build_engraving('TITLE', "keep"), ethrx.build_engraving('MESSAGE', "new"),
                ],
            },
        );

    assert!(ethrx.artifact_tag_nonce(artifact_id, 'TITLE') == 1, "unchanged TITLE nonce stays 1");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'MESSAGE') == 2, "changed MESSAGE nonce bumps");
    spy
        .assert_emitted(
            @array![
                (
                    ethrx.contract_address,
                    Ethrx::Event::ArtifactEngraved(
                        Ethrx::ArtifactEngraved {
                            token_id: 112,
                            artifact_id,
                            tag: 'MESSAGE',
                            nonce: 2,
                            new_data: ethrx.build_engraving('MESSAGE', "new").data,
                        },
                    ),
                ),
            ],
        );
    spy
        .assert_not_emitted(
            @array![
                (
                    ethrx.contract_address,
                    Ethrx::Event::ArtifactEngraved(
                        Ethrx::ArtifactEngraved {
                            token_id: 112,
                            artifact_id,
                            tag: 'TITLE',
                            nonce: 1,
                            new_data: ethrx.build_engraving('TITLE', "keep").data,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_set_tags_noop_skips_reregistered() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);
    let tags_before = ethrx.official_tags();

    let mut spy = spy_events();
    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.set_tags(Option::Some(array![(1_usize, 'TITLE')]), Option::None);
    stop_cheat_caller_address(ethrx.contract_address);

    assert!(ethrx.official_tags() == tags_before, "official tags should be unchanged");
    assert!(spy.get_events().events.len() == 0, "no-op tag rewrite must not emit");
}

#[test]
fn test_set_tags_mixed_modify_only_changed_emits() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    let mut spy = spy_events();
    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.set_tags(Option::Some(array![(1_usize, 'TITLE'), (2_usize, 'BIO')]), Option::None);
    stop_cheat_caller_address(ethrx.contract_address);

    let tags = ethrx.official_tags();
    assert!(*tags.at(0) == 'TITLE', "index 1 TITLE unchanged");
    assert!(*tags.at(1) == 'BIO', "index 2 MESSAGE -> BIO");
    spy
        .assert_emitted(
            @array![
                (
                    ethrx.contract_address,
                    Ethrx::Event::TagReregistered(
                        Ethrx::TagReregistered { index: 2, old_tag: 'MESSAGE', new_tag: 'BIO' },
                    ),
                ),
            ],
        );
    spy
        .assert_not_emitted(
            @array![
                (
                    ethrx.contract_address,
                    Ethrx::Event::TagReregistered(
                        Ethrx::TagReregistered { index: 1, old_tag: 'TITLE', new_tag: 'TITLE' },
                    ),
                ),
            ],
        );
}

fn bytes_array_builder(strings: Array<ByteArray>) -> Array<Bytes> {
    strings.into_iter().map(|s| Into::<ByteArray, Bytes>::into(s)).collect()
}

trait ToBytes<T> {
    fn to_bytes(self: T) -> Bytes;
}


impl BAToBytesImpl of ToBytes<ByteArray> {
    fn to_bytes(self: ByteArray) -> Bytes {
        Into::<ByteArray, Bytes>::into(self)
    }
}

#[test]
fn test_set_contract_uri_owner() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    let new_contract_uri = "https://example.com/new-contract";
    let initial_contract_uri = ethrx.contract_uri();

    // Owner should be able to set contract URI
    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.set_contract_uri(new_contract_uri.clone());
    stop_cheat_caller_address(ethrx.contract_address);

    assert!(ethrx.contract_uri() == new_contract_uri, "contract URI should be updated");
    assert!(
        ethrx.contract_uri() != initial_contract_uri,
        "contract URI should be different from initial value",
    );
}

#[test]
#[should_panic]
fn test_set_contract_uri_non_owner() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    let new_contract_uri = "https://example.com/new-contract.json";

    // Non-owner should not be able to set contract URI - should panic
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.set_contract_uri(new_contract_uri);
    stop_cheat_caller_address(ethrx.contract_address);
}

/// ERC721Enumerable Tests ///

#[test]
fn test_enumerable_initial_state() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // After constructor, 111 tokens should be minted to OWNER
    assert!(ethrx.total_supply() == 111, "initial total supply should be 111");
    assert!(ethrx.balance_of(OWNER) == 111, "OWNER should have 111 tokens initially");

    // Test token_by_index for all initial tokens
    for i in 0..111_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
        assert!(ethrx.owner_of(token_id) == OWNER, "token {token_id} should be owned by OWNER");
    }

    // Test token_of_owner_by_index for OWNER
    for i in 0..111_usize {
        let token_id = ethrx.token_of_owner_by_index(OWNER, i);
        assert!(
            token_id == (i + 1).into(),
            "token_of_owner_by_index(OWNER, {i}) should return {}",
            i + 1,
        );
    }
}

#[test]
fn test_enumerable_after_mint() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint tokens to ALICE and BOB
    ethrx.mint_batch_star(array![ALICE, BOB], array![2, 3]);

    assert!(ethrx.total_supply() == 116, "total supply should be 116 after minting 5 tokens");
    assert!(ethrx.balance_of(ALICE) == 2, "ALICE should have 2 tokens");
    assert!(ethrx.balance_of(BOB) == 3, "BOB should have 3 tokens");
    assert!(ethrx.balance_of(OWNER) == 111, "OWNER should still have 111 tokens");

    // Test token_by_index for all tokens (should be 1-116)
    for i in 0..116_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
    }

    // Test token_of_owner_by_index for ALICE (tokens 112, 113)
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 112, "ALICE's first token should be 112");
    assert!(ethrx.token_of_owner_by_index(ALICE, 1) == 113, "ALICE's second token should be 113");

    // Test token_of_owner_by_index for BOB (tokens 114, 115, 116)
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 114, "BOB's first token should be 114");
    assert!(ethrx.token_of_owner_by_index(BOB, 1) == 115, "BOB's second token should be 115");
    assert!(ethrx.token_of_owner_by_index(BOB, 2) == 116, "BOB's third token should be 116");

    // Test token_of_owner_by_index for OWNER (tokens 1-11)
    for i in 0..11_usize {
        let token_id = ethrx.token_of_owner_by_index(OWNER, i);
        assert!(token_id == (i + 1).into(), "OWNER's token at index {i} should be {}", i + 1);
    }
}

#[test]
fn test_enumerable_after_transfer() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint a token to ALICE
    ethrx.mint_star(ALICE);
    assert!(ethrx.balance_of(ALICE) == 1, "ALICE should have 1 token");
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 112, "ALICE's token should be 112");

    // Transfer token 112 from ALICE to BOB
    ethrx.transfer_star(ALICE, BOB, 112);

    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens after transfer");
    assert!(ethrx.balance_of(BOB) == 1, "BOB should have 1 token after transfer");
    assert!(ethrx.owner_of(112) == BOB, "token 112 should be owned by BOB");

    // ALICE should have no tokens
    // BOB should have token 112 at index 0
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 112, "BOB's first token should be 112");

    // token_by_index should still work correctly
    assert!(ethrx.token_by_index(111) == 112, "token_by_index(111) should return 112");
}

#[test]
fn test_enumerable_multiple_transfers() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![5]);
    assert!(ethrx.balance_of(ALICE) == 5, "ALICE should have 5 tokens");

    // Transfer tokens 112, 113, 114 from ALICE to BOB
    ethrx.transfer_star(ALICE, BOB, 112);
    ethrx.transfer_star(ALICE, BOB, 113);
    ethrx.transfer_star(ALICE, BOB, 114);

    assert!(ethrx.balance_of(ALICE) == 2, "ALICE should have 2 tokens after transfers");
    assert!(ethrx.balance_of(BOB) == 3, "BOB should have 3 tokens after transfers");

    // ALICE should have tokens 115, 116 (pop and swapped so order looks weird)
    assert!(
        ethrx.token_of_owner_by_index(ALICE, 0) == 116,
        "ALICE's first token should be 115 but is {}",
        ethrx.token_of_owner_by_index(ALICE, 0),
    );
    assert!(ethrx.token_of_owner_by_index(ALICE, 1) == 115, "ALICE's second token should be 116");

    // BOB should have tokens 112, 113, 114
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 112, "BOB's first token should be 112");
    assert!(ethrx.token_of_owner_by_index(BOB, 1) == 113, "BOB's second token should be 113");
    assert!(ethrx.token_of_owner_by_index(BOB, 2) == 114, "BOB's third token should be 114");
}

#[test]
fn test_enumerable_transfer_back() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint token to ALICE
    ethrx.mint_star(ALICE);
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 112, "ALICE should have token 112");

    // Transfer from ALICE to BOB
    ethrx.transfer_star(ALICE, BOB, 112);
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens");
    assert!(ethrx.balance_of(BOB) == 1, "BOB should have 1 token");
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 112, "BOB should have token 112");

    // Transfer back from BOB to ALICE
    ethrx.transfer_star(BOB, ALICE, 112);
    assert!(ethrx.balance_of(ALICE) == 1, "ALICE should have 1 token");
    assert!(ethrx.balance_of(BOB) == 0, "BOB should have 0 tokens");
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 112, "ALICE should have token 112 again");
}

#[test]
#[should_panic]
fn test_enumerable_token_by_index_out_of_bounds() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Should panic when accessing index beyond total_supply
    let total = ethrx.total_supply();
    ethrx.token_by_index(total.try_into().unwrap());
}

#[test]
#[should_panic]
fn test_enumerable_token_of_owner_by_index_out_of_bounds() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // ALICE has no tokens initially, should panic
    ethrx.token_of_owner_by_index(ALICE, 0);
}

#[test]
#[should_panic]
fn test_enumerable_token_of_owner_by_index_out_of_bounds_after_transfer() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint token to ALICE
    ethrx.mint_star(ALICE);
    assert!(ethrx.balance_of(ALICE) == 1, "ALICE should have 1 token");

    // Transfer token away
    ethrx.transfer_star(ALICE, BOB, 112);
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens");

    // Should panic when accessing ALICE's tokens
    ethrx.token_of_owner_by_index(ALICE, 0);
}

#[test]
fn test_enumerable_consistency_after_batch_mint() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint multiple tokens to different owners
    ethrx.mint_batch_star(array![ALICE, BOB, ALICE], array![3, 2, 1]);

    assert!(ethrx.total_supply() == 117, "total supply should be 117");
    assert!(ethrx.balance_of(ALICE) == 4, "ALICE should have 4 tokens");
    assert!(ethrx.balance_of(BOB) == 2, "BOB should have 2 tokens");

    // Verify all tokens are enumerable
    for i in 0..117_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
    }

    // ALICE receives tokens in order: 112, 113, 114, then 117
    // So ALICE should have [112, 113, 114, 117] in that order (no transfers yet)
    let alice_tokens = array![112, 113, 114, 117];
    for i in 0..4_usize {
        let token_id = ethrx.token_of_owner_by_index(ALICE, i);
        assert!(
            token_id == (*alice_tokens.at(i.into())).into(),
            "ALICE's token at index {i} should be {}",
            *alice_tokens.at(i),
        );
    }

    // Verify BOB's tokens (115, 116)
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 115, "BOB's first token should be 115");
    assert!(ethrx.token_of_owner_by_index(BOB, 1) == 116, "BOB's second token should be 116");
}

#[test]
fn test_enumerable_with_transfer_and_save_artifact() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint multiple tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![5]);
    assert!(ethrx.balance_of(ALICE) == 5, "ALICE should have 5 tokens");
    assert!(ethrx.total_supply() == 116, "total supply should be 116");

    // Verify ALICE's tokens before transfer (112, 113, 114, 115, 116)
    for i in 0..5_usize {
        let token_id = ethrx.token_of_owner_by_index(ALICE, i);
        assert!(token_id == (112 + i).into(), "ALICE's token at index {i} should be {}", 112 + i);
    }

    // Transfer tokens 112, 113, 114 with artifact saving
    ethrx.transfer_with_engraving_star(ALICE, BOB, 112);
    ethrx.transfer_with_engraving_star(ALICE, BOB, 113);
    ethrx.transfer_with_engraving_star(ALICE, BOB, 114);

    // Verify balances after transfer
    assert!(ethrx.balance_of(ALICE) == 2, "ALICE should have 2 tokens after transfer");
    assert!(ethrx.balance_of(BOB) == 3, "BOB should have 3 tokens after transfer");
    assert!(ethrx.total_supply() == 116, "total supply should remain 116");

    // ALICE originally had [112, 113, 114, 115, 116]
    // Transfer 112 (index 0): swap with 116 → [116, 113, 114, 115]
    // Transfer 113 (index 1): swap with 115 → [116, 115, 114]
    // Transfer 114 (index 2): swap with 114 (last) → [116, 115]
    // So ALICE should have [116, 115] in that order
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 116, "ALICE's first token should be 116");
    assert!(ethrx.token_of_owner_by_index(ALICE, 1) == 115, "ALICE's second token should be 115");

    // BOB receives tokens in order: [112, 113, 114]
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 112, "BOB's first token should be 112");
    assert!(ethrx.token_of_owner_by_index(BOB, 1) == 113, "BOB's second token should be 113");
    assert!(ethrx.token_of_owner_by_index(BOB, 2) == 114, "BOB's third token should be 114");

    // Verify token_by_index still works correctly for all tokens
    for i in 0..116_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
    }

    // Verify owners are correct
    assert!(ethrx.owner_of(112) == BOB, "token 112 should be owned by BOB");
    assert!(ethrx.owner_of(113) == BOB, "token 113 should be owned by BOB");
    assert!(ethrx.owner_of(114) == BOB, "token 114 should be owned by BOB");
    assert!(ethrx.owner_of(115) == ALICE, "token 115 should be owned by ALICE");
    assert!(ethrx.owner_of(116) == ALICE, "token 116 should be owned by ALICE");
}

#[test]
fn test_enumerable_batch_transfer_and_save_artifact() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint tokens to ALICE and BOB
    ethrx.mint_batch_star(array![ALICE, BOB], array![4, 3]);
    assert!(ethrx.total_supply() == 118, "total supply should be 118");
    assert!(ethrx.balance_of(ALICE) == 4, "ALICE should have 4 tokens");
    assert!(ethrx.balance_of(BOB) == 3, "BOB should have 3 tokens");

    // Transfer multiple tokens from ALICE to BOB using batch transfer_and_save_artifact
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.transfer_batch_with_engraving(array![ALICE, ALICE], array![BOB, BOB], array![112, 113]);
    stop_cheat_caller_address(ethrx.contract_address);

    // Verify enumerable state after batch transfer
    assert!(ethrx.balance_of(ALICE) == 2, "ALICE should have 2 tokens after batch transfer");
    assert!(ethrx.balance_of(BOB) == 5, "BOB should have 5 tokens after batch transfer");
    assert!(ethrx.total_supply() == 118, "total supply should remain 118");

    // ALICE originally had [112, 113, 114, 115]
    // Transfer 112 (index 0): swap with 115 → [115, 113, 114]
    // Transfer 113 (index 1): swap with 114 → [115, 114]
    // So ALICE should have [115, 114] in that order
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 115, "ALICE's first token should be 115");
    assert!(ethrx.token_of_owner_by_index(ALICE, 1) == 114, "ALICE's second token should be 114");

    // BOB originally had [116, 117, 118], then receives 112, 113 in order
    // So BOB should have [116, 117, 118, 112, 113] in that order
    let bob_tokens = array![116, 117, 118, 112, 113];
    for i in 0..5_usize {
        let token_id = ethrx.token_of_owner_by_index(BOB, i);
        assert!(
            token_id == (*bob_tokens.at(i)).into(),
            "BOB's token at index {i} should be {}",
            *bob_tokens.at(i),
        );
    }

    // Verify all tokens are still enumerable via token_by_index
    for i in 0..118_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
    }
}

#[test]
fn test_enumerable_transfer_and_save_artifact_with_engravings() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint token to ALICE
    ethrx.mint_star(ALICE);
    assert!(ethrx.balance_of(ALICE) == 1, "ALICE should have 1 token");

    // Engrave the token with only some tags (partial engraving)
    // This tests the edge case where not all official tags are engraved
    let partial_artifact = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "Test Title"),
            ethrx.build_engraving('MESSAGE', "Test Message"),
        ],
    };
    ethrx.engrave_star(112, partial_artifact);

    // Verify artifact exists before transfer
    // get_artifacts returns all 5 official tags, but unengraved ones should have empty data
    let retrieved_artifact = ethrx.get_artifact(112);

    // Verify all 5 official tags are present
    assert!(retrieved_artifact.collection.len() == 5, "should return all 5 official tags");

    // Verify engraved tags have correct data
    let mut found_title = false;
    let mut found_message = false;
    let mut found_url = false;
    let mut found_x_handle = false;
    let mut found_github_handle = false;

    for engraving in retrieved_artifact.collection {
        if engraving.tag == 'TITLE' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "Test Title", "TITLE should be 'Test Title'");
            found_title = true;
        } else if engraving.tag == 'MESSAGE' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "Test Message", "MESSAGE should be 'Test Message'");
            found_message = true;
        } else if engraving.tag == 'URL' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "", "URL should be empty string (not engraved)");
            found_url = true;
        } else if engraving.tag == 'X_HANDLE' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "", "X_HANDLE should be empty string (not engraved)");
            found_x_handle = true;
        } else if engraving.tag == 'GITHUB_HANDLE' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "", "GITHUB_HANDLE should be empty string (not engraved)");
            found_github_handle = true;
        }
    }

    assert!(found_title, "TITLE tag should be present");
    assert!(found_message, "MESSAGE tag should be present");
    assert!(found_url, "URL tag should be present");
    assert!(found_x_handle, "X_HANDLE tag should be present");
    assert!(found_github_handle, "GITHUB_HANDLE tag should be present");

    // Transfer with artifact saving
    ethrx.transfer_with_engraving_star(ALICE, BOB, 112);

    // Verify enumerable state
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens");
    assert!(ethrx.balance_of(BOB) == 1, "BOB should have 1 token");
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 112, "BOB should have token 112");
    assert!(ethrx.token_by_index(111) == 112, "token_by_index(111) should return 112");

    // Verify artifact is preserved after transfer
    // All tags should still be present, with engraved ones having data and unengraved ones empty
    let retrieved_artifact_after = ethrx.get_artifact(112);
    assert!(
        retrieved_artifact_after.collection.len() == 5,
        "should still return all 5 official tags after transfer",
    );

    // Verify engraved tags are still preserved
    let mut found_title_after = false;
    let mut found_message_after = false;
    let mut found_empty_tags_after = 0;

    for engraving in retrieved_artifact_after.collection {
        if engraving.tag == 'TITLE' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "Test Title", "TITLE should be preserved after transfer");
            found_title_after = true;
        } else if engraving.tag == 'MESSAGE' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "Test Message", "MESSAGE should be preserved after transfer");
            found_message_after = true;
        } else if engraving.tag == 'URL'
            || engraving.tag == 'X_HANDLE'
            || engraving.tag == 'GITHUB_HANDLE' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "", "Unengraved tag should remain empty after transfer");
            found_empty_tags_after += 1;
        }
    }

    assert!(found_title_after, "TITLE should be preserved after transfer");
    assert!(found_message_after, "MESSAGE should be preserved after transfer");
    assert!(found_empty_tags_after == 3, "All 3 unengraved tags should remain empty");
}

#[test]
fn test_enumerable_transfer_and_save_artifact_partial_engravings() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint token to ALICE
    ethrx.mint_star(ALICE);
    assert!(ethrx.balance_of(ALICE) == 1, "ALICE should have 1 token");

    // Engrave only TITLE and MESSAGE (partial engraving)
    let partial_artifact = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "Partial Title"),
            ethrx.build_engraving('MESSAGE', "Partial Message"),
        ],
    };
    ethrx.engrave_star(112, partial_artifact);

    // get_artifacts returns all official tags, so unengraved tags will have empty data
    let retrieved = ethrx.get_artifact(112);
    // Verify that TITLE and MESSAGE are set
    let mut found_title = false;
    let mut found_message = false;
    for engraving in retrieved.collection {
        if engraving.tag == 'TITLE' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "Partial Title", "TITLE should be preserved");
            found_title = true;
        }
        if engraving.tag == 'MESSAGE' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "Partial Message", "MESSAGE should be preserved");
            found_message = true;
        }
    }
    assert!(found_title, "TITLE should be in artifact");
    assert!(found_message, "MESSAGE should be in artifact");

    // Transfer with artifact saving
    ethrx.transfer_with_engraving_star(ALICE, BOB, 112);

    // Verify enumerable state
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens");
    assert!(ethrx.balance_of(BOB) == 1, "BOB should have 1 token");

    // Verify artifact is preserved after transfer
    let retrieved_after = ethrx.get_artifact(112);
    let mut found_title_after = false;
    let mut found_message_after = false;
    for engraving in retrieved_after.collection {
        if engraving.tag == 'TITLE' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "Partial Title", "TITLE should be preserved after transfer");
            found_title_after = true;
        }
        if engraving.tag == 'MESSAGE' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "Partial Message", "MESSAGE should be preserved after transfer");
            found_message_after = true;
        }
    }
    assert!(found_title_after, "TITLE should be in artifact after transfer");
    assert!(found_message_after, "MESSAGE should be in artifact after transfer");
}

#[test]
fn test_enumerable_transfer_and_save_artifact_with_full_engravings() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint token to ALICE
    ethrx.mint_star(ALICE);
    assert!(ethrx.balance_of(ALICE) == 1, "ALICE should have 1 token");

    // Engrave with all official tags
    let full_artifact = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "Full Title"),
            ethrx.build_engraving('MESSAGE', "Full Message"),
            ethrx.build_engraving('URL', "https://example.com"),
            ethrx.build_engraving('X_HANDLE', "@test"),
            ethrx.build_engraving('GITHUB_HANDLE', "testuser"),
        ],
    };
    ethrx.engrave_star(112, full_artifact.clone());

    // Verify artifact exists before transfer
    assert!(ethrx.get_artifact(112) == full_artifact, "artifact should exist before transfer");

    // Transfer with artifact saving
    ethrx.transfer_with_engraving_star(ALICE, BOB, 112);

    // Verify enumerable state
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens");
    assert!(ethrx.balance_of(BOB) == 1, "BOB should have 1 token");
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 112, "BOB should have token 112");
    assert!(ethrx.token_by_index(111) == 112, "token_by_index(111) should return 112");

    // Verify artifact is preserved after transfer
    assert!(
        ethrx.get_artifact(112) == full_artifact, "artifact should be preserved after transfer",
    );
}

#[test]
fn test_enumerable_transfer_and_save_artifact_multiple_engravings() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![3]);
    assert!(ethrx.balance_of(ALICE) == 3, "ALICE should have 3 tokens");

    // Engrave each token with different data
    let artifact1 = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "Token 112"),
            ethrx.build_engraving('MESSAGE', "Message 112"), ethrx.build_engraving('URL', ""),
            ethrx.build_engraving('X_HANDLE', ""), ethrx.build_engraving('GITHUB_HANDLE', ""),
        ],
    };
    let artifact2 = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "Token 113"),
            ethrx.build_engraving('MESSAGE', "Message 113"), ethrx.build_engraving('URL', ""),
            ethrx.build_engraving('X_HANDLE', ""), ethrx.build_engraving('GITHUB_HANDLE', ""),
        ],
    };
    let artifact3 = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "Token 114"),
            ethrx.build_engraving('MESSAGE', "Message 114"), ethrx.build_engraving('URL', ""),
            ethrx.build_engraving('X_HANDLE', ""), ethrx.build_engraving('GITHUB_HANDLE', ""),
        ],
    };

    ethrx.engrave_star(112, artifact1.clone());
    ethrx.engrave_star(113, artifact2.clone());
    ethrx.engrave_star(114, artifact3.clone());

    // Transfer all tokens with artifact saving
    ethrx.transfer_with_engraving_star(ALICE, BOB, 112);
    ethrx.transfer_with_engraving_star(ALICE, BOB, 113);
    ethrx.transfer_with_engraving_star(ALICE, BOB, 114);

    // Verify enumerable state
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens");
    assert!(ethrx.balance_of(BOB) == 3, "BOB should have 3 tokens");
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 112, "BOB's first token should be 112");
    assert!(ethrx.token_of_owner_by_index(BOB, 1) == 113, "BOB's second token should be 113");
    assert!(ethrx.token_of_owner_by_index(BOB, 2) == 114, "BOB's third token should be 114");

    // Verify all artifacts are preserved
    assert!(ethrx.get_artifact(112) == artifact1, "artifact 1 should be preserved");
    assert!(ethrx.get_artifact(113) == artifact2, "artifact 2 should be preserved");
    assert!(ethrx.get_artifact(114) == artifact3, "artifact 3 should be preserved");
}

#[test]
fn test_enumerable_transfer_and_save_artifact_back_and_forth() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![3]);
    assert!(ethrx.balance_of(ALICE) == 3, "ALICE should have 3 tokens");

    // ALICE originally had [112, 113, 114]
    // Transfer token 112 from ALICE to BOB with artifact saving
    // Transfer 112 (index 0): swap with 114 → [114, 113, 112], remove last → [114, 113]
    ethrx.transfer_with_engraving_star(ALICE, BOB, 112);
    assert!(ethrx.balance_of(ALICE) == 2, "ALICE should have 2 tokens");
    assert!(ethrx.balance_of(BOB) == 1, "BOB should have 1 token");
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 114, "ALICE's first token should be 114");
    assert!(ethrx.token_of_owner_by_index(ALICE, 1) == 113, "ALICE's second token should be 113");
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 112, "BOB should have token 112");

    // Transfer token 112 back from BOB to ALICE with artifact saving
    // BOB has [112] (index 0, which is last), so just remove → []
    // ALICE receives 112 at the end → [114, 113, 112]
    ethrx.transfer_with_engraving_star(BOB, ALICE, 112);
    assert!(ethrx.balance_of(ALICE) == 3, "ALICE should have 3 tokens again");
    assert!(ethrx.balance_of(BOB) == 0, "BOB should have 0 tokens");
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 114, "ALICE's first token should be 114");
    assert!(ethrx.token_of_owner_by_index(ALICE, 1) == 113, "ALICE's second token should be 113");
    assert!(ethrx.token_of_owner_by_index(ALICE, 2) == 112, "ALICE's third token should be 112");

    // Verify token_by_index still works
    assert!(ethrx.token_by_index(111) == 112, "token_by_index(111) should return 112");
    assert!(ethrx.token_by_index(112) == 113, "token_by_index(112) should return 113");
    assert!(ethrx.token_by_index(113) == 114, "token_by_index(113) should return 114");
}

#[test]
fn test_enumerable_at_max_supply() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    let initial_supply = ethrx.total_supply();
    let remaining = ethrx.max_supply() - initial_supply;

    // Mint up to max supply
    ethrx.mint_batch_star(array![ALICE], array![remaining]);

    assert!(ethrx.total_supply() == ethrx.max_supply(), "total supply should equal max supply");

    // Verify all tokens are enumerable (max_supply is 111)
    for i in 0..111_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
    }

    // Verify ALICE has the newly minted tokens (100 tokens)
    let alice_balance = ethrx.balance_of(ALICE);
    assert!(alice_balance == remaining, "ALICE should have all newly minted tokens");

    // Verify ALICE's tokens are correctly indexed (tokens 12-111)
    for i in 0..100_usize {
        let token_id = ethrx.token_of_owner_by_index(ALICE, i);
        assert!(
            token_id == (initial_supply + i.into() + 1).into(),
            "ALICE's token at index {i} should be {}",
            initial_supply + i.into() + 1,
        );
    }
}

/// transfer_batch Authorization Tests ///

#[test]
fn test_transfer_batch_owner_success() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![3]);
    assert!(ethrx.balance_of(ALICE) == 3, "ALICE should have 3 tokens");
    assert!(ethrx.owner_of(112) == ALICE, "token 112 should be owned by ALICE");
    assert!(ethrx.owner_of(113) == ALICE, "token 113 should be owned by ALICE");
    assert!(ethrx.owner_of(114) == ALICE, "token 114 should be owned by ALICE");

    // ALICE transfers her own tokens to BOB
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.transfer_batch_direct(array![BOB, BOB, BOB], array![112, 113, 114]);
    stop_cheat_caller_address(ethrx.contract_address);

    // Verify transfers succeeded
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens");
    assert!(ethrx.balance_of(BOB) == 3, "BOB should have 3 tokens");
    assert!(ethrx.owner_of(112) == BOB, "token 112 should be owned by BOB");
    assert!(ethrx.owner_of(113) == BOB, "token 113 should be owned by BOB");
    assert!(ethrx.owner_of(114) == BOB, "token 114 should be owned by BOB");
}

#[test]
#[should_panic]
fn test_transfer_batch_non_owner_fails() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![2]);
    assert!(ethrx.owner_of(112) == ALICE, "token 112 should be owned by ALICE");
    assert!(ethrx.owner_of(113) == ALICE, "token 113 should be owned by ALICE");

    // BOB tries to transfer ALICE's tokens - should fail
    start_cheat_caller_address(ethrx.contract_address, BOB);
    ethrx.transfer_batch_direct(array![BOB, BOB], array![112, 113]);
    stop_cheat_caller_address(ethrx.contract_address);
}

#[test]
#[should_panic]
fn test_transfer_batch_mixed_ownership_fails() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint tokens to ALICE and BOB
    ethrx.mint_batch_star(array![ALICE, BOB], array![2, 1]);
    assert!(ethrx.owner_of(112) == ALICE, "token 112 should be owned by ALICE");
    assert!(ethrx.owner_of(113) == ALICE, "token 113 should be owned by ALICE");
    assert!(ethrx.owner_of(114) == BOB, "token 114 should be owned by BOB");

    // ALICE tries to transfer her tokens AND BOB's token - should fail on BOB's token
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.transfer_batch_direct(array![BOB, BOB, BOB], array![112, 113, 114]);
    stop_cheat_caller_address(ethrx.contract_address);
}

#[test]
fn test_transfer_batch_owner_partial_success() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![2]);
    assert!(ethrx.owner_of(112) == ALICE, "token 112 should be owned by ALICE");
    assert!(ethrx.owner_of(113) == ALICE, "token 113 should be owned by ALICE");

    // ALICE transfers only one of her tokens
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.transfer_batch_direct(array![BOB], array![112]);
    stop_cheat_caller_address(ethrx.contract_address);

    // Verify only one token transferred
    assert!(ethrx.balance_of(ALICE) == 1, "ALICE should have 1 token");
    assert!(ethrx.balance_of(BOB) == 1, "BOB should have 1 token");
    assert!(ethrx.owner_of(112) == BOB, "token 112 should be owned by BOB");
    assert!(ethrx.owner_of(113) == ALICE, "token 113 should still be owned by ALICE");
}

#[test]
#[should_panic]
fn test_transfer_batch_from_wrong_owner_fails() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![2]);
    assert!(ethrx.owner_of(112) == ALICE, "token 112 should be owned by ALICE");

    // BOB tries to transfer ALICE's token - should fail (not the owner)
    start_cheat_caller_address(ethrx.contract_address, BOB);
    ethrx.transfer_batch_direct(array![BOB], array![112]);
    stop_cheat_caller_address(ethrx.contract_address);
}

#[test]
fn test_transfer_batch_approved_operator_success() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);
    ethrx.mint_batch_star(array![ALICE], array![2]);

    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.erc721.approve(BOB, 112);
    stop_cheat_caller_address(ethrx.contract_address);

    start_cheat_caller_address(ethrx.contract_address, BOB);
    ethrx.transfer_batch_direct(array![BOB], array![112]);
    stop_cheat_caller_address(ethrx.contract_address);

    assert!(ethrx.owner_of(112) == BOB, "approved operator should transfer token 112");
    assert!(ethrx.owner_of(113) == ALICE, "unapproved token 113 should stay with ALICE");
}

#[test]
#[should_panic]
fn test_transfer_batch_approved_operator_other_token_fails() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);
    ethrx.mint_batch_star(array![ALICE], array![2]);

    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.erc721.approve(BOB, 112);
    stop_cheat_caller_address(ethrx.contract_address);

    start_cheat_caller_address(ethrx.contract_address, BOB);
    ethrx.transfer_batch_direct(array![BOB], array![113]);
    stop_cheat_caller_address(ethrx.contract_address);
}

#[test]
fn test_transfer_batch_approval_for_all_success() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);
    ethrx.mint_batch_star(array![ALICE], array![2]);

    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.erc721.set_approval_for_all(BOB, true);
    stop_cheat_caller_address(ethrx.contract_address);

    start_cheat_caller_address(ethrx.contract_address, BOB);
    ethrx.transfer_batch_direct(array![BOB, BOB], array![112, 113]);
    stop_cheat_caller_address(ethrx.contract_address);

    assert!(ethrx.owner_of(112) == BOB, "operator should transfer token 112");
    assert!(ethrx.owner_of(113) == BOB, "operator should transfer token 113");
}

#[test]
fn test_transfer_batch_mixed_owner_and_operator() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);
    ethrx.mint_batch_star(array![ALICE, BOB], array![1, 1]);

    start_cheat_caller_address(ethrx.contract_address, BOB);
    ethrx.erc721.approve(ALICE, 113);
    stop_cheat_caller_address(ethrx.contract_address);

    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.transfer_batch_direct(array![ALICE, ALICE], array![112, 113]);
    stop_cheat_caller_address(ethrx.contract_address);

    assert!(ethrx.owner_of(112) == ALICE, "ALICE should keep her own token");
    assert!(ethrx.owner_of(113) == ALICE, "ALICE should receive BOB's approved token");
}

#[test]
#[should_panic]
fn test_transfer_batch_zero_address_fails() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint token to ALICE
    ethrx.mint_star(ALICE);
    assert!(ethrx.owner_of(112) == ALICE, "token 112 should be owned by ALICE");

    // Try to transfer to zero address - should fail
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.transfer_batch_direct(array![core::num::traits::Zero::zero()], array![112]);
    stop_cheat_caller_address(ethrx.contract_address);
}

#[test]
fn test_transfer_batch_multiple_owners_success() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint tokens to ALICE and BOB
    ethrx.mint_batch_star(array![ALICE, BOB], array![2, 2]);
    assert!(ethrx.owner_of(112) == ALICE, "token 112 should be owned by ALICE");
    assert!(ethrx.owner_of(113) == ALICE, "token 113 should be owned by ALICE");
    assert!(ethrx.owner_of(114) == BOB, "token 114 should be owned by BOB");
    assert!(ethrx.owner_of(115) == BOB, "token 115 should be owned by BOB");

    // ALICE transfers her tokens
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.transfer_batch_direct(array![BOB, BOB], array![112, 113]);
    stop_cheat_caller_address(ethrx.contract_address);

    // BOB transfers his tokens
    start_cheat_caller_address(ethrx.contract_address, BOB);
    ethrx.transfer_batch_direct(array![ALICE, ALICE], array![114, 115]);
    stop_cheat_caller_address(ethrx.contract_address);

    // Verify all transfers succeeded
    assert!(ethrx.balance_of(ALICE) == 2, "ALICE should have 2 tokens");
    assert!(ethrx.balance_of(BOB) == 2, "BOB should have 2 tokens");
    assert!(ethrx.owner_of(112) == BOB, "token 112 should be owned by BOB");
    assert!(ethrx.owner_of(113) == BOB, "token 113 should be owned by BOB");
    assert!(ethrx.owner_of(114) == ALICE, "token 114 should be owned by ALICE");
    assert!(ethrx.owner_of(115) == ALICE, "token 115 should be owned by ALICE");
}

#[test]
fn test_transfer_batch_enumerable_state_maintained() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![3]);
    assert!(ethrx.balance_of(ALICE) == 3, "ALICE should have 3 tokens");
    assert!(ethrx.total_supply() == 114, "total supply should be 114");

    // ALICE transfers tokens to BOB using transfer_batch
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.transfer_batch_direct(array![BOB, BOB, BOB], array![112, 113, 114]);
    stop_cheat_caller_address(ethrx.contract_address);

    // Verify enumerable state is correct
    assert!(ethrx.total_supply() == 114, "total supply should remain 114");
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens");
    assert!(ethrx.balance_of(BOB) == 3, "BOB should have 3 tokens");

    // Verify token_by_index still works
    for i in 0..114_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
    }

    // Verify token_of_owner_by_index
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 112, "BOB's first token should be 112");
    assert!(ethrx.token_of_owner_by_index(BOB, 1) == 113, "BOB's second token should be 113");
    assert!(ethrx.token_of_owner_by_index(BOB, 2) == 114, "BOB's third token should be 114");
}

#[test]
#[should_panic]
fn test_transfer_batch_mismatched_lengths_tos_longer() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![2]);
    assert!(ethrx.owner_of(112) == ALICE, "token 112 should be owned by ALICE");
    assert!(ethrx.owner_of(113) == ALICE, "token 113 should be owned by ALICE");

    // Try to transfer with more 'to' addresses than token_ids - should fail
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.transfer_batch_direct(array![BOB, BOB, BOB], array![112, 113]);
    stop_cheat_caller_address(ethrx.contract_address);
}

#[test]
#[should_panic]
fn test_transfer_batch_mismatched_lengths_token_ids_longer() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![3]);
    assert!(ethrx.owner_of(112) == ALICE, "token 112 should be owned by ALICE");
    assert!(ethrx.owner_of(113) == ALICE, "token 113 should be owned by ALICE");
    assert!(ethrx.owner_of(114) == ALICE, "token 114 should be owned by ALICE");

    // Try to transfer with more token_ids than 'to' addresses - should fail
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.transfer_batch_direct(array![BOB, BOB], array![112, 113, 114]);
    stop_cheat_caller_address(ethrx.contract_address);
}

#[test]
#[should_panic]
fn test_transfer_batch_mismatched_lengths_empty_tos() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint token to ALICE
    ethrx.mint_star(ALICE);
    assert!(ethrx.owner_of(112) == ALICE, "token 112 should be owned by ALICE");

    // Try to transfer with empty 'tos' array - should fail
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.transfer_batch_direct(array![], array![112]);
    stop_cheat_caller_address(ethrx.contract_address);
}

#[test]
#[should_panic]
fn test_transfer_batch_mismatched_lengths_empty_token_ids() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint token to ALICE
    ethrx.mint_star(ALICE);
    assert!(ethrx.owner_of(112) == ALICE, "token 112 should be owned by ALICE");

    // Try to transfer with empty token_ids array - should fail
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.transfer_batch_direct(array![BOB], array![]);
    stop_cheat_caller_address(ethrx.contract_address);
}

#[test]
fn test_transfer_batch_matched_lengths_success() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Mint tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![3]);
    assert!(ethrx.balance_of(ALICE) == 3, "ALICE should have 3 tokens");

    // Transfer with matching lengths - should succeed
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.transfer_batch_direct(array![BOB, BOB, BOB], array![112, 113, 114]);
    stop_cheat_caller_address(ethrx.contract_address);

    // Verify transfers succeeded
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens");
    assert!(ethrx.balance_of(BOB) == 3, "BOB should have 3 tokens");
}

/// Promo/Marketing Batch Transfer Tests (tokens 12-111) ///

#[test]
fn test_promo_batch_transfer_keep_engraved_tokens() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // OWNER keeps tokens 1-11 (engraved), transfers 12-111 (unengraved) for promo
    let mut tokens_to_transfer = array![];
    let mut recipients = array![];

    // Build arrays for tokens 12-111
    for i in 12..=111_usize {
        tokens_to_transfer.append(i.into());
        recipients.append(ALICE); // Transfer all to ALICE for simplicity
    }

    // Verify initial state
    assert!(ethrx.balance_of(OWNER) == 111, "OWNER should have 111 tokens initially");
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens initially");

    // Verify tokens 1-11 are engraved
    for i in 1..=11_usize {
        let artifact = ethrx.get_artifact(i.into());
        let expected = INITIAL_ENGRAVINGS::INITIAL_ARTIFACT(i.into());
        assert!(artifact == expected, "token {i} should have initial engraving");
    }

    // OWNER transfers tokens 12-111 to ALICE using batch transfer
    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.transfer_batch_direct(recipients, tokens_to_transfer);
    stop_cheat_caller_address(ethrx.contract_address);

    // Verify OWNER kept tokens 1-11
    assert!(ethrx.balance_of(OWNER) == 11, "OWNER should have kept 11 tokens");
    for i in 1..=11_usize {
        assert!(ethrx.owner_of(i.into()) == OWNER, "token {i} should still be owned by OWNER");
    }

    // Verify ALICE received tokens 12-111
    assert!(ethrx.balance_of(ALICE) == 100, "ALICE should have received 100 tokens");
    for i in 12..=111_usize {
        assert!(ethrx.owner_of(i.into()) == ALICE, "token {i} should be owned by ALICE");
    }

    // Verify engraved tokens 1-11 are still intact
    for i in 1..=11_usize {
        let artifact = ethrx.get_artifact(i.into());
        let expected = INITIAL_ENGRAVINGS::INITIAL_ARTIFACT(i.into());
        assert!(artifact == expected, "token {i} engraving should be preserved");
    }

    // Verify unengraved tokens 12-111 are still empty
    for i in 12..=111_usize {
        let artifact = ethrx.get_artifact(i.into());
        for engraving in artifact.collection {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "", "token {i} should remain unengraved after transfer");
        }
    }
}

#[test]
fn test_promo_batch_transfer_enumerable_state() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Transfer tokens 12-50 to ALICE, 51-100 to BOB, keep 101-111 with OWNER
    let mut tokens_alice = array![];
    let mut tokens_bob = array![];
    let mut recipients_alice = array![];
    let mut recipients_bob = array![];

    for i in 12..=50_usize {
        tokens_alice.append(i.into());
        recipients_alice.append(ALICE);
    }

    for i in 51..=100_usize {
        tokens_bob.append(i.into());
        recipients_bob.append(BOB);
    }

    // Transfer to ALICE
    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.transfer_batch_direct(recipients_alice, tokens_alice);
    stop_cheat_caller_address(ethrx.contract_address);

    // Transfer to BOB
    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.transfer_batch_direct(recipients_bob, tokens_bob);
    stop_cheat_caller_address(ethrx.contract_address);

    // Verify balances
    // OWNER starts with 111 tokens, transfers 39 (12-50) to ALICE and 50 (51-100) to BOB
    // OWNER keeps: 1-11 (11 tokens) + 101-111 (11 tokens) = 22 tokens
    assert!(ethrx.balance_of(OWNER) == 22, "OWNER should have 22 tokens (1-11, 101-111)");
    assert!(ethrx.balance_of(ALICE) == 39, "ALICE should have 39 tokens (12-50)");
    assert!(ethrx.balance_of(BOB) == 50, "BOB should have 50 tokens (51-100)");

    // Verify enumerable state - total supply unchanged
    assert!(ethrx.total_supply() == 111, "total supply should remain 111");

    // Verify token_by_index still works
    for i in 0..111_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
    }

    // Verify OWNER's tokens via enumeration
    // OWNER has 22 tokens: 1-11 and 101-111
    // Due to pop-and-swap during transfers, the order may not be sequential
    assert!(ethrx.token_of_owner_by_index(OWNER, 0) == 1, "OWNER's first token should be 1");
    assert!(ethrx.token_of_owner_by_index(OWNER, 10) == 11, "OWNER's 11th token should be 11");
    // After transferring tokens 12-100, OWNER's remaining tokens are 1-11 and 101-111
    // The 12th token (index 11) should be one of 101-111, but due to pop-and-swap it might be 111
    let owner_token_11 = ethrx.token_of_owner_by_index(OWNER, 11);
    assert!(
        owner_token_11 >= 101 && owner_token_11 <= 111,
        "OWNER's 12th token should be between 101-111",
    );

    // Verify ALICE's tokens via enumeration
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 12, "ALICE's first token should be 12");
    assert!(ethrx.token_of_owner_by_index(ALICE, 38) == 50, "ALICE's last token should be 50");

    // Verify BOB's tokens via enumeration
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 51, "BOB's first token should be 51");
    assert!(ethrx.token_of_owner_by_index(BOB, 49) == 100, "BOB's last token should be 100");
}

#[test]
fn test_promo_batch_transfer_multiple_recipients() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Simulate distributing tokens 12-20 to different recipients for promo
    let tokens = array![12, 13, 14, 15, 16, 17, 18, 19, 20];
    let recipients = array![ALICE, BOB, ALICE, BOB, ALICE, BOB, ALICE, BOB, ALICE];

    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.transfer_batch_direct(recipients, tokens);
    stop_cheat_caller_address(ethrx.contract_address);

    // Verify distribution
    assert!(ethrx.owner_of(12) == ALICE, "token 12 should go to ALICE");
    assert!(ethrx.owner_of(13) == BOB, "token 13 should go to BOB");
    assert!(ethrx.owner_of(14) == ALICE, "token 14 should go to ALICE");
    assert!(ethrx.owner_of(15) == BOB, "token 15 should go to BOB");
    assert!(ethrx.owner_of(16) == ALICE, "token 16 should go to ALICE");
    assert!(ethrx.owner_of(17) == BOB, "token 17 should go to BOB");
    assert!(ethrx.owner_of(18) == ALICE, "token 18 should go to ALICE");
    assert!(ethrx.owner_of(19) == BOB, "token 19 should go to BOB");
    assert!(ethrx.owner_of(20) == ALICE, "token 20 should go to ALICE");

    assert!(ethrx.balance_of(ALICE) == 5, "ALICE should have 5 tokens");
    assert!(ethrx.balance_of(BOB) == 4, "BOB should have 4 tokens");
    assert!(ethrx.balance_of(OWNER) == 102, "OWNER should have 102 tokens remaining");

    // Verify all transferred tokens remain unengraved
    for i in 12..=20_usize {
        let artifact = ethrx.get_artifact(i.into());
        for engraving in artifact.collection {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "", "token {i} should remain unengraved");
        }
    }
}

#[test]
fn test_promo_batch_transfer_preserve_engraved_tokens() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Transfer a large batch of unengraved tokens (12-111)
    let mut tokens = array![];
    let mut recipients = array![];

    for i in 12..=111_usize {
        tokens.append(i.into());
        recipients.append(ALICE);
    }

    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.transfer_batch_direct(recipients, tokens);
    stop_cheat_caller_address(ethrx.contract_address);

    // Verify tokens 1-11 (engraved) are still with OWNER and intact
    assert!(ethrx.balance_of(OWNER) == 11, "OWNER should have 11 engraved tokens");

    for i in 1..=11_usize {
        assert!(ethrx.owner_of(i.into()) == OWNER, "token {i} should be with OWNER");

        // Verify engraving is preserved
        let artifact = ethrx.get_artifact(i.into());
        let expected = INITIAL_ENGRAVINGS::INITIAL_ARTIFACT(i.into());
        assert!(artifact == expected, "token {i} engraving should be preserved");

        // Verify artifact_id hasn't changed (no wipe occurred)
        let artifact_id = ethrx.token_id_to_artifact_id(i.into());
        assert!(artifact_id == i.into(), "token {i} artifact_id should remain {i}");
    }
}

#[test]
fn test_promo_batch_transfer_large_batch() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Test transferring all 100 unengraved tokens in one batch
    let mut tokens = array![];
    let mut recipients = array![];

    for i in 12..=111_usize {
        tokens.append(i.into());
        recipients.append(ALICE);
    }

    let owner_balance_before = ethrx.balance_of(OWNER);
    let alice_balance_before = ethrx.balance_of(ALICE);

    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.transfer_batch_direct(recipients, tokens);
    stop_cheat_caller_address(ethrx.contract_address);

    // Verify balances
    assert!(
        ethrx.balance_of(OWNER) == owner_balance_before - 100,
        "OWNER should have transferred 100 tokens",
    );
    assert!(
        ethrx.balance_of(ALICE) == alice_balance_before + 100,
        "ALICE should have received 100 tokens",
    );

    // Verify enumerable state is correct
    assert!(ethrx.total_supply() == 111, "total supply should remain 111");
    assert!(ethrx.balance_of(OWNER) == 11, "OWNER should have 11 tokens");
    assert!(ethrx.balance_of(ALICE) == 100, "ALICE should have 100 tokens");

    // Verify all tokens are still enumerable
    for i in 0..111_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
    }
}

/// is_minting Tests ///

#[test]
fn test_is_minting_disabled_by_default() {
    let (ethrx, _) = setup_without_enabling_minting();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Verify minting is disabled by default
    assert!(!ethrx.is_minting(), "Minting should be disabled by default");
}

#[test]
fn test_initial_111_tokens_still_minted_during_deployment() {
    let (ethrx, _) = setup_without_enabling_minting();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Verify that the first 111 tokens are still minted during deployment
    assert!(ethrx.total_supply() == 111, "initial total supply should be 111");
    assert!(ethrx.is_minting() == false, "Minting should be disabled");

    // Verify all tokens 1-111 are owned by OWNER
    for i in 1..=111_usize {
        assert!(ethrx.owner_of(i.into()) == OWNER, "token {i} should be owned by OWNER");
    }

    // Verify tokens 1-11 have initial engravings
    for i in 1..=11_usize {
        assert!(
            ethrx.get_artifact(i.into()) == INITIAL_ENGRAVINGS::INITIAL_ARTIFACT(i.into()),
            "token {i} should have initial artifact",
        );
    }
}

#[test]
#[should_panic]
fn test_minting_fails_when_disabled() {
    let (ethrx, _) = setup_without_enabling_minting();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Verify minting is disabled
    assert!(!ethrx.is_minting(), "Minting should be disabled");

    // Attempt to mint should fail
    ethrx.mint_batch_star(array![ALICE], array![1]);
}

#[test]
fn test_set_minting_owner_only() {
    let (ethrx, _) = setup_without_enabling_minting();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Verify minting is disabled initially
    assert!(!ethrx.is_minting(), "Minting should be disabled initially");

    // Owner should be able to enable minting
    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.set_minting(true);
    stop_cheat_caller_address(ethrx.contract_address);

    assert!(ethrx.is_minting(), "Minting should be enabled after owner sets it");

    // Owner should be able to disable minting
    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.set_minting(false);
    stop_cheat_caller_address(ethrx.contract_address);

    assert!(!ethrx.is_minting(), "Minting should be disabled after owner sets it");
}

#[test]
#[should_panic]
fn test_set_minting_non_owner_fails() {
    let (ethrx, _) = setup_without_enabling_minting();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Non-owner should not be able to set minting - should panic
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.set_minting(true);
    stop_cheat_caller_address(ethrx.contract_address);
}

#[test]
fn test_minting_works_after_enabled() {
    let (ethrx, _) = setup_without_enabling_minting();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Verify minting is disabled initially
    assert!(!ethrx.is_minting(), "Minting should be disabled initially");

    // Enable minting as owner
    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.set_minting(true);
    stop_cheat_caller_address(ethrx.contract_address);

    assert!(ethrx.is_minting(), "Minting should be enabled");

    // Now minting should work
    let total_supply_before = ethrx.total_supply();
    ethrx.mint_batch_star(array![ALICE], array![1]);

    assert!(
        ethrx.total_supply() == total_supply_before + 1,
        "Total supply should increase after minting",
    );
    assert!(ethrx.owner_of(total_supply_before + 1) == ALICE, "New token should be owned by ALICE");
}

#[test]
#[should_panic]
fn test_minting_fails_after_disabled() {
    let (ethrx, _) = setup_without_enabling_minting();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    // Enable minting first
    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.set_minting(true);
    stop_cheat_caller_address(ethrx.contract_address);

    // Mint a token to verify it works
    ethrx.mint_batch_star(array![ALICE], array![1]);

    // Disable minting
    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.set_minting(false);
    stop_cheat_caller_address(ethrx.contract_address);

    // Minting should fail now
    ethrx.mint_batch_star(array![BOB], array![1]);
}

#[test]
fn test_mint_emits_artifact_assigned() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);
    let mut spy = spy_events();
    ethrx.mint_star(ALICE);

    spy
        .assert_emitted(
            @array![
                (
                    ethrx.contract_address,
                    Ethrx::Event::ArtifactAssigned(
                        Ethrx::ArtifactAssigned {
                            token_id: 112, artifact_id: 112, previous_artifact_id: 0,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_wipe_transfer_emits_artifact_assigned() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);
    ethrx.mint_star(ALICE);
    let previous_artifact_id = ethrx.token_id_to_artifact_id(112);

    let mut spy = spy_events();
    ethrx.transfer_star(ALICE, BOB, 112);
    let artifact_id = ethrx.token_id_to_artifact_id(112);

    spy
        .assert_emitted(
            @array![
                (
                    ethrx.contract_address,
                    Ethrx::Event::ArtifactAssigned(
                        Ethrx::ArtifactAssigned {
                            token_id: 112, artifact_id, previous_artifact_id,
                        },
                    ),
                ),
            ],
        );
    spy
        .assert_not_emitted(
            @array![
                (
                    ethrx.contract_address,
                    Ethrx::Event::ArtifactPreserved(
                        Ethrx::ArtifactPreserved {
                            token_id: 112, artifact_id: previous_artifact_id, from: ALICE, to: BOB,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_save_transfer_emits_artifact_preserved() {
    let (ethrx, _) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);
    ethrx.mint_star(ALICE);
    let artifact_id = ethrx.token_id_to_artifact_id(112);

    let mut spy = spy_events();
    ethrx.transfer_with_engraving_star(ALICE, BOB, 112);

    spy
        .assert_emitted(
            @array![
                (
                    ethrx.contract_address,
                    Ethrx::Event::ArtifactPreserved(
                        Ethrx::ArtifactPreserved {
                            token_id: 112, artifact_id, from: ALICE, to: BOB,
                        },
                    ),
                ),
            ],
        );
    spy
        .assert_not_emitted(
            @array![
                (
                    ethrx.contract_address,
                    Ethrx::Event::ArtifactAssigned(
                        Ethrx::ArtifactAssigned {
                            token_id: 112,
                            artifact_id: artifact_id + 1,
                            previous_artifact_id: artifact_id,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_admin_config_events() {
    let (ethrx, erc20) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);
    let new_contract_uri: ByteArray = "https://example.com/contract";
    let new_base_uri: ByteArray = "https://example.com/base/";

    let mut spy = spy_events();
    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.set_mint_price(MINT_PRICE * 2);
    ethrx.set_mint_token(ALICE);
    ethrx.set_minting(false);
    ethrx.set_contract_uri(new_contract_uri.clone());
    ethrx.set_base_uri(new_base_uri.clone());
    ethrx.set_tags(Option::None, Option::Some(array!['BIO']));
    stop_cheat_caller_address(ethrx.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    ethrx.contract_address,
                    Ethrx::Event::MintPriceUpdated(
                        Ethrx::MintPriceUpdated {
                            old_price: MINT_PRICE, new_price: MINT_PRICE * 2,
                        },
                    ),
                ),
                (
                    ethrx.contract_address,
                    Ethrx::Event::MintTokenUpdated(
                        Ethrx::MintTokenUpdated {
                            old_token: erc20.contract_address, new_token: ALICE,
                        },
                    ),
                ),
                (
                    ethrx.contract_address,
                    Ethrx::Event::MintingStatusUpdated(
                        Ethrx::MintingStatusUpdated { enabled: false },
                    ),
                ),
                (
                    ethrx.contract_address,
                    Ethrx::Event::ContractURIUpdated(
                        Ethrx::ContractURIUpdated { new_uri: new_contract_uri },
                    ),
                ),
                (
                    ethrx.contract_address,
                    Ethrx::Event::BaseURIUpdated(
                        Ethrx::BaseURIUpdated { new_uri: new_base_uri },
                    ),
                ),
                (
                    ethrx.contract_address,
                    Ethrx::Event::TagRegistered(
                        Ethrx::TagRegistered { index: 6, new_tag: 'BIO' },
                    ),
                ),
            ],
        );
}

#[test]
fn test_admin_config_noop_skips_events() {
    let (ethrx, erc20) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    let mut spy = spy_events();
    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.set_mint_price(MINT_PRICE);
    ethrx.set_mint_token(erc20.contract_address);
    ethrx.set_minting(true);
    ethrx.set_contract_uri(CONTRACT_URI());
    ethrx.set_base_uri(BASE_URI());
    stop_cheat_caller_address(ethrx.contract_address);

    assert!(spy.get_events().events.len() == 0, "no-op admin writes must not emit");
}

#[test]
fn test_upgrade_emits_version_updated() {
    let (ethrx, _) = setup();
    assert!(ethrx.version() == 1, "constructor version should be 1");

    let mut spy = spy_events();
    let ethrx = upgrade(ethrx);

    spy
        .assert_emitted(
            @array![
                (
                    ethrx.contract_address,
                    Ethrx::Event::VersionUpdated(
                        Ethrx::VersionUpdated { old_version: 1, new_version: 2 },
                    ),
                ),
            ],
        );
    assert!(ethrx.version() == 2, "version should bump to 2 after upgrade");
}

#[test]
fn test_mint_emits_etheracts_purchased() {
    let (ethrx, erc20) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    let mut spy = spy_events();
    ethrx.mint_star(ALICE);

    spy
        .assert_emitted(
            @array![
                (
                    ethrx.contract_address,
                    Ethrx::Event::EtheractsPurchased(
                        Ethrx::EtheractsPurchased {
                            token_id: 112,
                            buyer: BYSTANDER,
                            to: ALICE,
                            payment_token: erc20.contract_address,
                            price: MINT_PRICE,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_mint_batch_emits_etheracts_purchased_per_token() {
    let (ethrx, erc20) = setup();
    let ethrx = upgrade(ethrx);
    initializerV2(ethrx);

    let mut spy = spy_events();
    ethrx.mint_batch_star(array![ALICE, BOB], array![2, 1]);

    spy
        .assert_emitted(
            @array![
                (
                    ethrx.contract_address,
                    Ethrx::Event::EtheractsPurchased(
                        Ethrx::EtheractsPurchased {
                            token_id: 112,
                            buyer: BYSTANDER,
                            to: ALICE,
                            payment_token: erc20.contract_address,
                            price: MINT_PRICE,
                        },
                    ),
                ),
                (
                    ethrx.contract_address,
                    Ethrx::Event::EtheractsPurchased(
                        Ethrx::EtheractsPurchased {
                            token_id: 113,
                            buyer: BYSTANDER,
                            to: ALICE,
                            payment_token: erc20.contract_address,
                            price: MINT_PRICE,
                        },
                    ),
                ),
                (
                    ethrx.contract_address,
                    Ethrx::Event::EtheractsPurchased(
                        Ethrx::EtheractsPurchased {
                            token_id: 114,
                            buyer: BYSTANDER,
                            to: BOB,
                            payment_token: erc20.contract_address,
                            price: MINT_PRICE,
                        },
                    ),
                ),
            ],
        );
}
