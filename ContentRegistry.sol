// SPDX-License-Identifier: MIT
// Author: Astraeus | 0x00ASTRA

/*
* This contract is for registering and fetching content in a decentralized manor.
**/

pragma solidity 0.8.23;

struct ContentInfo {
    address owner;
    bytes32 contentHash;
    string title;
    string description;
    string uri;
}

struct RuleAssignment {
    bool sameTitle;
    bool sameDescription;
    bool sameUri;
}

contract ContentRegistry {
    mapping(bytes32 => ContentInfo) private registry;

    constructor(){}

    event ContentRegistered(address indexed owner, bytes32 contentHash);
    event ContentUpdated(address indexed owner, bytes32 contentHash);

    modifier onlyContentOwner(address caller, bytes32 contentHash) {
        require(caller == registry[contentHash].owner, "you are not the content owner.");
        _;
    }

    function registerContent(bytes32 contentHash_, string calldata title_, string calldata description_, string calldata uri_) external {
        ContentInfo memory contentInfo = ContentInfo(msg.sender, contentHash_, title_, description_, uri_);

        registry[contentHash_] = contentInfo;
        emit ContentRegistered(msg.sender, contentHash_);
    }

    function fetchContent(bytes32 contentHash_) public view returns(ContentInfo memory) {
        return registry[contentHash_];
    }

    function updateContentInfo(
        bytes32 contentHash_, 
        string calldata title_, 
        string calldata description_, 
        string calldata uri_
        ) 
        external onlyContentOwner(msg.sender, contentHash_) returns(ContentInfo memory) {

        RuleAssignment memory rules = _assignRules(title_, description_, uri_);

        ContentInfo memory updatedContentInfo = registry[contentHash_];

        if (!rules.sameTitle) {
            updatedContentInfo.title = title_;
        }
        if (!rules.sameDescription) {
            updatedContentInfo.description = description_;
        }
        if (!rules.sameUri) {
            updatedContentInfo.uri = uri_;
        }

        registry[contentHash_] = updatedContentInfo;
        emit ContentUpdated(msg.sender, contentHash_);

        return registry[contentHash_];
    }

    function _assignRules(string calldata title_, string calldata description_, string calldata uri_) internal pure returns(RuleAssignment memory){
        bytes32 titleHash = keccak256(abi.encodePacked(title_));       
        bool sameTitle = titleHash == keccak256(abi.encodePacked(""));
        bytes32 descriptionHash = keccak256(abi.encodePacked(description_));
        bool sameDescription = descriptionHash == keccak256(abi.encodePacked(""));
        bytes32 uriHash = keccak256(abi.encodePacked(uri_));
        bool sameUri = uriHash == keccak256(abi.encodePacked(""));

        return RuleAssignment(sameTitle, sameDescription, sameUri);
    }
}
