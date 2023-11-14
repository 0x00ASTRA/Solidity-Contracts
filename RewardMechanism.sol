// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AnimusToken } from "contracts/AnimusToken.sol";
import { XPToken } from "contracts/XPToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardMechansim is Ownable(msg.sender) {
    address public _tokenAddress;
    address public _xpTokenAddress;
    AnimusToken _baseToken = AnimusToken(_tokenAddress);
    XPToken _xpToken = XPToken(_xpTokenAddress);
    uint256 private _f;
    uint256 private _t;
    uint256 private _i;
    uint256 private _j;
    uint256 public _af;
    mapping(address => uint256) private _subscriptions;
    mapping(address => uint256) private _bannedAddresses;
    mapping(address => uint256) private _bannedAtTimes;
    mapping(address => bool) private _blacklistedAddresses;
    mapping(address => uint256) private _providerFundLocks;
    address[] public _admins;
    address[] public _subscribers;
    address[] public _moderators;
    address[] public _providers;
    uint256 public _rewardEpoch;
    uint256 public _totalXPDistributed;
    uint256 public _totalTokenDistributed;
    uint256 public _lastDistributionTime;
    uint16 public _rewardLockTime;
    uint256 public _providerFee;
    uint256 public _providerRedeemValue;
    uint256 public _providerFundLockDuration;

    modifier onlyNotSubscribed(address who) {
        require(_subscriptions[who] == 0, "Subscriber is already subscribed");
        _;
    }

    modifier onlyNotBanned(address who) {
        require(!_isBanned(who), "Address is Banned");
        _;
    }

    modifier onlyNotBlacklisted(address who) {
        require(!_isBlacklisted(who), "Address is Blacklisted");
        _;
    }

    modifier onlyAdmin() {
        require(_isAdmin(msg.sender), "Not an Admin");
        _;
    }

    modifier onlyModerator() {
        require(_isModerator(msg.sender), "Not a Moderator");
        _;
    }

    modifier onlyBanTimeServed() {
        require(_banTimeServed(msg.sender), "Still Serving Time");
        _;
    }

    modifier onlyThis() {
        require(msg.sender == address(this), "Not this Contract");
        _;
    }

    modifier onlySelf(address who) {
        require(msg.sender == who, "Not the Subjectee");
        _;
    }

    modifier onlyUnlocked() {
        require(block.timestamp >= _lastDistributionTime + (uint256(_rewardLockTime) * 1 hours), "Reward distribution is locked");
        _;
    }

    modifier onlyProvider() {
        require(_isProvider(msg.sender), "Not a Provider");
        _;
    }

    modifier onlyFunded() {
        require(msg.value >= _providerFee, "Insufficient Funding");
        _;
    }

    modifier onlyUnlockedFunds(address account, uint256 unlockDate) {
        require(_providerFundLocks[account] < block.timestamp);
        _;
    }

    function _banTimeServed(address account) internal view returns(bool){
        uint256 timeStarted = _bannedAtTimes[account];
        uint256 banLength = _bannedAddresses[account];
        return block.timestamp > timeStarted + banLength;
    } 

    function _isBanned(address account) internal view returns (bool) {
        return _bannedAddresses[account] == 0;
    }

    function _isBlacklisted(address account) internal view returns(bool) {
       return _blacklistedAddresses[account];
    }

    function _isAdmin(address account) internal view returns (bool) {
        for (uint256 i = 0; i < _admins.length; i++) {
            if (_admins[i] == account) {
                return true;
            }
        }
        return false;
    }

    function _isModerator(address account) internal view returns (bool) {
        for (uint256 i = 0; i < _moderators.length; i++) {
            if (_moderators[i] == account) {
                return true;
            }
        }
        return false;
    }

    function _isProvider(address account) internal view returns(bool) {
        for (uint256 i = 0; i < _providers.length; i++) {
            if (_providers[i] == account) {
                return true;
            }
        }
        return false;
    }

    event updatedParms(uint256 time, uint256 newAf);
    event blacklisted(address account, address authority, uint256 timetamp);
    event blacklistRemoved(address account, address authority, uint256 timestamp);
    event banned(address, address authority, uint256 duration, uint256 timestamp);
    event unbanned(address account, uint256 timestamp);
    event subscribed(address account, uint256 timestamp);
    event rewardDistributed(address indexed validator, uint256 reward);
    event xpDistributed(address account, address authority, uint256 amount, bytes data);
    event authorizedUnbanned(address account, address authority, uint256 timestamp);
    event providerRevoked(address provider, address authority, uint256 timestamp);
    event providerRegistered(address provider, uint256 timestamp);
    event providerUnregistered(address provider, uint256 timestamp);
    event fundsLocked(address account, uint256 amount, uint256 unlockDate);


    constructor(address baseTokenAddress_, address xpTokenAddress_, uint256 providerFee_) {
        _tokenAddress = baseTokenAddress_;
        _xpTokenAddress = xpTokenAddress_;
        _moderators.push(address(this));
        _rewardEpoch = 1;
        _totalXPDistributed = 0;
        _totalTokenDistributed = 0;
        _providerFee = providerFee_;
        _providerRedeemValue = _providerFee - ((_providerFee * 10) / 100);

    }

    function _addAdmin(address adminAddress) internal {
        _admins.push(adminAddress);
    }

    function _removeAdmin(address adminAddress) internal returns(bool){
        for (uint i = 0; i < _admins.length; i++) {
            if (_admins[i] == adminAddress) {
                _admins[i] = _admins[_admins.length - 1];
                _admins.pop();
                return true;
            }
        }
        return false;
    }

    function _addModerator(address moderatorAddress) internal returns(bool){
        _moderators.push(moderatorAddress);
        return true;
    }

    function _removeModerator(address moderatorAddress) internal returns(bool){
        for (uint i = 0; i < _moderators.length; i++) {
            if (_moderators[i] == moderatorAddress) {
                _moderators[i] = _moderators[_moderators.length - 1];
                _moderators.pop();
                return true;
            }
        }
        return false;
    }

    function _addProvider(address providerAddress) internal returns(bool){
        _providers.push(providerAddress);
        return true;
    }

    function _removeProvider(address providerAddress) internal returns(bool){
        for (uint i = 0; i < _providers.length; i++) {
            if (_providers[i] == providerAddress) {
                _providers[i] = _providers[_providers.length - 1];
                _providers.pop();
                return true;
            }
        }
        return false;
    }

    function _lockProviderFunds(address provider) internal returns(bool){
        _providerFundLocks[provider] = block.timestamp + _providerFundLockDuration;

        emit fundsLocked(provider, _providerFee, block.timestamp + _providerFundLockDuration);

        return true;
    }

    function _calculateReward(address recipient) internal view returns (uint256) {
        // Enhanced reward calculation logic with mathematical beauty
        require(_subscriptions[recipient] > 0, "Not Subscribed");
        
        address[] memory recipients = new address[](2);
        recipients[0] = recipient;
        recipients[1] = recipient;

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;

        // Get the players xp token balance and level
        (uint256[] memory balances) = _xpToken.balanceOfBatch(recipients, ids);

        uint256 f_ = (_f * _t) / 100;
        uint256 t_ = _i / ((_j * _af) + _t / (2 *_f));
        uint256 i_ = _i * (_t / _af);
        uint256 j_ = uint256(keccak256(abi.encodePacked(f_, t_, i_))) * (f_ + (t_ * _af));
        uint256 af_ = uint256(keccak256(abi.encodePacked(_f, _t, _i, _j, _af))) % 1000;
        uint256 mod = uint256(keccak256(abi.encodePacked(address(recipient)))) * af_;
        uint256 timeMod = block.timestamp - _subscriptions[recipient];
        uint256 xpMod = balances[0];
        uint256 levelMod = balances[1];

        uint256 reward = ((
            _f * _t +
            _i / _j -
            _af +
            (uint256(keccak256(abi.encodePacked(_f, _t, _i, _j, _af, mod, xpMod * levelMod))) % 1000) + mod * timeMod
        ) * uint256(keccak256(abi.encodePacked(f_, t_, i_, j_, af_, mod, timeMod, xpMod, levelMod))) % 100) * timeMod;

        

        return reward;
    }

    function set_RewardLockTime(uint16 __rewardLockTime) external onlyAdmin {
        _rewardLockTime = __rewardLockTime;
    }

    function distributeRewards() external onlyAdmin onlyUnlocked {
        for (uint256 i = 0; i < _subscribers.length; i++) {
            address subscriber = _subscribers[i];
            uint256 reward = _calculateReward(subscriber);
            uint256 xpReward = reward * ((_af + 200 * reward) * 1000);
            uint256 tokenReward = 2 * (reward % 10000) / (((reward * 300) + _i) - 2**6);

            _xpToken.mint(subscriber, 0, xpReward, abi.encodePacked("Network Rewards: Epoch ", _rewardEpoch));
            _baseToken.mint(tokenReward, subscriber);

            emit rewardDistributed(subscriber, reward);
        }

        _lastDistributionTime = block.timestamp; // Update the last distribution time
    }

    function distributeXP(address recipient, uint256 amount, string calldata data) public onlyAdmin onlyThis onlyProvider returns(bool) {
        _xpToken.mint(recipient, 0, amount, bytes(data));

        emit xpDistributed(recipient, msg.sender, amount, bytes(data));

        return true;
    }

    function revokeProvider(address provider) public onlyOwner onlySelf(provider) onlyThis returns(bool) {
        emit providerRevoked(provider, msg.sender, block.timestamp);

        return _removeProvider(provider);
    }

    function _unregisterProvider(address provider) internal returns(bool) {
       bool removed = _removeProvider(provider);
       uint256 initialBalance = provider.balance;
       payable(provider).transfer(_providerRedeemValue);
       uint256 FinalBalance = provider.balance;
       bool recieved = FinalBalance > initialBalance;

       emit providerUnregistered(provider, block.timestamp);

       return removed && recieved;

    }

    function unregisterProvider(address provider) external onlySelf(provider) onlyUnlockedFunds(provider, _providerFundLocks[provider]) onlyAdmin onlyOwner returns(bool) {
        return _unregisterProvider(provider);
    }

    function registerProvider(address providerAddress) external payable onlyFunded returns(bool) {
        _lockProviderFunds(providerAddress);
        emit providerRegistered(providerAddress, block.timestamp);

        return _addProvider(providerAddress);
    }

    function updateParams(uint256 newF, uint256 newT, uint256 newI, uint256 newJ, uint256 newAf) public onlyThis onlyOwner {
        _f = newF;
        _t = newT;
        _i = newI;
        _j = newJ;
        _af = newAf;

        emit updatedParms(block.timestamp, newAf);
    }

    function _subscribe(address subscriber) internal onlyNotBlacklisted(subscriber) onlyNotSubscribed(subscriber) onlyNotBanned(subscriber) returns(bool){
        _subscriptions[subscriber] = block.timestamp;
        _xpToken.mint(subscriber, 0, 2000, "Subscribed to Reward Mechansim");

        emit subscribed(subscriber, block.timestamp);

        return true;
    }

    function subscribe() external returns(bool){
        return _subscribe(msg.sender);
    }

    function _ban(address userAddress, address authority, uint256 duration) internal returns(bool){
        _bannedAddresses[userAddress] = duration;
        _subscriptions[userAddress] = 0;

        emit banned(userAddress, authority, duration, block.timestamp);

        return true;
    }

    function ban(address userAddress, uint256 duration) public onlyModerator onlyAdmin onlyOwner returns(bool){
        return _ban(userAddress, msg.sender, duration);
    }

    function _unban(address account) internal onlyBanTimeServed returns(bool)  {
        _bannedAddresses[account] = 0;
        _bannedAtTimes[account] = 0;
        _subscriptions[account] = block.timestamp;
        
        emit unbanned(account, block.timestamp);

        return true;
    }

    function unban(address account) public returns(bool) {
        return _unban(account);
    }

    function authorizedUnban(address account) public onlyModerator onlyAdmin onlyOwner returns(bool){
        _bannedAddresses[account] = 0;
        _bannedAtTimes[account] = 0;
        _subscriptions[account] = block.timestamp;

        emit authorizedUnbanned(account, msg.sender, block.timestamp);

        return true;
    }

    function _blacklist(address account, address authority) internal returns(bool){
        _blacklistedAddresses[account] = true;
        _subscriptions[account] = 0;

        emit blacklisted(account, authority, block.timestamp);

        return true;
    }

    function _removeBlacklist(address account, address authority) internal returns(bool) {
        _blacklistedAddresses[account] = false;

        emit blacklistRemoved(account, authority, block.timestamp);

        return _blacklistedAddresses[account];
    }

    function blacklist(address account) public onlyAdmin onlyOwner returns(bool) {
        return _blacklist(account, msg.sender);
    }

    function removeBlacklist(address account) public onlyAdmin onlyOwner returns(bool){
        return _removeBlacklist(account, msg.sender);
    }

    function unbanMe() external onlyBanTimeServed returns(bool) {
        return _unban(msg.sender);
    }
}
