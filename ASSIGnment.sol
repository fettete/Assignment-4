// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StakingContract {
    address public owner;
    uint public stakingPeriod; // In seconds
    uint public rewardsPerPeriod;
    IERC20 public stakedToken;

    struct Staker {
        uint stakedAmount;
        uint stakingStartTime;
        uint lastClaimTime;
        uint rewardsEarned;
    }

    mapping(address => Staker) public stakers;

    event Staked(address indexed user, uint amount);
    event Withdrawn(address indexed user, uint stakedAmount, uint rewardsEarned);

    constructor(
        uint _stakingPeriod,
        uint _rewardsPerPeriod,
        address _stakedTokenAddress
    ) {
        owner = msg.sender;
        stakingPeriod = _stakingPeriod;
        rewardsPerPeriod = _rewardsPerPeriod;
        stakedToken = IERC20(_stakedTokenAddress);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    function stake(uint _amount) external {
        require(_amount > 0, "Staking amount must be greater than 0");
        require(stakers[msg.sender].stakedAmount == 0, "You are already a staker");

        // Transfer tokens from the user to this contract
        stakedToken.transferFrom(msg.sender, address(this), _amount);

        stakers[msg.sender] = Staker({
            stakedAmount: _amount,
            stakingStartTime: block.timestamp,
            lastClaimTime: block.timestamp,
            rewardsEarned: 0
        });

        emit Staked(msg.sender, _amount);
    }

    function calculateRewards(address _user) internal view returns (uint) {
        Staker storage staker = stakers[_user];
        uint timeStaked = block.timestamp - staker.stakingStartTime;
        return (staker.stakedAmount * timeStaked * rewardsPerPeriod) / stakingPeriod;
    }

    function distributeRewards() external onlyOwner {
        for (address user : stakers) {
            if (stakers[user].stakedAmount > 0) {
                uint rewards = calculateRewards(user);
                stakers[user].rewardsEarned += rewards;
                stakers[user].lastClaimTime = block.timestamp;
            }
        }
    }

    function withdraw() external {
        Staker storage staker = stakers[msg.sender];
        require(staker.stakedAmount > 0, "You are not a staker");
        
        uint rewards = calculateRewards(msg.sender);
        uint totalAmount = staker.stakedAmount + rewards;

        staker.stakedAmount = 0;
        staker.rewardsEarned = 0;

        stakedToken.transfer(msg.sender, totalAmount);
        emit Withdrawn(msg.sender, staker.stakedAmount, rewards);
    }

    function getStakerBalance(address _user) external view returns (uint stakedAmount, uint rewardsEarned) {
        Staker storage staker = stakers[_user];
        return (staker.stakedAmount, staker.rewardsEarned);
    }
}