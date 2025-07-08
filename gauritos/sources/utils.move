/// This module provides general-purpose utility functions 
/// to support formatting and string manipulation tasks across the Guaritos framework.
module guaritos::utils {
    use aptos_framework::string::{Self, String};
    use aptos_framework::vector;
    use aptos_framework::string_utils;
    
    /// Creates a formatted token name by appending the token name and its ID.
    public(friend) fun create_token_name_with_id (
        token_name: String,
        id: u64,
    ) : String {
        let name = string::utf8(b"");
        name.append(token_name);
        name.append(string::utf8(b" #"));
        name.append(string_utils::to_string<u64>(&id));
        name
    }
}