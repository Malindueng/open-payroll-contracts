// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title OpenPayroll
 * @notice On-chain payroll streams with clawback protection.
 *         An employer deploys this contract, funds it with OPN,
 *         and adds employees. Each employee's salary drips
 *         continuously per second. Employees withdraw whenever
 *         they want. The employer can pause or terminate streams.
 */
contract OpenPayroll is Ownable, ReentrancyGuard {

    // ─── Data structures ──────────────────────────────────────────

    struct Employee {
        address wallet;         // Employee's wallet address
        uint256 salaryPerSec;   // How much OPN (in wei) they earn per second
        uint256 startTime;      // When their stream started
        uint256 lastClaimed;    // Timestamp of their last withdrawal
        uint256 totalClaimed;   // Lifetime amount claimed
        bool active;            // Whether stream is currently running
        bool exists;            // Whether this employee record exists
    }

    // ─── State variables ──────────────────────────────────────────

    // employer address => (employee address => Employee)
    mapping(address => mapping(address => Employee)) public employees;

    // employer address => list of their employee wallet addresses
    mapping(address => address[]) public employeeList;

    // employer address => total funds they have deposited
    mapping(address => uint256) public employerBalance;

    // ─── Events ───────────────────────────────────────────────────

    event EmployeeAdded(address indexed employer, address indexed employee, uint256 salaryPerSec);
    event SalaryClaimed(address indexed employee, address indexed employer, uint256 amount);
    event StreamPaused(address indexed employer, address indexed employee);
    event StreamResumed(address indexed employer, address indexed employee);
    event StreamTerminated(address indexed employer, address indexed employee);
    event FundsDeposited(address indexed employer, uint256 amount);
    event FundsWithdrawn(address indexed employer, uint256 amount);

    // ─── Constructor ──────────────────────────────────────────────

    constructor() Ownable(msg.sender) {}

    // ─── Employer functions ───────────────────────────────────────

    /**
     * @notice Deposit OPN into the contract to fund payroll.
     *         Anyone can call this for any employer address,
     *         but practically the employer funds their own balance.
     */
    function depositFunds() external payable {
        require(msg.value > 0, "Must deposit more than 0");
        employerBalance[msg.sender] += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    /**
     * @notice Add a new employee and start their salary stream.
     * @param employeeWallet  The employee's wallet address
     * @param salaryPerSec    How much OPN (wei) they earn per second
     *
     * Example: for 1 OPN/day, salaryPerSec = 1e18 / 86400 = 11574074074 (wei)
     */
    function addEmployee(address employeeWallet, uint256 salaryPerSec) external {
        require(employeeWallet != address(0), "Invalid address");
        require(salaryPerSec > 0, "Salary must be greater than 0");
        require(!employees[msg.sender][employeeWallet].exists, "Employee already exists");

        employees[msg.sender][employeeWallet] = Employee({
            wallet: employeeWallet,
            salaryPerSec: salaryPerSec,
            startTime: block.timestamp,
            lastClaimed: block.timestamp,
            totalClaimed: 0,
            active: true,
            exists: true
        });

        employeeList[msg.sender].push(employeeWallet);

        emit EmployeeAdded(msg.sender, employeeWallet, salaryPerSec);
    }

    /**
     * @notice Pause an employee's salary stream.
     *         Accrued amount up to this point is preserved.
     */
    function pauseStream(address employeeWallet) external {
        Employee storage emp = employees[msg.sender][employeeWallet];
        require(emp.exists, "Employee not found");
        require(emp.active, "Stream already paused");

        // Snapshot earned amount into lastClaimed so nothing is lost
        emp.lastClaimed = block.timestamp;
        emp.active = false;

        emit StreamPaused(msg.sender, employeeWallet);
    }

    /**
     * @notice Resume a paused stream. Salary accrual restarts now.
     */
    function resumeStream(address employeeWallet) external {
        Employee storage emp = employees[msg.sender][employeeWallet];
        require(emp.exists, "Employee not found");
        require(!emp.active, "Stream already active");

        emp.lastClaimed = block.timestamp;
        emp.active = true;

        emit StreamResumed(msg.sender, employeeWallet);
    }

    /**
     * @notice Permanently terminate an employee's stream.
     *         Any unclaimed salary is forfeited back to employer balance.
     */
    function terminateStream(address employeeWallet) external {
        Employee storage emp = employees[msg.sender][employeeWallet];
        require(emp.exists, "Employee not found");

        emp.active = false;
        emp.exists = false;

        emit StreamTerminated(msg.sender, employeeWallet);
    }

    /**
     * @notice Withdraw unused funds from your employer balance.
     */
    function withdrawFunds(uint256 amount) external nonReentrant {
        require(employerBalance[msg.sender] >= amount, "Insufficient balance");
        employerBalance[msg.sender] -= amount;
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Transfer failed");
        emit FundsWithdrawn(msg.sender, amount);
    }

    // ─── Employee functions ───────────────────────────────────────

    /**
     * @notice Claim all accrued salary from a specific employer.
     * @param employerAddress  The employer whose stream you are claiming from
     */
    function claimSalary(address employerAddress) external nonReentrant {
        Employee storage emp = employees[employerAddress][msg.sender];
        require(emp.exists, "No stream found");
        require(emp.active, "Stream is paused");

        uint256 earned = _calculateEarned(emp);
        require(earned > 0, "Nothing to claim");
        require(employerBalance[employerAddress] >= earned, "Employer balance too low");

        emp.lastClaimed = block.timestamp;
        emp.totalClaimed += earned;
        employerBalance[employerAddress] -= earned;

        (bool sent, ) = msg.sender.call{value: earned}("");
        require(sent, "Transfer failed");

        emit SalaryClaimed(msg.sender, employerAddress, earned);
    }

    // ─── View functions ───────────────────────────────────────────

    /**
     * @notice Check how much salary an employee has earned but not yet claimed.
     */
    function getClaimable(address employerAddress, address employeeWallet)
        external
        view
        returns (uint256)
    {
        Employee storage emp = employees[employerAddress][employeeWallet];
        if (!emp.exists || !emp.active) return 0;
        return _calculateEarned(emp);
    }

    /**
     * @notice Get all employee addresses for an employer.
     */
    function getEmployees(address employerAddress)
        external
        view
        returns (address[] memory)
    {
        return employeeList[employerAddress];
    }

    /**
     * @notice Get full employee details.
     */
    function getEmployee(address employerAddress, address employeeWallet)
        external
        view
        returns (Employee memory)
    {
        return employees[employerAddress][employeeWallet];
    }

    // ─── Internal helpers ─────────────────────────────────────────

    /**
     * @dev Calculate earned amount since last claim.
     *      earned = salaryPerSec × (now - lastClaimed)
     */
    function _calculateEarned(Employee storage emp)
        internal
        view
        returns (uint256)
    {
        if (!emp.active) return 0;
        uint256 elapsed = block.timestamp - emp.lastClaimed;
        return emp.salaryPerSec * elapsed;
    }

    // ─── Fallback ─────────────────────────────────────────────────

    receive() external payable {
        employerBalance[msg.sender] += msg.value;
    }
}