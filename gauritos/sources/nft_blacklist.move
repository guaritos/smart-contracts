module dao_address::nft_blacklist {
    use std::signer;
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use aptos_token_objects::property_map;

    /// Lỗi khi NFT đã tồn tại
    const E_NFT_ALREADY_EXISTS: u64 = 1;
    /// Lỗi khi không có quyền truy cập
    const E_NO_ACCESS: u64 = 2;
    /// Lỗi khi NFT không tồn tại
    const E_NFT_NOT_EXISTS: u64 = 3;
    /// Lỗi khi địa chỉ đã có trong blacklist
    const E_ADDRESS_ALREADY_BLACKLISTED: u64 = 4;
    /// Lỗi khi địa chỉ không có trong blacklist
    const E_ADDRESS_NOT_BLACKLISTED: u64 = 5;

    /// Tên collection cho NFT Blacklist
    const COLLECTION_NAME: vector<u8> = b"DAO Blacklist NFT";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Unique NFT for DAO blacklist management";
    const TOKEN_NAME: vector<u8> = b"Blacklist Authority";
    const TOKEN_DESCRIPTION: vector<u8> = b"Authority token for managing DAO blacklist";

    /// Struct lưu trữ thông tin NFT Blacklist
    struct BlacklistNFT has key {
        /// Địa chỉ sở hữu NFT
        owner: address,
        /// Danh sách blacklist
        blacklisted_addresses: vector<address>,
        /// Token object của NFT
        token_address: address,
        /// Signer capability để quản lý collection
        signer_cap: account::SignerCapability,
    }

    /// Event khi NFT được tạo
    #[event]
    struct NFTCreated has drop, store {
        owner: address,
        token_address: address,
        timestamp: u64,
    }

    /// Event khi địa chỉ được thêm vào blacklist
    #[event]
    struct AddressBlacklisted has drop, store {
        blacklisted_address: address,
        by_owner: address,
        timestamp: u64,
    }

    /// Event khi địa chỉ được xóa khỏi blacklist
    #[event]
    struct AddressUnblacklisted has drop, store {
        unblacklisted_address: address,
        by_owner: address,
        timestamp: u64,
    }

    /// Event khi NFT được transfer
    #[event]
    struct NFTTransferred has drop, store {
        from: address,
        to: address,
        timestamp: u64,
    }

    /// Khởi tạo module (chỉ gọi 1 lần)
    fun init_module(dao: &signer) {
        // Tạo resource account để quản lý collection
        let (resource_signer, signer_cap) = account::create_resource_account(dao, b"nft_blacklist_seed");
        
        // Tạo collection
        collection::create_unlimited_collection(
            &resource_signer,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            option::none(),
            string::utf8(b"https://dao.example.com")
        );

        // Lưu signer capability
        move_to(dao, BlacklistNFT {
            owner: @0x0, // Chưa có owner
            blacklisted_addresses: vector::empty(),
            token_address: @0x0, // Chưa có token
            signer_cap,
        });
    }

    /// Tạo NFT Blacklist duy nhất (chỉ gọi được 1 lần)
    public entry fun create_blacklist_nft(creator: &signer) acquires BlacklistNFT {
        let creator_addr = signer::address_of(creator);
        
        // Kiểm tra NFT đã tồn tại chưa
        let blacklist_nft = borrow_global_mut<BlacklistNFT>(@dao_address);
        assert!(blacklist_nft.owner == @0x0, E_NFT_ALREADY_EXISTS);

        // Tạo resource signer
        let resource_signer = account::create_signer_with_capability(&blacklist_nft.signer_cap);

        // Tạo token
        let token_constructor_ref = token::create_named_token(
            &resource_signer,
            string::utf8(COLLECTION_NAME),
            string::utf8(TOKEN_DESCRIPTION),
            string::utf8(TOKEN_NAME),
            option::none(),
            string::utf8(b"https://dao.example.com/blacklist-nft")
        );

        // Lấy địa chỉ token
        let token_address = token::address_from_constructor_ref(&token_constructor_ref);

        // Tạo transfer ref để có thể transfer token
        let transfer_ref = token::generate_transfer_ref(&token_constructor_ref);
        
        // Transfer token cho creator
        let linear_transfer_ref = token::generate_linear_transfer_ref(&transfer_ref);
        token::transfer_with_ref(linear_transfer_ref, creator_addr);

        // Cập nhật thông tin NFT
        blacklist_nft.owner = creator_addr;
        blacklist_nft.token_address = token_address;

        // Emit event
        event::emit(NFTCreated {
            owner: creator_addr,
            token_address,
            timestamp: aptos_framework::timestamp::now_microseconds(),
        });
    }

    /// Thêm địa chỉ vào blacklist (chỉ owner NFT mới gọi được)
    public entry fun add_to_blacklist(owner: &signer, address_to_blacklist: address) acquires BlacklistNFT {
        let owner_addr = signer::address_of(owner);
        let blacklist_nft = borrow_global_mut<BlacklistNFT>(@dao_address);
        
        // Kiểm tra quyền sở hữu
        assert!(blacklist_nft.owner == owner_addr, E_NO_ACCESS);
        
        // Kiểm tra địa chỉ đã có trong blacklist chưa
        assert!(!vector::contains(&blacklist_nft.blacklisted_addresses, &address_to_blacklist), E_ADDRESS_ALREADY_BLACKLISTED);
        
        // Thêm vào blacklist
        vector::push_back(&mut blacklist_nft.blacklisted_addresses, address_to_blacklist);

        // Emit event
        event::emit(AddressBlacklisted {
            blacklisted_address: address_to_blacklist,
            by_owner: owner_addr,
            timestamp: aptos_framework::timestamp::now_microseconds(),
        });
    }

    /// Xóa địa chỉ khỏi blacklist (chỉ owner NFT mới gọi được)
    public entry fun remove_from_blacklist(owner: &signer, address_to_remove: address) acquires BlacklistNFT {
        let owner_addr = signer::address_of(owner);
        let blacklist_nft = borrow_global_mut<BlacklistNFT>(@dao_address);
        
        // Kiểm tra quyền sở hữu
        assert!(blacklist_nft.owner == owner_addr, E_NO_ACCESS);
        
        // Tìm và xóa địa chỉ khỏi blacklist
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

    /// Transfer NFT sang owner mới
    public entry fun transfer_nft(current_owner: &signer, new_owner: address) acquires BlacklistNFT {
        let current_owner_addr = signer::address_of(current_owner);
        let blacklist_nft = borrow_global_mut<BlacklistNFT>(@dao_address);
        
        // Kiểm tra quyền sở hữu
        assert!(blacklist_nft.owner == current_owner_addr, E_NO_ACCESS);
        
        // Transfer token (cần implement token transfer logic)
        // Cập nhật owner
        blacklist_nft.owner = new_owner;

        // Emit event
        event::emit(NFTTransferred {
            from: current_owner_addr,
            to: new_owner,
            timestamp: aptos_framework::timestamp::now_microseconds(),
        });
    }

    /// Kiểm tra địa chỉ có trong blacklist không
    #[view]
    public fun is_blacklisted(address_to_check: address): bool acquires BlacklistNFT {
        let blacklist_nft = borrow_global<BlacklistNFT>(@dao_address);
        vector::contains(&blacklist_nft.blacklisted_addresses, &address_to_check)
    }

    /// Lấy owner hiện tại của NFT
    #[view]
    public fun get_owner(): address acquires BlacklistNFT {
        let blacklist_nft = borrow_global<BlacklistNFT>(@dao_address);
        blacklist_nft.owner
    }

    /// Lấy địa chỉ token NFT
    #[view]
    public fun get_token_address(): address acquires BlacklistNFT {
        let blacklist_nft = borrow_global<BlacklistNFT>(@dao_address);
        blacklist_nft.token_address
    }

    /// Lấy danh sách blacklist
    #[view]
    public fun get_blacklisted_addresses(): vector<address> acquires BlacklistNFT {
        let blacklist_nft = borrow_global<BlacklistNFT>(@dao_address);
        blacklist_nft.blacklisted_addresses
    }

    /// Kiểm tra NFT đã được tạo chưa
    #[view]
    public fun nft_exists(): bool acquires BlacklistNFT {
        let blacklist_nft = borrow_global<BlacklistNFT>(@dao_address);
        blacklist_nft.owner != @0x0
    }

    /// Lấy số lượng địa chỉ trong blacklist
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