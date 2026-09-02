#[derive(Drop, Serde)]
pub struct InitializerV2Args {
    pub new_feature: felt252,
}

#[starknet::interface]
pub trait IEthrxV2<TState> {
    /// READ ///
    fn get_new_feature(self: @TState) -> felt252;

    /// WRITE ///
    fn initializerV2(ref self: TState, args: InitializerV2Args);
    fn set_new_feature(ref self: TState, _new: felt252);
}

#[starknet::contract]
pub mod EthrxV2 {
    use alexandria_bytes::{Bytes, BytesStore};
    use core::num::traits::Zero;
    use etheracts::ethrx::interface::{ConstructorArgs, IEthrx};
    use etheracts::types::engraving::{Artifact, Engraving, INITIAL_ENGRAVINGS};
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::ERC721Component::Errors as ERC721Errors;
    use openzeppelin_token::erc721::extensions::ERC721EnumerableComponent;
    use openzeppelin_upgrades::upgradeable::UpgradeableComponent;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress, get_caller_address};
    use super::{IEthrxV2, InitializerV2Args};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(
        path: ERC721EnumerableComponent, storage: erc721_enumerable, event: ERC721EnumerableEvent,
    );
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);


    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;


    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721EnumerableImpl =
        ERC721EnumerableComponent::ERC721EnumerableImpl<ContractState>;
    impl ERC721EnumberableInternalImpl = ERC721EnumerableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        /// V1 ///
        is_minting: bool,
        mint_token: ContractAddress,
        mint_price: u256,
        max_supply: u256,
        artifact_nonces: felt252,
        token_artifact_ids: Map<u256, felt252>,
        tag_registry: Map<usize, felt252>,
        total_registered_tags: usize,
        tag_nonces: Map<(felt252, felt252), usize>,
        artifacts: Map<(felt252, felt252, usize), Bytes>,
        artifact_saving: Map<u256, bool>,
        contract_uri: ByteArray,
        version: usize,
        initialized: Map<usize, bool>,
        /// V2 ///
        new_feature: felt252,
        /// V1 ///
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        erc721_enumerable: ERC721EnumerableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, args: ConstructorArgs) {
        let ConstructorArgs {
            owner, name, symbol, base_uri, contract_uri, mint_token, mint_price, max_supply,
        } = args;

        self.ownable.initializer(owner);
        self.erc721.initializer(name, symbol, base_uri);

        self.contract_uri.write(contract_uri);

        self.mint_token.write(mint_token);
        self.mint_price.write(mint_price);
        self.max_supply.write(max_supply);

        self._mint_and_engrave_initial_artifacts(owner);

        self.version.write(1);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ArtifactEngraved: ArtifactEngraved,
        ArtifactAssigned: ArtifactAssigned,
        ArtifactPreserved: ArtifactPreserved,
        TagRegistered: TagRegistered,
        TagReregistered: TagReregistered,
        MintPriceUpdated: MintPriceUpdated,
        MintTokenUpdated: MintTokenUpdated,
        MintingStatusUpdated: MintingStatusUpdated,
        ContractURIUpdated: ContractURIUpdated,
        BaseURIUpdated: BaseURIUpdated,
        EtheractsPurchased: EtheractsPurchased,
        VersionUpdated: VersionUpdated,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        ERC721EnumerableEvent: ERC721EnumerableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ArtifactAssigned {
        #[key]
        pub token_id: u256,
        #[key]
        pub artifact_id: felt252,
        pub previous_artifact_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ArtifactPreserved {
        #[key]
        pub token_id: u256,
        #[key]
        pub artifact_id: felt252,
        pub from: ContractAddress,
        pub to: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ArtifactEngraved {
        #[key]
        pub token_id: u256,
        #[key]
        pub artifact_id: felt252,
        #[key]
        pub tag: felt252,
        pub nonce: usize,
        pub new_data: Bytes,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TagRegistered {
        pub index: usize,
        pub new_tag: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TagReregistered {
        pub index: usize,
        pub old_tag: felt252,
        pub new_tag: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MintPriceUpdated {
        pub old_price: u256,
        pub new_price: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MintTokenUpdated {
        pub old_token: ContractAddress,
        pub new_token: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MintingStatusUpdated {
        pub enabled: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContractURIUpdated {
        pub new_uri: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BaseURIUpdated {
        pub new_uri: ByteArray,
    }

    /// Emitted once per paid token mint (not for free/constructor mints).
    #[derive(Drop, starknet::Event)]
    pub struct EtheractsPurchased {
        #[key]
        pub token_id: u256,
        #[key]
        pub buyer: ContractAddress,
        pub to: ContractAddress,
        pub payment_token: ContractAddress,
        pub price: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct VersionUpdated {
        pub old_version: usize,
        pub new_version: usize,
    }

    impl EthrxHooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let mut self = self.get_contract_mut();

            // @dev If this is a transfer that saves the artifact, do not wipe it
            if !self.artifact_saving.entry(token_id).read() {
                self._wipe_artifact(token_id);
            }

            // @dev Handle ERC721Enumerable logic
            self.erc721_enumerable.before_update(to, token_id);
        }
    }

    #[abi(embed_v0)]
    impl EthrxV2Impl of IEthrxV2<ContractState> {
        fn get_new_feature(self: @ContractState) -> felt252 {
            self.new_feature.read()
        }

        fn initializerV2(ref self: ContractState, args: InitializerV2Args) {
            self._only_owner();
            self._initializer(2);
            self.new_feature.write(args.new_feature);
        }

        fn set_new_feature(ref self: ContractState, _new: felt252) {
            self._only_owner();
            self.new_feature.write(_new)
        }
    }


    #[abi(embed_v0)]
    impl EthrxImpl of IEthrx<ContractState> {
        /// READ ///
        fn is_minting(self: @ContractState) -> bool {
            self.is_minting.read()
        }

        fn mint_price(self: @ContractState) -> u256 {
            self.mint_price.read()
        }

        fn mint_token(self: @ContractState) -> ContractAddress {
            self.mint_token.read()
        }

        fn max_supply(self: @ContractState) -> u256 {
            self.max_supply.read()
        }

        fn total_artifacts(self: @ContractState) -> felt252 {
            self.artifact_nonces.read()
        }

        fn token_ids_to_artifact_ids(
            self: @ContractState, token_ids: Array<u256>,
        ) -> Array<felt252> {
            token_ids.into_iter().map(|id| self.token_artifact_ids.entry(id).read()).collect()
        }

        fn artifact_tag_nonces(
            self: @ContractState, artifact_ids: Array<felt252>, tags: Array<felt252>,
        ) -> Array<usize> {
            assert!(artifact_ids.len() == tags.len(), "Mismatched lengths");
            artifact_ids
                .into_iter()
                .zip(tags)
                .map(
                    |key| {
                        let (artifact_id, tag) = key;
                        self.tag_nonces.entry((artifact_id, tag)).read()
                    },
                )
                .collect()
        }

        fn get_artifacts(self: @ContractState, token_ids: Array<u256>) -> Array<Artifact> {
            let official_tags = @self.official_tags();

            let mut artifacts: Array<Artifact> = array![];
            for token_id in token_ids {
                let artifact_id = self.token_artifact_ids.entry(token_id).read();
                let nonce_list = self._get_artifact_nonces(artifact_id, official_tags);

                artifacts.append(self._lookup_artifact(artifact_id, official_tags, @nonce_list));
            }
            artifacts
        }

        fn get_historic_artifacts(
            self: @ContractState,
            artifact_ids: Array<felt252>,
            tags: Array<Array<felt252>>,
            tag_nonces: Array<Array<usize>>,
        ) -> Array<Artifact> {
            assert!(artifact_ids.len() == tags.len(), "Mismatched lengths");
            assert!(tags.len() == tag_nonces.len(), "Mismatched lengths");

            let mut artifacts: Array<Artifact> = array![];
            for i in 0..tags.len() {
                let artifact_id = *artifact_ids.at(i);
                let tag_list = tags.at(i);
                let nonce_list = tag_nonces.at(i);

                artifacts.append(self._lookup_artifact(artifact_id, tag_list, nonce_list));
            }
            artifacts
        }

        fn contract_uri(self: @ContractState) -> ByteArray {
            self.contract_uri.read()
        }

        fn contractURI(self: @ContractState) -> ByteArray {
            self.contract_uri.read()
        }

        fn official_tags(self: @ContractState) -> Array<felt252> {
            let total_registered_tags: u256 = self.total_registered_tags.read().into();
            let mut tags: Array<felt252> = array![];
            for i in 1..=total_registered_tags {
                let tag = self.tag_registry.entry(i.try_into().unwrap()).read();
                tags.append(tag);
            }
            tags
        }

        fn version(self: @ContractState) -> usize {
            self.version.read()
        }

        /// WRITE ///

        fn mint(ref self: ContractState, amounts: Array<u256>, tos: Array<ContractAddress>) {
            assert!(self.is_minting.read(), "Minting not enabled");
            assert!(amounts.len() == tos.len(), "Mismatched lengths");

            for (amount, to) in amounts.into_iter().zip(tos) {
                self._mint(to, amount, true);
            }
        }

        fn engrave(ref self: ContractState, token_ids: Array<u256>, artifacts: Array<Artifact>) {
            assert!(token_ids.len() == artifacts.len(), "Mismatched lengths");

            for i in 0..token_ids.len() {
                let token_id = *token_ids[i];
                let artifact = artifacts.at(i).clone();

                assert!(self.owner_of(token_id) == get_caller_address(), "Not token owner");

                self._engrave_artifact(token_id, artifact, true);
            }
        }

        fn transfer_and_save_artifact(
            ref self: ContractState,
            froms: Array<ContractAddress>,
            tos: Array<ContractAddress>,
            token_ids: Array<u256>,
        ) {
            assert!(
                froms.len() == tos.len() && froms.len() == token_ids.len(), "Mismatched lengths",
            );

            for i in 0..token_ids.len() {
                let from = *froms[i];
                let to = *tos[i];
                let token_id = *token_ids[i];

                self._transfer_with_engraving(from, to, token_id);
            }
        }

        fn transfer_batch(
            ref self: ContractState, tos: Array<ContractAddress>, token_ids: Array<u256>,
        ) {
            assert!(tos.len() == token_ids.len(), "Mismatched lengths");
            for i in 0..token_ids.len() {
                let to = *tos[i];
                let token_id = *token_ids[i];
                let from = self.owner_of(token_id);

                self.transfer_from(from, to, token_id);
            }
        }

        fn set_base_uri(ref self: ContractState, new_base_uri: ByteArray) {
            self._only_owner();
            if self.erc721._base_uri() == new_base_uri {
                return;
            }
            self.erc721._set_base_uri(new_base_uri.clone());
            self.emit(Event::BaseURIUpdated(BaseURIUpdated { new_uri: new_base_uri }));
        }

        fn set_contract_uri(ref self: ContractState, new_contract_uri: ByteArray) {
            self._only_owner();
            if self.contract_uri.read() == new_contract_uri {
                return;
            }
            self.contract_uri.write(new_contract_uri.clone());
            self
                .emit(
                    Event::ContractURIUpdated(ContractURIUpdated { new_uri: new_contract_uri }),
                );
        }

        fn set_mint_price(ref self: ContractState, new_mint_price: u256) {
            self._only_owner();
            let old_price = self.mint_price.read();
            if old_price == new_mint_price {
                return;
            }
            self.mint_price.write(new_mint_price);
            self.emit(Event::MintPriceUpdated(MintPriceUpdated { old_price, new_price: new_mint_price }));
        }

        fn set_mint_token(ref self: ContractState, new_mint_token: ContractAddress) {
            self._only_owner();
            let old_token = self.mint_token.read();
            if old_token == new_mint_token {
                return;
            }
            self.mint_token.write(new_mint_token);
            self.emit(Event::MintTokenUpdated(MintTokenUpdated { old_token, new_token: new_mint_token }));
        }

        fn set_is_minting(ref self: ContractState, enabled: bool) {
            self._only_owner();
            if self.is_minting.read() == enabled {
                return;
            }
            self.is_minting.write(enabled);
            self.emit(Event::MintingStatusUpdated(MintingStatusUpdated { enabled }));
        }

        fn set_tags(
            ref self: ContractState,
            modify_tags: Option<Array<(usize, felt252)>>,
            new_tags: Option<Array<felt252>>,
        ) {
            self._only_owner();

            if let Option::Some(tag_fixes) = modify_tags {
                let total_registered_tags = self.total_registered_tags.read();

                for tag_fixes in tag_fixes {
                    let (index, new_tag) = tag_fixes;

                    assert!(index <= total_registered_tags, "Index out of bounds");

                    let old_tag = self.tag_registry.entry(index).read();
                    if old_tag == new_tag {
                        continue;
                    }

                    self.tag_registry.entry(index).write(new_tag);
                    self
                        .emit(
                            Event::TagReregistered(
                                TagReregistered { index, old_tag, new_tag },
                            ),
                        );
                }
            }

            if let Option::Some(tags) = new_tags {
                let mut total_registered_tags = self.total_registered_tags.read();

                for new_tag in tags {
                    total_registered_tags += 1;

                    self.total_registered_tags.write(total_registered_tags);
                    self.tag_registry.entry(total_registered_tags).write(new_tag);
                    self
                        .emit(
                            Event::TagRegistered(
                                TagRegistered { index: total_registered_tags, new_tag },
                            ),
                        );
                }
            }
        }

        fn upgrade_contract(ref self: ContractState, new_class_hash: ClassHash) {
            self._only_owner();
            let old_version = self.version.read();
            let new_version = old_version + 1;
            self.version.write(new_version);
            self.emit(Event::VersionUpdated(VersionUpdated { old_version, new_version }));
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    impl InternalImpl of EthrxInternalTrait {
        /// V1 ///
        fn _initializer(ref self: ContractState, version: usize) {
            let current_version = self.version.read();

            assert!(
                current_version == version,
                "Initializer called incorrectly (expected: {current_version}, got: {version})",
            );
            assert!(
                !self.initialized.entry(version).read(),
                "Contract V{} is already initialized",
                version,
            );

            self.initialized.entry(version).write(true);
        }

        fn _get_artifact_nonces(
            self: @ContractState, artifact_id: felt252, tags: @Array<felt252>,
        ) -> Array<usize> {
            (tags)
                .into_iter()
                .map(|tag| self.tag_nonces.entry((artifact_id, *tag)).read())
                .collect()
        }

        fn _lookup_artifact(
            self: @ContractState,
            artifact_id: felt252,
            tags: @Array<felt252>,
            tag_nonces: @Array<usize>,
        ) -> Artifact {
            assert!(tags.len() == tag_nonces.len(), "Mismatched lengths");

            let collection: Array<Engraving> = tags
                .into_iter()
                .zip(tag_nonces)
                .map(
                    |tag_nonce| {
                        let (tag, nonce) = tag_nonce;
                        Engraving {
                            tag: *tag,
                            data: self.artifacts.entry((artifact_id, *tag, *nonce)).read(),
                        }
                    },
                )
                .collect();

            Artifact { collection }
        }


        fn _only_owner(ref self: ContractState) {
            assert!(get_caller_address() == self.owner(), "Ownable: caller is not the owner");
        }

        fn _register_tags(ref self: ContractState, new_tags: Array<felt252>) {
            let mut total_registered_tags = self.total_registered_tags.read();

            for new_tag in new_tags {
                total_registered_tags += 1;

                self.total_registered_tags.write(total_registered_tags);
                self.tag_registry.entry(total_registered_tags).write(new_tag);
                self
                    .emit(
                        Event::TagRegistered(
                            TagRegistered { index: total_registered_tags, new_tag },
                        ),
                    );
            }
        }

        fn _mint(ref self: ContractState, to: ContractAddress, amount: u256, is_paying: bool) {
            let total_tokens = self.erc721_enumerable.total_supply();
            let payment_token = self.mint_token.read();
            let price = self.mint_price.read();
            let buyer = get_caller_address();

            let mut cost: u256 = 0;
            for i in 0..amount {
                let new_token_id = total_tokens + i + 1;
                if new_token_id <= self.max_supply.read() {
                    self.erc721.mint(to, new_token_id);
                    if is_paying {
                        cost += price;
                        self
                            .emit(
                                Event::EtheractsPurchased(
                                    EtheractsPurchased {
                                        token_id: new_token_id,
                                        buyer,
                                        to,
                                        payment_token,
                                        price,
                                    },
                                ),
                            );
                    }
                }
            }

            if cost > 0 {
                let mint_token = ERC20ABIDispatcher { contract_address: payment_token };
                mint_token.transfer_from(buyer, self.owner(), cost);
            }
        }

        // @dev Copy of `ERC721Component::transfer_from` with 2 custom lines
        fn _transfer_with_engraving(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
        ) {
            assert(!to.is_zero(), ERC721Errors::INVALID_RECEIVER);

            let artifact_id = self.token_artifact_ids.entry(token_id).read();
            self.artifact_saving.entry(token_id).write(true); // <- @dev Custom line 1
            let previous_owner = self.erc721.update(to, token_id, get_caller_address());
            self.artifact_saving.entry(token_id).write(false); // <- @dev Custom line 2

            assert(from == previous_owner, ERC721Errors::INVALID_SENDER);
            self
                .emit(
                    Event::ArtifactPreserved(
                        ArtifactPreserved { token_id, artifact_id, from, to },
                    ),
                );
        }

        fn _wipe_artifact(ref self: ContractState, token_id: u256) {
            let previous_artifact_id = self.token_artifact_ids.entry(token_id).read();
            let artifact_id: felt252 = self.artifact_nonces.read() + 1;

            self.artifact_nonces.write(artifact_id);
            self.token_artifact_ids.entry(token_id).write(artifact_id);
            self
                .emit(
                    Event::ArtifactAssigned(
                        ArtifactAssigned { token_id, artifact_id, previous_artifact_id },
                    ),
                );
        }

        fn _engrave_artifact(
            ref self: ContractState, token_id: u256, artifact: Artifact, emit_event: bool,
        ) {
            let artifact_id: felt252 = self.token_artifact_ids.entry(token_id).read();
            assert!(artifact_id != 0, "Token does not exist");

            for new_engraving in artifact.collection {
                let nonce = self.tag_nonces.entry((artifact_id, new_engraving.tag)).read();

                let old_data = self.artifacts.entry((artifact_id, new_engraving.tag, nonce)).read();
                if old_data == new_engraving.data {
                    continue;
                }

                self.tag_nonces.entry((artifact_id, new_engraving.tag)).write(nonce + 1);
                self
                    .artifacts
                    .entry((artifact_id, new_engraving.tag, nonce + 1))
                    .write(new_engraving.data.clone());
                if emit_event {
                    self
                        .emit(
                            Event::ArtifactEngraved(
                                ArtifactEngraved {
                                    token_id,
                                    artifact_id,
                                    tag: new_engraving.tag,
                                    nonce: nonce + 1,
                                    new_data: new_engraving.data,
                                },
                            ),
                        );
                }
            }
        }

        fn _mint_and_engrave_initial_artifacts(ref self: ContractState, owner: ContractAddress) {
            self._register_tags(INITIAL_ENGRAVINGS::INITIAL_TAGS());
            self._mint(owner, 111, false); // Mint 111 tokens (1-111)

            for i in 1..=11_u256 {
                self._engrave_artifact(i, INITIAL_ENGRAVINGS::INITIAL_ARTIFACT(i), false);
            }
        }
    }
}
