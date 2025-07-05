module guaritos::nft_blacklist_events {
    use aptos_framework::event;
    use std::signer;
    friend guaritos::nft_blacklist;

    #[event]
    struct NFTCreated has drop, store {
        owner: address,
        token_address: address,
        timestamp: u64,
    }
    
    #[event]
    struct AddressBlacklisted has drop, store {
        blacklisted_address: address,
        by_owner: address,
        timestamp: u64,
    }

    #[event]
    struct AddressUnblacklisted has drop, store {
        unblacklisted_address: address,
        by_owner: address,
        timestamp: u64,
    }

    #[event]
    struct NFTTransferred has drop, store {
        from: address,
        to: address,
        timestamp: u64,
    }

    public(friend) fun emit_nft_created_event(
        owner: address,
        token_address: address,
        timestamp: u64,
    ) {
        event::emit(NFTCreated {
            owner,
            token_address,
            timestamp,
        });
    }

    public(friend) fun emit_address_blacklisted_event(
        blacklisted_address: address,
        by_owner: address,
        timestamp: u64,
    ) {
        event::emit(AddressBlacklisted {
            blacklisted_address,
            by_owner,
            timestamp,
        });
    }

    public(friend) fun emit_address_unblacklisted_event(
        unblacklisted_address: address,
        by_owner: address,
        timestamp: u64,
    ) {
        event::emit(AddressUnblacklisted {
            unblacklisted_address,
            by_owner,
            timestamp,
        });
    }

    public(friend) fun emit_nft_transferred_event(
        from: address,
        to: address,
        timestamp: u64,
    ) {
        event::emit(NFTTransferred {
            from,
            to,
            timestamp,
        });
    }
}
