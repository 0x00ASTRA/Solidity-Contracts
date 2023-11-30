// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract DNS is Ownable {
    struct Domain {
        address owner;
        string did;
        string domainName;
        uint256 startTime;
        uint256 endTime;
    }

    Domain[] public domains;
    mapping(string => bool) public domainExists;
    mapping(string => Domain) public domainInfo;

    event DomainRegistered(address indexed owner, string domainName);
    event DomainTransferred(address indexed from, address indexed to, string domainName);
    event DomainRenewed(address indexed owner, string domainName, uint256 newEndTime);
    event DomainDeleted(address indexed owner, string domainName);
    event DomainUpdated(address indexed owner, string domainName);

    string public domainExtension;

    modifier onlyDomainOwner(string memory _domainName) {
        require(domainExists[_domainName], "Domain does not exist");
        require(msg.sender == domainInfo[_domainName].owner, "Only the owner can perform this action");
        _;
    }

    constructor(string memory _domainExtension) Ownable(msg.sender) {
        domainExtension = _domainExtension;
    }

    function addDomain(string memory _did, string memory _domainName, uint256 _endTime) external {
        _endTime = block.timestamp + _endTime;

        require(bytes(_did).length > 0, "DID cannot be empty");
        require(bytes(_domainName).length > 0, "Domain name cannot be empty");
        require(_endTime > block.timestamp, "End time must be in the future");
        require(domainExists[_domainName] == false, "Domain is already registered");

        string memory completeDomainName = string(abi.encodePacked(_domainName, domainExtension));

        Domain memory newDomain = Domain({
            owner: msg.sender,
            did: _did,
            domainName: completeDomainName,
            startTime: block.timestamp,
            endTime: _endTime
        });

        domains.push(newDomain);
        domainExists[completeDomainName] = true;
        domainInfo[completeDomainName] = newDomain;

        emit DomainRegistered(msg.sender, completeDomainName);
    }

    function getDomainCount() external view returns (uint256) {
        return domains.length;
    }

    function getDomain(uint256 index) external view returns (Domain memory) {
        require(index < domains.length, "Invalid index");
        return domains[index];
    }

    function resolveDomain(string memory _domainName) external view returns (Domain memory) {
        require(domainExists[string(abi.encodePacked(_domainName, domainExtension))], "Domain does not exist");
        return domainInfo[string(abi.encodePacked(_domainName, domainExtension))];
    }

    function transferDomainOwnership(string memory _domainName, address newOwner) external onlyDomainOwner(_domainName) {
        domainInfo[_domainName].owner = newOwner;
        emit DomainTransferred(msg.sender, newOwner, _domainName);
    }

    function renewDomain(string memory _domainName, uint256 newEndTime) external onlyDomainOwner(_domainName) {
        require(newEndTime > domainInfo[_domainName].endTime, "New end time must be after the current end time");
        domainInfo[_domainName].endTime = newEndTime;
        emit DomainRenewed(msg.sender, _domainName, newEndTime);
    }

    function deleteDomain(string memory _domainName) external onlyDomainOwner(_domainName) {
        delete domainInfo[_domainName];
        domainExists[_domainName] = false;
        emit DomainDeleted(msg.sender, _domainName);
    }
    
    function updateDID(string memory _domainName, string memory _newDID) external onlyDomainOwner(_domainName) {
        oldDomainInfo = domainInfo[_domainName];
        newDomainInfo = new Domain(oldDomainInfo.owner, _newDID, oldDomainInfo.domainName, oldDomainInfo.startTime, oldDomainInfo.endTime);
        domainInfo[_domainName] = newDomainInfo;
        emit DomainUpdated(msg.sender, _domainName);
    }
}
