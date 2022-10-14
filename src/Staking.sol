// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC20 {
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function decimals() external view returns (uint8);
    function balanceOf(address) external view returns (uint);
}

/**
    CAUTION: This contract makes important security assumptions regarding both staking and reward token contracts.
    Before deployment, please ensure the following:
        
        1. Both `stakingToken` and `rewardToken` contracts make no external calls in their code (re-entrancy risk)
        2. Both `stakingToken` and `rewardToken` contracts revert when `transfer()` and `transferFrom()` fail (returned bool is ignored by this contract)
*/
contract Staking {

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;
    address public operator;
    uint public rewardRate;
    uint public lastUpdate;
    uint public rewardIndex;
    uint public totalSupply;

    mapping (address => uint) public balanceOf;
    mapping (address => uint) public stakerIndex;
    mapping (address => uint) public accruedRewards;

    modifier updateIndex() {
        uint deltaT = block.timestamp - lastUpdate;
        if(deltaT > 0) {
            if(rewardRate > 0 && totalSupply > 0) {
                uint rewardsAccrued = deltaT * rewardRate;
                rewardIndex += rewardsAccrued / totalSupply;
            }
            lastUpdate = block.timestamp;
        }

        uint deltaIndex = rewardIndex - stakerIndex[msg.sender];
        uint bal = balanceOf[msg.sender];
        uint stakerDelta = bal * deltaIndex;
        stakerIndex[msg.sender] = rewardIndex;
        accruedRewards[msg.sender] += stakerDelta;
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operator, "ONLY OPERATOR");
        _;
    }

    constructor(IERC20 _stakingToken, IERC20 _rewardToken, address _operator, uint _monthlyReward) {
        require(_monthlyReward < type(uint).max / 120000); // cannot overflow and revert within 10,000 years
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        operator = _operator;
        rewardRate = _monthlyReward / 30 days;
        lastUpdate = block.timestamp;
    }

    function setMonthlyReward(uint _monthlyReward) public onlyOperator updateIndex {
        require(_monthlyReward < type(uint).max / 120000); // cannot overflow and revert within 10,000 years
        rewardRate = _monthlyReward / 30 days;
    }
    function setOperator(address _operator) public onlyOperator { operator = _operator; }

    function stake(uint amount) public updateIndex {
        stakingToken.transferFrom(msg.sender, address(this), amount);
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
    }

    function unstake(uint amount) public updateIndex {
        stakingToken.transfer(msg.sender, amount);
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
    }

    function claimable(address user) public view returns(uint) {
        uint deltaT = block.timestamp - lastUpdate;
        uint rewardsAccrued = deltaT * rewardRate;
        uint _rewardIndex = rewardIndex + (rewardsAccrued / totalSupply);
        uint deltaIndex = _rewardIndex - stakerIndex[user];
        uint bal = balanceOf[user];
        uint stakerDelta = bal * deltaIndex;
        return accruedRewards[user] + stakerDelta;
    }

    function claimRewards() public updateIndex {
        rewardToken.transfer(msg.sender, accruedRewards[msg.sender]);
        accruedRewards[msg.sender] = 0;
    }

}
