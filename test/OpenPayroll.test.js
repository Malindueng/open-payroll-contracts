const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("OpenPayroll", function () {
  let contract, employer, employee, other;

  // 1 OPN per day in wei per second
  const SALARY_PER_SEC = ethers.parseEther("1") / 86400n;

  beforeEach(async function () {
    [employer, employee, other] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("OpenPayroll");
    contract = await Factory.deploy();
  });

  it("employer can deposit funds", async function () {
    await contract.connect(employer).depositFunds({
      value: ethers.parseEther("10"),
    });
    const bal = await contract.employerBalance(employer.address);
    expect(bal).to.equal(ethers.parseEther("10"));
  });

  it("employer can add an employee", async function () {
    await contract.connect(employer).addEmployee(employee.address, SALARY_PER_SEC);
    const emp = await contract.getEmployee(employer.address, employee.address);
    expect(emp.active).to.be.true;
    expect(emp.salaryPerSec).to.equal(SALARY_PER_SEC);
  });

  it("employee accrues salary over time", async function () {
    await contract.connect(employer).depositFunds({ value: ethers.parseEther("10") });
    await contract.connect(employer).addEmployee(employee.address, SALARY_PER_SEC);

    // Fast-forward 1 day
    await time.increase(86400);

    const claimable = await contract.getClaimable(employer.address, employee.address);
    // Should be approximately 1 OPN (within rounding)
    expect(claimable).to.be.closeTo(ethers.parseEther("1"), ethers.parseEther("0.001"));
  });

  it("employee can claim salary", async function () {
    await contract.connect(employer).depositFunds({ value: ethers.parseEther("10") });
    await contract.connect(employer).addEmployee(employee.address, SALARY_PER_SEC);
    await time.increase(86400);

    const before = await ethers.provider.getBalance(employee.address);
    await contract.connect(employee).claimSalary(employer.address);
    const after = await ethers.provider.getBalance(employee.address);

    expect(after).to.be.gt(before);
  });

  it("employer can pause a stream", async function () {
    await contract.connect(employer).depositFunds({ value: ethers.parseEther("10") });
    await contract.connect(employer).addEmployee(employee.address, SALARY_PER_SEC);
    await contract.connect(employer).pauseStream(employee.address);

    const emp = await contract.getEmployee(employer.address, employee.address);
    expect(emp.active).to.be.false;
  });

  it("employee cannot claim when paused", async function () {
    await contract.connect(employer).depositFunds({ value: ethers.parseEther("10") });
    await contract.connect(employer).addEmployee(employee.address, SALARY_PER_SEC);
    await contract.connect(employer).pauseStream(employee.address);
    await time.increase(86400);

    await expect(
      contract.connect(employee).claimSalary(employer.address)
    ).to.be.revertedWith("Stream is paused");
  });

  it("employer can terminate a stream", async function () {
    await contract.connect(employer).depositFunds({ value: ethers.parseEther("10") });
    await contract.connect(employer).addEmployee(employee.address, SALARY_PER_SEC);
    await contract.connect(employer).terminateStream(employee.address);

    const emp = await contract.getEmployee(employer.address, employee.address);
    expect(emp.exists).to.be.false;
  });

  it("employer can withdraw unused funds", async function () {
    await contract.connect(employer).depositFunds({ value: ethers.parseEther("10") });
    const before = await ethers.provider.getBalance(employer.address);
    await contract.connect(employer).withdrawFunds(ethers.parseEther("5"));
    const after = await ethers.provider.getBalance(employer.address);
    expect(after).to.be.gt(before);
  });
});