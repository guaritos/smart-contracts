/// NFT-based blacklist system for flagging malicious addresses
/// Each account can create one NFT to manage their blacklist
module guaritos::nft_blacklist {
    use aptos_framework::account::{SignerCapability, create_resource_account, create_signer_with_capability};
    use aptos_std::table::{Self, Table};
    use aptos_token_objects::collection::create_unlimited_collection;
    use aptos_token_objects::token::create_named_token;
    use std::signer;
    use std::option;
    use std::object::{address_from_constructor_ref, generate_transfer_ref, generate_linear_transfer_ref, transfer_with_ref};
    use guaritos::constants;
    use guaritos::nft_blacklist_events;
    use guaritos::utils;

    /// Errors
    const ENFT_ALREADY_EXISTS: u64 = 1;
    const ENO_ACCESS: u64 = 2;
    const ENFT_NOT_EXISTS: u64 = 3;
    const EADDRESS_ALREADY_BLACKLISTED: u64 = 4;
    const EADDRESS_NOT_BLACKLISTED: u64 = 5;
    const EREGISTRY_NOT_EXISTS: u64 = 6;
    const EBLACKLIST_COLLECTION_NOT_CREATED: u64 = 7;
    const EBLACKLIST_ALREADY_EXISTS: u64 = 8;

    const RESOURCE_ACCOUNT_SEED: vector<u8> = b"nft_blacklist_seed";

    struct InitFlag has key {}
    
    /// Individual blacklist NFT data
    struct Blacklist has key {
        owner: address,
        addresses: Table<address, bool>,
        token_address: address,
    }

    /// Global registry for managing shared collection
    struct BlacklistRegistry has key {
        signer_cap: SignerCapability,
        collection_created: bool,
        count: u64,
    }

    fun init_module(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        assert!(!exists<InitFlag>(admin_addr), ENFT_ALREADY_EXISTS);
        
        move_to(admin, InitFlag {});
        
        let (res_signer, _) = create_resource_account(admin, RESOURCE_ACCOUNT_SEED);

        create_blacklist_registry(&res_signer);
    }

    public entry fun create_blacklist_registry(creator: &signer) {
        let creator_addr = signer::address_of(creator);
        assert!(!exists<BlacklistRegistry>(creator_addr), ENFT_ALREADY_EXISTS);
        
        let (res_signer, res_cap) = create_resource_account(creator, RESOURCE_ACCOUNT_SEED);
        
        create_unlimited_collection(
            &res_signer,
            constants::get_default_nft_blacklist_collection_description(),
            constants::get_default_nft_blacklist_collection_name(),
            option::none(),
            constants::get_default_base_uri()
        );

        move_to(creator, BlacklistRegistry {
            signer_cap: res_cap,
            collection_created: true,
            count: constants::get_default_nft_blacklist_initial_count(),
        });
    }

    /// Create blacklist NFT for caller
    public entry fun create_blacklist(creator: &signer, registry_addr: address) acquires BlacklistRegistry {
        let creator_addr = signer::address_of(creator);
        assert!(!exists<Blacklist>(creator_addr), ENFT_ALREADY_EXISTS);
        assert!(exists<BlacklistRegistry>(registry_addr), EREGISTRY_NOT_EXISTS);
        
        let registry = borrow_global_mut<BlacklistRegistry>(registry_addr);
        let resource_signer = create_signer_with_capability(&registry.signer_cap);
        registry.count = registry.count + constants::get_default_nft_blacklist_count_increment();

        let token_constructor_ref = create_named_token(
            &resource_signer,
            constants::get_default_nft_blacklist_collection_name(),
            constants::get_default_nft_blacklist_collection_description(),
            utils::create_token_name_with_id(constants::get_default_nft_blacklist_token_name(), registry.count),
            option::none(),
            constants::get_default_nft_uri()
        );

        let token_address = address_from_constructor_ref(&token_constructor_ref);
        let transfer_ref = generate_transfer_ref(&token_constructor_ref);
        let linear_transfer_ref = generate_linear_transfer_ref(&transfer_ref);
        transfer_with_ref(linear_transfer_ref, creator_addr);

        move_to(creator, Blacklist {
            owner: creator_addr,
            addresses: table::new<address, bool>(),
            token_address,
        });

        nft_blacklist_events::emit_nft_created_event(
            creator_addr,
            token_address,
            aptos_framework::timestamp::now_microseconds(),
        );
    }

    /// Add address to blacklist (only owner)
    public entry fun add_to_blacklist(owner: &signer, target: address) acquires Blacklist {
        let owner_addr = signer::address_of(owner);
        assert!(exists<Blacklist>(owner_addr), ENFT_NOT_EXISTS);

        let blacklist = borrow_global_mut<Blacklist>(owner_addr);
        assert!(blacklist.owner == owner_addr, ENO_ACCESS);
        assert!(!table::contains(&blacklist.addresses, target), EADDRESS_ALREADY_BLACKLISTED);
        
        table::add(&mut blacklist.addresses, target, true);
        
        nft_blacklist_events::emit_address_blacklisted_event(
            target,
            owner_addr,
            aptos_framework::timestamp::now_microseconds(),
        );
    }

    /// Remove address from blacklist (only owner)
    public entry fun remove_from_blacklist(owner: &signer, target: address) acquires Blacklist {
        let owner_addr = signer::address_of(owner);
        assert!(exists<Blacklist>(owner_addr), ENFT_NOT_EXISTS);
        
        let blacklist = borrow_global_mut<Blacklist>(owner_addr);
        assert!(blacklist.owner == owner_addr, ENO_ACCESS);
        assert!(table::contains(&blacklist.addresses, target), EADDRESS_NOT_BLACKLISTED);
        
        table::remove(&mut blacklist.addresses, target);

        nft_blacklist_events::emit_address_unblacklisted_event(
            target,
            owner_addr,
            aptos_framework::timestamp::now_microseconds(),
        );
    }

    #[view]
    /// Check if address is blacklisted
    public fun is_blacklisted(owner: address, address: address): bool acquires Blacklist {
        if (!exists<Blacklist>(owner)) return false;
        let blacklist = borrow_global<Blacklist>(owner);
        table::contains(&blacklist.addresses, address)
    }

    #[view]
    /// Check if NFT exists
    public fun nft_exists(owner: address): bool {
        exists<Blacklist>(owner)
    }

    #[view]
    /// Get blacklist owner
    public fun get_owner(blacklist_addr: address): address acquires Blacklist {
        assert!(exists<Blacklist>(blacklist_addr), ENFT_NOT_EXISTS);
        borrow_global<Blacklist>(blacklist_addr).owner
    }

    #[view]
    /// Get token address
    public fun get_token_address(owner: address): address acquires Blacklist {
        assert!(exists<Blacklist>(owner), ENFT_NOT_EXISTS);
        borrow_global<Blacklist>(owner).token_address
    }

    #[test_only]
    use aptos_framework::timestamp;

    #[test_only]
    fun setup_test(registry: &signer, creator: &signer) {
        timestamp::set_time_has_started_for_testing(registry);
        create_blacklist_registry(registry);
        
        let creator_addr = signer::address_of(creator);
        assert!(!exists<Blacklist>(creator_addr), 1);
        assert!(!nft_exists(creator_addr), 2);
        assert!(exists<BlacklistRegistry>(signer::address_of(registry)), 3);
    }

    #[test_only]
    public fun init_module_for_test(admin: &signer) {
        timestamp::set_time_has_started_for_testing(admin);
        init_module(admin);
    }

    #[test(registry = @0x1, creator = @0x123)]
    fun test_create_nft_success(registry: &signer, creator: &signer) acquires BlacklistRegistry, Blacklist {
        let creator_addr = signer::address_of(creator);
        let registry_addr = signer::address_of(registry);

        setup_test(registry, creator);
        create_blacklist(creator, registry_addr);
        
        let blacklist = borrow_global<Blacklist>(creator_addr);
        assert!(nft_exists(creator_addr), 1);
        assert!(blacklist.owner == creator_addr, 2);
    }

    #[test(registry = @0x1, creator = @0x123)]
    #[expected_failure(abort_code = ENFT_ALREADY_EXISTS)]
    fun test_create_nft_twice_fails(registry: &signer, creator: &signer) acquires BlacklistRegistry {
        let registry_addr = signer::address_of(registry);
        setup_test(registry, creator);
        create_blacklist(creator, registry_addr);
        create_blacklist(creator, registry_addr);
    }

    #[test(registry = @0x1, creator = @0x123)]
    fun test_add_to_blacklist(registry: &signer, creator: &signer) acquires Blacklist, BlacklistRegistry {
        let creator_addr = signer::address_of(creator);
        let registry_addr = signer::address_of(registry);
        let target_addr = @0x456;

        setup_test(registry, creator);
        create_blacklist(creator, registry_addr);
        add_to_blacklist(creator, target_addr);

        assert!(is_blacklisted(creator_addr, target_addr), 1);
    }

    #[test(registry = @0x1, creator = @0x123)]
    fun test_remove_from_blacklist(registry: &signer, creator: &signer) acquires Blacklist, BlacklistRegistry {
        let creator_addr = signer::address_of(creator);
        let registry_addr = signer::address_of(registry);
        let target_addr = @0x456;

        setup_test(registry, creator);
        create_blacklist(creator, registry_addr);
        add_to_blacklist(creator, target_addr);
        remove_from_blacklist(creator, target_addr);

        assert!(!is_blacklisted(creator_addr, target_addr), 1);
    }

    #[test(registry = @0x1, creator = @0x123)]
    fun test_view_functions(registry: &signer, creator: &signer) acquires Blacklist, BlacklistRegistry {
        let creator_addr = signer::address_of(creator);
        let registry_addr = signer::address_of(registry);

        setup_test(registry, creator);
        create_blacklist(creator, registry_addr);

        assert!(get_owner(creator_addr) == creator_addr, 1);
        assert!(get_token_address(creator_addr) != @0x0, 2);
    }
}