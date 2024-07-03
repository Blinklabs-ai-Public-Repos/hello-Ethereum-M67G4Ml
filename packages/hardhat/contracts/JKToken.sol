// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract JKToken is ERC20, Ownable {
    using SafeMath for uint256;

    uint8 private immutable _decimals;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 cliffDuration;
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    event TokensVested(address indexed beneficiary, uint256 amount);
    event VestingScheduleCreated(address indexed beneficiary, uint256 amount);

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration
    ) public onlyOwner {
        require(beneficiary != address(0), "Beneficiary cannot be zero address");
        require(amount > 0, "Amount must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(cliffDuration <= duration, "Cliff duration cannot exceed total duration");
        require(vestingSchedules[beneficiary].totalAmount == 0, "Vesting schedule already exists");

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            duration: duration,
            cliffDuration: cliffDuration
        });

        _mint(address(this), amount);

        emit VestingScheduleCreated(beneficiary, amount);
    }

    function releaseVestedTokens(address beneficiary) public {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "No vesting schedule found");

        uint256 vestedAmount = _calculateVestedAmount(schedule);
        uint256 releasableAmount = vestedAmount.sub(schedule.releasedAmount);

        require(releasableAmount > 0, "No tokens are due for release");

        schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);
        _transfer(address(this), beneficiary, releasableAmount);

        emit TokensVested(beneficiary, releasableAmount);
    }

    function _calculateVestedAmount(VestingSchedule memory schedule) private view returns (uint256) {
        if (block.timestamp < schedule.startTime.add(schedule.cliffDuration)) {
            return 0;
        }
        if (block.timestamp >= schedule.startTime.add(schedule.duration)) {
            return schedule.totalAmount;
        }
        return schedule.totalAmount.mul(
            block.timestamp.sub(schedule.startTime)
        ).div(schedule.duration);
    }

    function getVestedAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        return _calculateVestedAmount(schedule);
    }

    function getReleasableAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        uint256 vestedAmount = _calculateVestedAmount(schedule);
        return vestedAmount.sub(schedule.releasedAmount);
    }
}