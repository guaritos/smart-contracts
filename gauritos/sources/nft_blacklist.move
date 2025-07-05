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
    use std::signer::{Self};
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::object::{Self, address_from_constructor_ref, generate_transfer_ref, generate_linear_transfer_ref, transfer_with_ref};
    use std::vector;

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
    const COLLECTION_NAME: vector<u8> = b"Guaritos Blacklist NFT";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Unique NFT for DAO blacklist management";
    const TOKEN_NAME: vector<u8> = b"Blacklist Authority";
    const TOKEN_DESCRIPTION: vector<u8> = b"Authority token for managing DAO blacklist";

    /// Registry address for the NFT Blacklist
    /// This will be changed to dao address in production
    /// For now, we use a fixed address for testing purposes
    const REGISTRY_ADDRESS: address = @0x1;

    /// Struct for storing NFT Blacklist information
    struct BlacklistNFT has key {
        /// Address that owns the NFT
        owner: address,
        /// Blacklist addresses
        blacklisted_addresses: Table<address, bool>,
        /// Token object of the NFT
        token_address: address,
    }

    /// Global resource for managing collections
    struct BlacklistRegistry has key {
        /// Signer capability to manage collection
        signer_cap: SignerCapability,
        /// Collection created flag
        collection_created: bool,
    }

    /// Event when NFT is created
    #[event]
    struct NFTCreated has drop, store {
        owner: address,
        token_address: address,
        timestamp: u64,
    }

    /// Event when address is added to blacklist
    #[event]
    struct AddressBlacklisted has drop, store {
        blacklisted_address: address,
        owner: address,
        timestamp: u64,
    }

    /// Event when address is removed from blacklist
    #[event]
    struct AddressUnblacklisted has drop, store {
        unblacklisted_address: address,
        owner: address,
        timestamp: u64,
    }

    /// Event when NFT is transferred
    #[event]
    struct NFTTransferred has drop, store {
        from: address,
        to: address,
        timestamp: u64,
    }

    /// Initialize module (only called once)
    fun init_module(dao: &signer) {
        let (resource_signer, signer_cap) = create_resource_account(dao, b"nft_blacklist_seed");
        
        move_to(dao, BlacklistRegistry {
            signer_cap,
            collection_created: false,
        });
    }

    /// Create the shared collection (can be called by anyone, but only once)
    fun ensure_collection_exists() acquires BlacklistRegistry {
        let registry = borrow_global_mut<BlacklistRegistry>(REGISTRY_ADDRESS);
        
        if (!registry.collection_created) {
            let resource_signer = create_signer_with_capability(&registry.signer_cap);
            
            create_unlimited_collection(
                &resource_signer,
                string::utf8(COLLECTION_DESCRIPTION),
                string::utf8(COLLECTION_NAME),
                option::none(),
                string::utf8(b"https://guaritos.vercel.app")
            );
            
            registry.collection_created = true;
        }
    }

    /// Create unique NFT Blacklist for the caller
    public entry fun create_blacklist_nft(creator: &signer) acquires BlacklistRegistry {
        let creator_addr = signer::address_of(creator);
        
        assert!(!exists<BlacklistNFT>(creator_addr), ENFT_ALREADY_EXISTS);
        
        ensure_collection_exists();
        
        let registry = borrow_global<BlacklistRegistry>(REGISTRY_ADDRESS);
        let resource_signer = create_signer_with_capability(&registry.signer_cap);

        let token_constructor_ref = create_named_token(
            &resource_signer,
            string::utf8(COLLECTION_NAME),
            string::utf8(TOKEN_DESCRIPTION),
            string::utf8(TOKEN_NAME),
            option::none(),
            string::utf8(b"https://dao.example.com/blacklist-nft")
        );

        let token_address = address_from_constructor_ref(&token_constructor_ref);
        let transfer_ref = generate_transfer_ref(&token_constructor_ref);
        let linear_transfer_ref = generate_linear_transfer_ref(&transfer_ref);

        transfer_with_ref(linear_transfer_ref, creator_addr);

        move_to(creator, BlacklistNFT {
            owner: creator_addr,
            blacklisted_addresses: table::new<address, bool>(),
            token_address,
        });

        event::emit(NFTCreated {
            owner: creator_addr,
            token_address,
            timestamp: aptos_framework::timestamp::now_microseconds(),
        });
    }

    /// Add address to blacklist (only NFT owner can call)
    public entry fun add_to_blacklist(owner: &signer, address_to_blacklist: address) acquires BlacklistNFT {
        let owner_addr = signer::address_of(owner);

        assert!(exists<BlacklistNFT>(owner_addr), ENFT_NOT_EXISTS);

        let blacklist_nft = borrow_global_mut<BlacklistNFT>(owner_addr);
        
        assert!(blacklist_nft.owner == owner_addr, ENO_ACCESS);
        assert!(!blacklist_nft.blacklisted_addresses.contains(address_to_blacklist), EADDRESS_ALREADY_BLACKLISTED);
        
        blacklist_nft.blacklisted_addresses.add(address_to_blacklist, true);

        event::emit(AddressBlacklisted {
            blacklisted_address: address_to_blacklist,
            owner: owner_addr,
            timestamp: aptos_framework::timestamp::now_microseconds(),
        });
    }

    // /// Remove address from blacklist (only NFT owner can call)
    // /// Remove address from blacklist (only NFT owner can call)
    // public entry fun remove_from_blacklist(owner: &signer, address_to_remove: address) acquires BlacklistNFT {
    //     let owner_addr = signer::address_of(owner);
    //     let blacklist_nft = borrow_global_mut<BlacklistNFT>(@guaritos);
        
    //     // Check ownership
    //     // Check ownership
    //     assert!(blacklist_nft.owner == owner_addr, ENO_ACCESS);
        
    //     // Find and remove address from blacklist
    //     // Find and remove address from blacklist
    //     let (found, index) = vector::index_of(&blacklist_nft.blacklisted_addresses, &address_to_remove);
    //     assert!(found, EADDRESS_NOT_BLACKLISTED);
        
    //     vector::remove(&mut blacklist_nft.blacklisted_addresses, index);

    //     // Emit event
    //     event::emit(AddressUnblacklisted {
    //         unblacklisted_address: address_to_remove,
    //         owner: owner_addr,
    //         timestamp: aptos_framework::timestamp::now_microseconds(),
    //     });
    // }

    /// Transfer NFT to new owner
    /// Transfer NFT to new owner
    // public entry fun transfer_nft(current_owner: &signer, new_owner: address) acquires BlacklistNFT {
    //     let current_owner_addr = signer::address_of(current_owner);
    //     let blacklist_nft = borrow_global_mut<BlacklistNFT>(@guaritos);
        
    //     // Check ownership
    //     // Check ownership
    //     assert!(blacklist_nft.owner == current_owner_addr, ENO_ACCESS);
        
    //     // Transfer token (need to implement token transfer logic)
    //     // Update owner
    //     // Transfer token (need to implement token transfer logic)
    //     // Update owner
    //     blacklist_nft.owner = new_owner;

    //     // Emit event
    //     event::emit(NFTTransferred {
    //         from: current_owner_addr,
    //         to: new_owner,
    //         timestamp: aptos_framework::timestamp::now_microseconds(),
    //     });
    // }

    // /// Check if address is in blacklist
    // /// Check if address is in blacklist
    // #[view]
    // public fun is_blacklisted(address_to_check: address): bool acquires BlacklistNFT {
    //     let blacklist_nft = borrow_global<BlacklistNFT>(@guaritos);
    //     vector::contains(&blacklist_nft.blacklisted_addresses, &address_to_check)
    // }

    // /// Get current owner of NFT
    // /// Get current owner of NFT
    // #[view]
    // public fun get_owner(): address acquires BlacklistNFT {
    //     let blacklist_nft = borrow_global<BlacklistNFT>(@guaritos);
    //     blacklist_nft.owner
    // }

    // /// Get NFT token address
    // /// Get NFT token address
    // #[view]
    // public fun get_token_address(): address acquires BlacklistNFT {
    //     let blacklist_nft = borrow_global<BlacklistNFT>(@guaritos);
    //     blacklist_nft.token_address
    // }

    // /// Get blacklist addresses
    // /// Get blacklist addresses
    // #[view]
    // public fun get_blacklisted_addresses(): vector<address> acquires BlacklistNFT {
    //     let blacklist_nft = borrow_global<BlacklistNFT>(@guaritos);
    //     blacklist_nft.blacklisted_addresses
    // }

    // /// Check if NFT has been created
    // /// Check if NFT has been created
    // #[view]
    // public fun nft_exists(): bool acquires BlacklistNFT {
    //     let blacklist_nft = borrow_global<BlacklistNFT>(@guaritos);
    //     blacklist_nft.owner != @0x0
    // }

    // /// Get number of addresses in blacklist
    // /// Get number of addresses in blacklist
    // #[view]
    // public fun get_blacklist_count(): u64 acquires BlacklistNFT {
    //     let blacklist_nft = borrow_global<BlacklistNFT>(@guaritos);
        
    //     blacklist_nft.blacklisted_addresses.length
    // }

    #[test_only]
    use aptos_framework::timestamp;

    #[test_only]
    fun setup_test(dao: &signer, creator: &signer) {
        timestamp::set_time_has_started_for_testing(dao);
        init_module(dao);
    }

    #[test(dao = @0x1, creator = @0x123)]
    fun test_create_nft_success(dao: &signer, creator: &signer) acquires BlacklistRegistry {
        setup_test(dao, creator);
        
        create_blacklist_nft(creator);
        
        // assert!(nft_exists(), 0);
        // assert!(get_owner() == signer::address_of(creator), 1);
    }

    // #[test(dao = @guaritos, creator = @0x123)]
    // #[expected_failure(abort_code = ENFT_ALREADY_EXISTS)]
    // fun test_create_nft_twice_fails(dao: &signer, creator: &signer) acquires BlacklistRegistry {
    //     setup_test(dao, creator);
        
    //     create_blacklist_nft(creator);
    //     create_blacklist_nft(creator); // Should fail
    // }

    // #[test(dao = @guaritos, creator = @0x123)]
    // fun test_blacklist_operations(dao: &signer, creator: &signer) acquires BlacklistRegistry {
    //     setup_test(dao, creator);
    //     create_blacklist_nft(creator);
        
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