# 💸 Open Payroll — Smart Contracts

> Solidity contracts powering Open Payroll — OPN Builders Season 1 Submission

This repo contains the core smart contract, deploy scripts, and full test suite for Open Payroll — an on-chain payroll streaming protocol built on OPN Chain.

---

## 🔗 Links

| | |
|---|---|
| **Live DApp** | https://open-payroll-xyz.vercel.app |
| **DApp Repository** | https://github.com/YOUR_USERNAME/open-payroll-app |
| **Contract Address** | `0xYourContractAddressHere` |
| **OPN Explorer** | https://testnet.iopn.tech/address/0xYourContractAddressHere |

---

## 📄 Contract Overview

`OpenPayroll.sol` is a single-contract payroll streaming protocol. An employer
deploys it, funds it with OPN, and adds employees with a daily salary rate.
Salary accrues every second. Employees claim whenever they want.

### Core mechanics

| Feature | How it works |
|---|---|
| Salary streaming | `salaryPerSec × (now - lastClaimed)` calculated on-chain |
| Claim | Employee calls `claimSalary(employerAddress)` |
| Pause | Employer freezes accrual, preserving earned amount |
| Resume | Accrual restarts from current timestamp |
| Terminate | Stream closed permanently, unstreamed funds stay in employer balance |
| Withdraw | Employer reclaims unstreamed funds anytime |

### Contract functions

depositFunds()                              → employer deposits OPN
addEmployee(wallet, salaryPerSec)          → start a salary stream
pauseStream(employeeWallet)                → pause accrual
resumeStream(employeeWallet)               → resume accrual
terminateStream(employeeWallet)            → permanently end stream
withdrawFunds(amount)                      → employer reclaims funds
claimSalary(employerAddress)               → employee withdraws earned salary
getClaimable(employer, employee)           → view earned but unclaimed amount
getEmployee(employer, employee)            → view full employee struct
getEmployees(employer)                     → list all employee addresses

---

## 🔐 Security

- **ReentrancyGuard** on all fund-moving functions
- **Ownable** via OpenZeppelin
- Earned amounts snapshot on pause — no loss of accrued salary
- Pull pattern for claims — contract never pushes funds unsolicited

---

## ⚙️ Tech Stack

| | |
|---|---|
| Language | Solidity 0.8.24 |
| Framework | Hardhat |
| Libraries | OpenZeppelin Contracts |
| Network | OPN Testnet (Chain ID: 984) |
| Testing | Hardhat + Chai + hardhat-network-helpers |

---

## 🚀 Getting started

```bash
# Clone
git clone https://github.com/YOUR_USERNAME/open-payroll-contracts.git
cd open-payroll-contracts

# Install
npm install

# Copy env
cp .env.example .env
# Add your PRIVATE_KEY to .env

# Run tests
npx hardhat test

# Deploy to OPN Testnet
npx hardhat run scripts/deploy.js --network opnTestnet
```

---

## 🧪 Tests

```bash
npx hardhat test
```

Covers:
- Employer deposits funds
- Add employee and verify stream starts
- Salary accrues correctly over time
- Employee claims salary
- Pause prevents claiming
- Resume restarts accrual
- Terminate closes stream permanently
- Employer withdraws unused funds

---

## 🗺 Roadmap

### ✅ Phase 1 — Core (shipped)
- [x] Salary streaming with per-second accrual
- [x] Pause, resume, terminate controls
- [x] Multi-employee support
- [x] Deployed on OPN Testnet

### 🔜 Phase 2 — Identity & Reputation
- [ ] Employer reputation scores tracked on-chain
- [ ] Employee work history as soulbound credentials
- [ ] Verified employer badges via OPN identity layer

### 🔜 Phase 3 — Real World Assets
- [ ] Multi-token payroll (OPN + ERC-20s)
- [ ] Payroll backed by tokenized treasury assets
- [ ] Automatic tax withholding vault

### 🔮 Future
- [ ] Mainnet deployment
- [ ] DAO payroll — proposal-gated salary changes
- [ ] Payroll analytics on-chain

---

## 👤 Builder

Built for OPN Builders Season 1 — DeFi & Open Finance track.