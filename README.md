# Simple Staking

`Staking` is a simple contract that lets anyone stake a `stakingToken` in order to be eligible for claiming `rewardToken` rewards that are accrued to stakers pro-rata and indefinitely.

A contract `operator` role only has one privilege which is to change the monthly reward rate. The contract puts strict boundaries over the monthly reward rate in order to protect stakers from misuse (e.g. reward rate overflow).

While the operator sets a monthly rate for simplicity, rewards are streamed continuously as long as there are `rewardToken`s left in the contract balance. Therefore, the monthly rate can be changed by the operator at any time and becomes effective immediately.