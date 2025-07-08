module guaritos::constants {
    use aptos_framework::string::{Self, String};
    use aptos_framework::vector;

    /// Default dao name for Guaritos DAO
    const GUARITOS_DEFAULT_DAO_NAME: vector<u8> = b"Guaritos DAO";

    /// Default collection name for Guaritos DAO
    const GUARITOS_DEFAULT_COLLECTION_NAME: vector<u8> = b"Guaritos DAO Collection";

    /// Default token name for Guaritos DAO
    const GUARITOS_DEFAULT_TOKEN_NAME: vector<u8> = b"Guaritos DAO Token";

    /// Default threshold for resolving a proposal
    const GUARITOS_DEFAULT_THRESHOLD: u64 = 2; // Minimum votes required to resolve a proposal

    /// Default voting duration for proposals
    const GUARITOS_DEFAULT_VOTING_DURATION: u64 = 604800; // 7 days in seconds

    /// Default minimum required voting power for a proposer to create a proposal
    const GUARITOS_DEFAULT_MIN_REQUIRED_PROPOSER_VOTING_POWER: u64 = 1; // Minimum voting power required to create a proposal

    /// Default metadata for the NFT Blacklist collection managed by the DAO
    const GUARITOS_DEFAULT_NFT_BLACKLIST_COLLECTION_NAME: vector<u8> = b"Guaritos Blacklist Collection";
    const GUARITOS_DEFAULT_NFT_BLACKLIST_COLLECTION_DESCRIPTION: vector<u8> = b"Unique NFT for DAO blacklist management";
    const GUARITOS_DEFAULT_NFT_BLACKLIST_TOKEN_NAME: vector<u8> = b"Guaritos Blacklist Token";
    const GUARITOS_DEFAULT_NFT_BLACKLIST_TOKEN_DESCRIPTION: vector<u8> = b"Authority token for managing DAO blacklist";
    const GUARITOS_DEFAULT_BASE_URI: vector<u8> = b"https://guaritos.vercel.app";
    const GUARITOS_DEFAULT_NFT_URI: vector<u8> = b"https://guaritos.vercel.app/blacklist-nft";

    /// Default initial count for the NFT Blacklist
    const GUARITOS_DEFAULT_NFT_BLACKLIST_INITIAL_COUNT: u64 = 0;

    /// Default increment for the NFT Blacklist count
    const GUARITOS_DEFAULT_NFT_BLACKLIST_COUNT_INCREMENT: u64 = 1;

    public fun get_default_dao_name(): String {
        string::utf8(GUARITOS_DEFAULT_DAO_NAME)
    }

    public fun get_default_collection_name(): String {
        string::utf8(GUARITOS_DEFAULT_COLLECTION_NAME)
    }

    public fun get_default_token_name(): String {
        string::utf8(GUARITOS_DEFAULT_TOKEN_NAME)
    }

    public fun get_default_threshold(): u64 {
        GUARITOS_DEFAULT_THRESHOLD
    }

    public fun get_default_voting_duration(): u64 {
        GUARITOS_DEFAULT_VOTING_DURATION
    }

    public fun get_default_min_required_proposer_voting_power(): u64 {
        GUARITOS_DEFAULT_MIN_REQUIRED_PROPOSER_VOTING_POWER
    }

    public fun get_default_nft_blacklist_collection_name(): String {
        string::utf8(GUARITOS_DEFAULT_NFT_BLACKLIST_COLLECTION_NAME)
    }

    public fun get_default_nft_blacklist_collection_description(): String {
        string::utf8(GUARITOS_DEFAULT_NFT_BLACKLIST_COLLECTION_DESCRIPTION)
    }

    public fun get_default_nft_blacklist_token_name(): String {
        string::utf8(GUARITOS_DEFAULT_NFT_BLACKLIST_TOKEN_NAME)
    }

    public fun get_default_nft_blacklist_token_description(): String {
        string::utf8(GUARITOS_DEFAULT_NFT_BLACKLIST_TOKEN_DESCRIPTION)
    }

    public fun get_default_base_uri(): String {
        string::utf8(GUARITOS_DEFAULT_BASE_URI)
    }

    public fun get_default_nft_blacklist_initial_count(): u64 {
        GUARITOS_DEFAULT_NFT_BLACKLIST_INITIAL_COUNT
    }

    public fun get_default_nft_blacklist_count_increment(): u64 {
        GUARITOS_DEFAULT_NFT_BLACKLIST_COUNT_INCREMENT
    }

    public fun get_default_nft_uri(): String {
        string::utf8(GUARITOS_DEFAULT_NFT_URI)
    }
}