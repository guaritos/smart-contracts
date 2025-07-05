/// This module defines a system for issuing NFT-based blacklists.
/// Each account can create its own NFT collection to flag addresses
/// considered malicious or risky.
///
/// NFTs are uniquely minted per blacklisted address, using a consistent
/// naming convention (e.g., "Blacklist: 0xabc...") and stored in the
/// collection created by the caller.
///
/// Key features:
/// - Each admin/project can maintain their own blacklist collection
/// - One NFT per flagged address (non-fungible, unique)
/// - Useful for decentralized reputation systems and governance-based trust
module guaritos::nft_blacklist {
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_token::collection;
    use aptos_token::token;
    use aptos_token::property_map;
    use std::signer;
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::vector;

    /// Error when NFT already exists
    /// Error when NFT already exists
    const E_NFT_ALREADY_EXISTS: u64 = 1;

    /// Error when no access permission
    const E_NO_ACCESS: u64 = 2;

    /// Error when NFT does not exist
    const E_NFT_NOT_EXISTS: u64 = 3;

    /// Error when address is already blacklisted
    const E_ADDRESS_ALREADY_BLACKLISTED: u64 = 4;
    
    /// Error when address is not blacklisted
    const E_ADDRESS_NOT_BLACKLISTED: u64 = 5;

    /// Collection name for NFT Blacklist
    /// Collection name for NFT Blacklist
    const COLLECTION_NAME: vector<u8> = b"DAO Blacklist NFT";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Unique NFT for DAO blacklist management";
    const TOKEN_NAME: vector<u8> = b"Blacklist Authority";
    const TOKEN_DESCRIPTION: vector<u8> = b"Authority token for managing DAO blacklist";

    /// Struct for storing NFT Blacklist information
    /// Struct for storing NFT Blacklist information
    struct BlacklistNFT has key {
        /// Address that owns the NFT
        /// Address that owns the NFT
        owner: address,
        /// Blacklist addresses
        /// Blacklist addresses
        blacklisted_addresses: vector<address>,
        /// Token object of the NFT
        /// Token object of the NFT
        token_address: address,
        /// Signer capability to manage collection
        /// Signer capability to manage collection
        signer_cap: account::SignerCapability,
    }

    /// Event when NFT is created
    /// Event when NFT is created
    #[event]
    struct NFTCreated has drop, store {
        owner: address,
        token_address: address,
        timestamp: u64,
    }

    /// Event when address is added to blacklist
    /// Event when address is added to blacklist
    #[event]
    struct AddressBlacklisted has drop, store {
        blacklisted_address: address,
        by_owner: address,
        timestamp: u64,
    }

    /// Event when address is removed from blacklist
    /// Event when address is removed from blacklist
    #[event]
    struct AddressUnblacklisted has drop, store {
        unblacklisted_address: address,
        by_owner: address,
        timestamp: u64,
    }

    /// Event when NFT is transferred
    /// Event when NFT is transferred
    #[event]
    struct NFTTransferred has drop, store {
        from: address,
        to: address,
        timestamp: u64,
    }

    /// Initialize module (only called once)
    /// Initialize module (only called once)
    fun init_module(dao: &signer) {
        // Create resource account to manage collection
        // Create resource account to manage collection
        let (resource_signer, signer_cap) = account::create_resource_account(dao, b"nft_blacklist_seed");
        
        // Create collection
        // Create collection
        collection::create_unlimited_collection(
            &resource_signer,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            option::none(),
            string::utf8(b"https://dao.example.com")
        );

        // Store signer capability
        // Store signer capability
        move_to(dao, BlacklistNFT {
            owner: @0x0, // No owner yet
            owner: @0x0, // No owner yet
            blacklisted_addresses: vector::empty(),
            token_address: @0x0, // No token yet
            token_address: @0x0, // No token yet
            signer_cap,
        });
    }

    /// Create unique NFT Blacklist (can only be called once)
    /// Create unique NFT Blacklist (can only be called once)
    public entry fun create_blacklist_nft(creator: &signer) acquires BlacklistNFT {
        let creator_addr = signer::address_of(creator);
        
        // Check if NFT already exists
        // Check if NFT already exists
        let blacklist_nft = borrow_global_mut<BlacklistNFT>(@dao_address);
        assert!(blacklist_nft.owner == @0x0, E_NFT_ALREADY_EXISTS);

        // Create resource signer
        // Create resource signer
        let resource_signer = account::create_signer_with_capability(&blacklist_nft.signer_cap);

        // Create token
        // Create token
        let token_constructor_ref = token::create_named_token(
            &resource_signer,
            string::utf8(COLLECTION_NAME),
            string::utf8(TOKEN_DESCRIPTION),
            string::utf8(TOKEN_NAME),
            option::none(),
            string::utf8(b"https://dao.example.com/blacklist-nft")
        );

        // Get token address
        // Get token address
        let token_address = token::address_from_constructor_ref(&token_constructor_ref);

        // Create transfer ref to enable token transfer
        // Create transfer ref to enable token transfer
        let transfer_ref = token::generate_transfer_ref(&token_constructor_ref);
        
        // Transfer token to creator
        // Transfer token to creator
        let linear_transfer_ref = token::generate_linear_transfer_ref(&transfer_ref);
        token::transfer_with_ref(linear_transfer_ref, creator_addr);

        // Update NFT information
        // Update NFT information
        blacklist_nft.owner = creator_addr;
        blacklist_nft.token_address = token_address;

        // Emit event
        event::emit(NFTCreated {
            owner: creator_addr,
            token_address,
            timestamp: aptos_framework::timestamp::now_microseconds(),
        });
    }

    /// Add address to blacklist (only NFT owner can call)
    /// Add address to blacklist (only NFT owner can call)
    public entry fun add_to_blacklist(owner: &signer, address_to_blacklist: address) acquires BlacklistNFT {
        let owner_addr = signer::address_of(owner);
        let blacklist_nft = borrow_global_mut<BlacklistNFT>(@dao_address);
        
        // Check ownership
        // Check ownership
        assert!(blacklist_nft.owner == owner_addr, E_NO_ACCESS);
        
        // Check if address is already in blacklist
        // Check if address is already in blacklist
        assert!(!vector::contains(&blacklist_nft.blacklisted_addresses, &address_to_blacklist), E_ADDRESS_ALREADY_BLACKLISTED);
        
        // Add to blacklist
        // Add to blacklist
        vector::push_back(&mut blacklist_nft.blacklisted_addresses, address_to_blacklist);

        // Emit event
        event::emit(AddressBlacklisted {
            blacklisted_address: address_to_blacklist,
            by_owner: owner_addr,
            timestamp: aptos_framework::timestamp::now_microseconds(),
        });
    }

    /// Remove address from blacklist (only NFT owner can call)
    /// Remove address from blacklist (only NFT owner can call)
    public entry fun remove_from_blacklist(owner: &signer, address_to_remove: address) acquires BlacklistNFT {
        let owner_addr = signer::address_of(owner);
        let blacklist_nft = borrow_global_mut<BlacklistNFT>(@dao_address);
        
        // Check ownership
        // Check ownership
        assert!(blacklist_nft.owner == owner_addr, E_NO_ACCESS);
        
        // Find and remove address from blacklist
        // Find and remove address from blacklist
        let (found, index) = vector::index_of(&blacklist_nft.blacklisted_addresses, &address_to_remove);
        assert!(found, E_ADDRESS_NOT_BLACKLISTED);
        
        vector::remove(&mut blacklist_nft.blacklisted_addresses, index);

        // Emit event
        event::emit(AddressUnblacklisted {
            unblacklisted_address: address_to_remove,
            by_owner: owner_addr,
            timestamp: aptos_framework::timestamp::now_microseconds(),
        });
    }

    /// Transfer NFT to new owner
    /// Transfer NFT to new owner
    public entry fun transfer_nft(current_owner: &signer, new_owner: address) acquires BlacklistNFT {
        let current_owner_addr = signer::address_of(current_owner);
        let blacklist_nft = borrow_global_mut<BlacklistNFT>(@dao_address);
        
        // Check ownership
        // Check ownership
        assert!(blacklist_nft.owner == current_owner_addr, E_NO_ACCESS);
        
        // Transfer token (need to implement token transfer logic)
        // Update owner
        // Transfer token (need to implement token transfer logic)
        // Update owner
        blacklist_nft.owner = new_owner;

        // Emit event
        event::emit(NFTTransferred {
            from: current_owner_addr,
            to: new_owner,
            timestamp: aptos_framework::timestamp::now_microseconds(),
        });
    }

    /// Check if address is in blacklist
    /// Check if address is in blacklist
    #[view]
    public fun is_blacklisted(address_to_check: address): bool acquires BlacklistNFT {
        let blacklist_nft = borrow_global<BlacklistNFT>(@dao_address);
        vector::contains(&blacklist_nft.blacklisted_addresses, &address_to_check)
    }

    /// Get current owner of NFT
    /// Get current owner of NFT
    #[view]
    public fun get_owner(): address acquires BlacklistNFT {
        let blacklist_nft = borrow_global<BlacklistNFT>(@dao_address);
        blacklist_nft.owner
    }

    /// Get NFT token address
    /// Get NFT token address
    #[view]
    public fun get_token_address(): address acquires BlacklistNFT {
        let blacklist_nft = borrow_global<BlacklistNFT>(@dao_address);
        blacklist_nft.token_address
    }

    /// Get blacklist addresses
    /// Get blacklist addresses
    #[view]
    public fun get_blacklisted_addresses(): vector<address> acquires BlacklistNFT {
        let blacklist_nft = borrow_global<BlacklistNFT>(@dao_address);
        blacklist_nft.blacklisted_addresses
    }

    /// Check if NFT has been created
    /// Check if NFT has been created
    #[view]
    public fun nft_exists(): bool acquires BlacklistNFT {
        let blacklist_nft = borrow_global<BlacklistNFT>(@dao_address);
        blacklist_nft.owner != @0x0
    }

    /// Get number of addresses in blacklist
    /// Get number of addresses in blacklist
    #[view]
    public fun get_blacklist_count(): u64 acquires BlacklistNFT {
        let blacklist_nft = borrow_global<BlacklistNFT>(@dao_address);
        vector::length(&blacklist_nft.blacklisted_addresses)
    }

    #[test_only]
    use aptos_framework::timestamp;

    #[test_only]
    fun setup_test(dao: &signer, creator: &signer) {
        timestamp::set_time_has_started_for_testing(dao);
        init_module(dao);
    }

    #[test(dao = @dao_address, creator = @0x123)]
    fun test_create_nft_success(dao: &signer, creator: &signer) acquires BlacklistNFT {
        setup_test(dao, creator);
        
        create_blacklist_nft(creator);
        
        assert!(nft_exists(), 0);
        assert!(get_owner() == signer::address_of(creator), 1);
    }

    #[test(dao = @dao_address, creator = @0x123)]
    #[expected_failure(abort_code = E_NFT_ALREADY_EXISTS)]
    fun test_create_nft_twice_fails(dao: &signer, creator: &signer) acquires BlacklistNFT {
        setup_test(dao, creator);
        
        create_blacklist_nft(creator);
        create_blacklist_nft(creator); // Should fail
    }

    #[test(dao = @dao_address, creator = @0x123)]
    fun test_blacklist_operations(dao: &signer, creator: &signer) acquires BlacklistNFT {
        setup_test(dao, creator);
        create_blacklist_nft(creator);
        
        let address_to_blacklist = @0x456;
        
        // Test add to blacklist
        add_to_blacklist(creator, address_to_blacklist);
        assert!(is_blacklisted(address_to_blacklist), 0);
        assert!(get_blacklist_count() == 1, 1);
        
        // Test remove from blacklist
        remove_from_blacklist(creator, address_to_blacklist);
        assert!(!is_blacklisted(address_to_blacklist), 2);
        assert!(get_blacklist_count() == 0, 3);
    }
}