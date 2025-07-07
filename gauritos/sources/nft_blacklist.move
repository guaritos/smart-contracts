/// This module defines a system for issuing NFT-based blacklists.
/// Each account can create its own NFT collection to flag addresses
/// considered malicious or risky.
///
/// NFTs are uniquely minted per blacklisted address, using a consistent
/// naming convention (e.g., "Blacklist: 0xabc...") and stored in the
/// collection created by the caller.
module guaritos::nft_blacklist {
    use aptos_framework::account::{Account, SignerCapability, create_resource_account, create_signer_with_capability};
    use aptos_framework::event;
    use aptos_std::table::{Self, Table};
    use aptos_token::property_map;
    use aptos_token_objects::collection::{create_unlimited_collection};
    use aptos_token_objects::token::{create_named_token};
    use std::debug;
    use std::signer::{Self};
    use std::string_utils::{Self};
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::object::{Self, address_from_constructor_ref, generate_transfer_ref, generate_linear_transfer_ref, transfer_with_ref};
    use std::vector;
    use guaritos::nft_blacklist_events;

    /// Error when NFT already exists
    const ENFT_ALREADY_EXISTS: u64 = 1;

    /// Error when no access permission
    const ENO_ACCESS: u64 = 2;

    /// Error when NFT does not exist
    const ENFT_NOT_EXISTS: u64 = 3;

    /// Error when address is already blacklisted
    const EADDRESS_ALREADY_BLACKLISTED: u64 = 4;
    
    /// Error when address is not blacklisted
    const EADDRESS_NOT_BLACKLISTED: u64 = 5;

    /// Collection name for NFT Blacklist
    const COLLECTION_NAME: vector<u8> = b"Guaritos Blacklist Collection";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Unique NFT for DAO blacklist management";
    const TOKEN_NAME: vector<u8> = b"Blacklist Authority";
    const TOKEN_DESCRIPTION: vector<u8> = b"Authority token for managing DAO blacklist";

    /// Metadata constants for the default NFT Blacklist collection managed by the DAO
    const DAO_TOKEN_NAME: vector<u8> = b"Guaritos Blacklist";
    const DAO_TOKEN_DESCRIPTION: vector<u8> = b"Unique NFT collection for Guaritos DAO blacklist management";

    /// Resource account seed for creating the blacklist registry
    const RESOURCE_ACCOUNT_SEED: vector<u8> = b"nft_blacklist_seed";

    /// Base URI for the collection
    const BASE_URI: vector<u8> = b"https://guaritos.vercel.app";

    /// NFT URI for individual tokens
    const NFT_URI: vector<u8> = b"https://guaritos.vercel.app/blacklist-nft";

    /// Initial count value
    const INITIAL_COUNT: u64 = 0;

    /// Count increment value
    const COUNT_INCREMENT: u64 = 1;
    
    /// Struct for storing NFT Blacklist information
    struct Blacklist has key {
        /// Address that owns the NFT
        owner: address,
        /// Blacklist addresses
        addresses: Table<address, bool>,
        /// Token object of the NFT
        token_address: address,
    }

    /// Global resource for managing collections
    struct BlacklistRegistry has key {
        /// Signer capability to manage collection
        signer_cap: SignerCapability,
        /// Collection created flag
        collection_created: bool,
        /// Count of created blacklists
        count: u64,
    }

    /// Initialize module (only called once)
    fun init_module(dao: &signer) {
        let (resource_signer, signer_cap) = create_resource_account(dao, RESOURCE_ACCOUNT_SEED);
        
        let registry = BlacklistRegistry {
            signer_cap,
            collection_created: true,
            count: INITIAL_COUNT,
        };

        let dao_blacklist_collection_constructor_ref = create_unlimited_collection(
            &resource_signer,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            option::none(),
            string::utf8(BASE_URI)
        );

        let dao_blacklist_collection_address = address_from_constructor_ref(&dao_blacklist_collection_constructor_ref);
        
        let transfer_ref = generate_transfer_ref(&dao_blacklist_collection_constructor_ref);
        let linear_transfer_ref = generate_linear_transfer_ref(&transfer_ref);
        transfer_with_ref(linear_transfer_ref, signer::address_of(dao));

        // Create first Blacklist NFT for the DAO
        let dao_blacklist_constructor_ref = create_named_token(
            &resource_signer,
            string::utf8(COLLECTION_NAME),
            string::utf8(DAO_TOKEN_DESCRIPTION),
            string::utf8(DAO_TOKEN_NAME),
            option::none(),
            string::utf8(NFT_URI)
        );

        let token_address = address_from_constructor_ref(&dao_blacklist_constructor_ref);
        let transfer_ref = generate_transfer_ref(&dao_blacklist_constructor_ref);
        let linear_transfer_ref = generate_linear_transfer_ref(&transfer_ref);
        transfer_with_ref(linear_transfer_ref, signer::address_of(dao));

        registry.count = registry.count + COUNT_INCREMENT;
        
        move_to(dao, Blacklist {
            owner: signer::address_of(dao),
            addresses: table::new<address, bool>(),
            token_address,
        });

        move_to(dao, registry);
    }

    /// Create the shared collection (can be called by anyone, but only once)
    fun ensure_collection_exists(registry: &mut BlacklistRegistry) {
        if (!registry.collection_created) {
            let resource_signer = create_signer_with_capability(&registry.signer_cap);
            
            create_unlimited_collection(
                &resource_signer,
                string::utf8(COLLECTION_DESCRIPTION),
                string::utf8(COLLECTION_NAME),
                option::none(),
                string::utf8(BASE_URI)
            );

            registry.collection_created = true;
        }
    }

    /// Create unique NFT Blacklist for the caller
    public entry fun create_blacklist(creator: &signer, dao_addr: address) acquires BlacklistRegistry {
        let creator_addr = signer::address_of(creator);

        assert!(!exists<Blacklist>(creator_addr), ENFT_ALREADY_EXISTS);
        
        let registry = borrow_global_mut<BlacklistRegistry>(dao_addr);
        ensure_collection_exists(registry);
        
        let resource_signer = create_signer_with_capability(&registry.signer_cap);
        let count_after_creation = registry.count + COUNT_INCREMENT;
        let name = string::utf8(TOKEN_NAME);
        name.append(string::utf8(b" #"));
        name.append(string_utils::to_string<u64>(&count_after_creation));

        let token_constructor_ref = create_named_token(
            &resource_signer,
            string::utf8(COLLECTION_NAME),
            string::utf8(TOKEN_DESCRIPTION),
            name,
            option::none(),
            string::utf8(NFT_URI)
        );

        let token_address = address_from_constructor_ref(&token_constructor_ref);
        let transfer_ref = generate_transfer_ref(&token_constructor_ref);
        let linear_transfer_ref = generate_linear_transfer_ref(&transfer_ref);

        transfer_with_ref(linear_transfer_ref, creator_addr);
        
        registry.count = count_after_creation;

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

    /// Add address to blacklist (only NFT owner can call)
    public entry fun add_to_blacklist(owner: &signer, target: address) acquires Blacklist {
        let owner_addr = signer::address_of(owner);

        assert!(exists<Blacklist>(owner_addr), ENFT_NOT_EXISTS);

        let blacklist_nft = borrow_global_mut<Blacklist>(owner_addr);
        
        assert!(blacklist_nft.owner == owner_addr, ENO_ACCESS);
        assert!(!blacklist_nft.addresses.contains(target), EADDRESS_ALREADY_BLACKLISTED);
        
        blacklist_nft.addresses.add(target, true);
    
        nft_blacklist_events::emit_address_blacklisted_event(
            target,
            owner_addr,
            aptos_framework::timestamp::now_microseconds(),
        );
    }

    /// Remove address from blacklist (only NFT owner can call)
    public entry fun remove_from_blacklist(owner: &signer, target: address) acquires Blacklist {
        let owner_addr = signer::address_of(owner);
        let blacklist_nft = borrow_global_mut<Blacklist>(owner_addr);
        
        assert!(blacklist_nft.owner == owner_addr, ENO_ACCESS);
        
        let found= blacklist_nft.addresses.contains(target);
        assert!(found, EADDRESS_NOT_BLACKLISTED);
        
        blacklist_nft.addresses.remove(target);

        nft_blacklist_events::emit_address_unblacklisted_event(
            target,
            owner_addr,
            aptos_framework::timestamp::now_microseconds(),
        );
    }

    //////////////////// All view functions ////////////////////////////////

    /// Check if address is in blacklist
    #[view]
    public fun is_blacklisted(owner: address, address: address): bool acquires Blacklist {
        let blacklist_nft = borrow_global<Blacklist>(owner);
        assert!(exists<Blacklist>(owner), ENFT_NOT_EXISTS);
        
        blacklist_nft.addresses.contains(address)
    }

    // /// Get NFT token address
    // /// Get NFT token address
    // #[view]
    // public fun get_token_address(): address acquires Blacklist {
    //     let blacklist_nft = borrow_global<Blacklist>(@guaritos);
    //     blacklist_nft.token_address
    // }

    // /// Get blacklist addresses
    // /// Get blacklist addresses
    // #[view]
    // public fun get_addresses(): vector<address> acquires Blacklist {
    //     let blacklist_nft = borrow_global<Blacklist>(@guaritos);
    //     blacklist_nft.addresses
    // }

    /// Check if NFT has been created
    #[view]
    public fun nft_exists(owner: address): bool {
        exists<Blacklist>(owner)
    }

    // /// Get number of addresses in blacklist
    // /// Get number of addresses in blacklist
    // #[view]
    // public fun get_blacklist_count(): u64 acquires Blacklist {
    //     let blacklist_nft = borrow_global<Blacklist>(@guaritos);
        
    //     blacklist_nft.addresses.length
    // }

    #[test_only]
    use aptos_framework::timestamp;

    #[test_only]
    fun setup_test(dao: &signer, creator: &signer) acquires BlacklistRegistry {
        timestamp::set_time_has_started_for_testing(dao);
        init_module(dao);
        
        let creator_addr = signer::address_of(creator);
        assert!(!exists<Blacklist>(creator_addr), INITIAL_COUNT);
        assert!(!nft_exists(creator_addr), COUNT_INCREMENT);
        assert!(exists<BlacklistRegistry>(signer::address_of(dao)), 2);
        assert!(borrow_global<BlacklistRegistry>(signer::address_of(dao)).count == COUNT_INCREMENT, 3);
    }

    #[test(dao = @0x1, creator = @0x123)]
    fun test_create_nft_success(dao: &signer, creator: &signer) acquires BlacklistRegistry, Blacklist {
        let creator_addr = signer::address_of(creator);
        let dao_addr = signer::address_of(dao);

        setup_test(dao, creator);
        
        create_blacklist(creator, dao_addr);
        
        let blacklist = borrow_global<Blacklist>(creator_addr);
        
        assert!(nft_exists(creator_addr), INITIAL_COUNT);
        assert!(blacklist.owner == creator_addr, COUNT_INCREMENT);
    }

    #[test(dao = @0x1, creator = @0x123)]
    #[expected_failure(abort_code = ENFT_ALREADY_EXISTS)]
    fun test_create_nft_twice_fails(dao: &signer, creator: &signer) acquires BlacklistRegistry {
        let dao_addr = signer::address_of(dao);

        setup_test(dao, creator);
        
        create_blacklist(creator, dao_addr);
        create_blacklist(creator, dao_addr); // This should fail since NFT already exists
    }

    #[test_only]
    public fun init_module_for_test(dao: &signer) {
        timestamp::set_time_has_started_for_testing(dao);
        init_module(dao);
    }

    // #[test(dao = @guaritos, creator = @0x123)]
    // fun test_blacklist_operations(dao: &signer, creator: &signer) acquires BlacklistRegistry {
    //     setup_test(dao, creator);
    //     create_blacklist(dao, creator);
        
    //     let address_to_blacklist = @0x456;
        
    //     // Test add to blacklist
    //     // add_to_blacklist(creator, address_to_blacklist);
    //     // assert!(is_blacklisted(address_to_blacklist), 0);
    //     // assert!(get_blacklist_count() == 1, 1);
        
    //     // // Test remove from blacklist
    //     // remove_from_blacklist(creator, address_to_blacklist);
    //     // assert!(!is_blacklisted(address_to_blacklist), 2);
    //     // assert!(get_blacklist_count() == 0, 3);
    // }
}