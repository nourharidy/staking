// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/Staking.sol";

contract ERC20 {
    uint8 public constant decimals = 18;
    uint public immutable totalSupply;

    mapping(address => uint) public balanceOf;
    mapping (address => mapping (address => uint)) public allowance;

    constructor(uint supply) {
        balanceOf[msg.sender] = supply;
        totalSupply = supply;
    }

    function transfer(address to, uint amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint amount) public returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract ContractTest is Test {

    Staking staking;
    ERC20 stakingToken = new ERC20(1000 ether);
    ERC20 rewardToken = new ERC20(1000 ether);

    function setUp() public {
        staking = new Staking(IERC20(address(stakingToken)), IERC20(address(rewardToken)), address(this), 30 days * 1 ether);
        rewardToken.transfer(address(staking), 1000 ether);
    }

    function testSingleStaker() public {
        vm.warp(block.timestamp + 10000); // a delayed first deposit hould cause no issues
        stakingToken.approve(address(staking), 1 ether);
        staking.stake(1 ether);
        assert(staking.balanceOf(address(this)) == 1 ether);
        assert(staking.totalSupply() == 1 ether);
        vm.warp(block.timestamp + 10);
        uint claimable = staking.claimable(address(this));
        staking.claimRewards();
        assert(rewardToken.balanceOf(address(this)) == 10 ether);
        assert(rewardToken.balanceOf(address(this)) == claimable);
        staking.unstake(1 ether);
        assert(staking.balanceOf(address(this)) == 0);
        assert(staking.totalSupply() == 0);
        assert(stakingToken.balanceOf(address(this)) == 1000 ether);
    }

    function test2Stakers() public {
        // 1st staker
        stakingToken.approve(address(staking), 1 ether);
        staking.stake(1 ether);
        stakingToken.transfer(address(1), 1 ether);
        // 2nd staker
        vm.prank(address(1));
        stakingToken.approve(address(staking), 1 ether);
        vm.prank(address(1));
        staking.stake(1 ether);
        assert(staking.balanceOf(address(1)) == 1 ether);
        assert(staking.totalSupply() == 2 ether);
        vm.warp(block.timestamp + 10);
        uint claimable = staking.claimable(address(this));
        staking.claimRewards();
        assert(rewardToken.balanceOf(address(this)) == 5 ether);
        assert(rewardToken.balanceOf(address(this)) == claimable);
        uint claimable1 = staking.claimable(address(1));
        vm.prank(address(1));
        staking.claimRewards();
        assert(rewardToken.balanceOf(address(1)) == 5 ether);
        assert(rewardToken.balanceOf(address(1)) == claimable1);
    }

    function testSecondStakerAfter0Supply() public {
        // 1st staker
        stakingToken.approve(address(staking), 1 ether);
        staking.stake(1 ether);
        vm.warp(block.timestamp + 10);
        staking.unstake(1 ether);
        staking.claimRewards();
        assert(rewardToken.balanceOf(address(this)) == 10 ether);
        assert(staking.balanceOf(address(this)) == 0);
        assert(staking.totalSupply() == 0);
        stakingToken.transfer(address(1), 1 ether);
        // 2nd staker
        vm.warp(block.timestamp + 1000); // second staker stakes after 1000 seconds
        vm.prank(address(1));
        stakingToken.approve(address(staking), 1 ether);
        vm.prank(address(1));
        staking.stake(1 ether);
        assert(staking.balanceOf(address(1)) == 1 ether);
        assert(staking.totalSupply() == 1 ether);
        vm.warp(block.timestamp + 10);
        uint claimable1 = staking.claimable(address(1));
        vm.prank(address(1));
        staking.claimRewards();
        assert(rewardToken.balanceOf(address(1)) == 10 ether);
        assert(rewardToken.balanceOf(address(1)) == claimable1);
    }

    function test2StakersComplex() public {
        // 1st staker
        stakingToken.approve(address(staking), 1 ether);
        staking.stake(1 ether);
        stakingToken.transfer(address(1), 1 ether);
        vm.warp(block.timestamp + 10); // 1st staker = 10 ether rewards
        vm.prank(address(1));
        stakingToken.approve(address(staking), 1 ether);
        vm.prank(address(1));
        staking.stake(1 ether);
        vm.warp(block.timestamp + 10); // 1st staker = 15 ether rewards, 2nd staker = 5 ether rewards
        uint claimable1 = staking.claimable(address(1));
        vm.prank(address(1));
        staking.claimRewards();
        assert(rewardToken.balanceOf(address(1)) == 5 ether);
        assert(rewardToken.balanceOf(address(1)) == claimable1);
        vm.prank(address(1));
        staking.unstake(1 ether);
        vm.warp(block.timestamp + 10); // 1st staker = 25 ether rewards, 2nd staker = 0 ether rewards
        uint claimable = staking.claimable(address(this));
        staking.claimRewards();
        assert(rewardToken.balanceOf(address(this)) == 25 ether);
        assert(rewardToken.balanceOf(address(this)) == claimable);
        claimable1 = staking.claimable(address(1));
        vm.prank(address(1));
        staking.claimRewards();
        assert(rewardToken.balanceOf(address(1)) == 5 ether); // already has 5 ether in balance
        assert(rewardToken.balanceOf(address(1)) == claimable1 + 5 ether);
    }

    function testRateChange() public {
        stakingToken.approve(address(staking), 1 ether);
        staking.stake(1 ether);
        vm.warp(block.timestamp + 10);
        uint claimable = staking.claimable(address(this));
        assert(claimable == 10 ether);
        // 0.5x rate
        staking.setMonthlyReward(30 days * 0.5 ether);
        vm.warp(block.timestamp + 10);
        assert(staking.claimable(address(this)) == 15 ether);
        staking.claimRewards();
        assert(rewardToken.balanceOf(address(this)) == 15 ether);
        // 2x rate
        staking.setMonthlyReward(30 days * 2 ether);
        vm.warp(block.timestamp + 10);
        assert(staking.claimable(address(this)) == 20 ether);
        staking.claimRewards();
        assert(rewardToken.balanceOf(address(this)) == 35 ether);
    }
}
