# Social Benefits Distribution System

A comprehensive blockchain-based social benefits distribution system built with Clarity smart contracts. This system automates welfare payments, reduces fraud through verification mechanisms, and provides transparent reporting of program effectiveness.

## System Overview

The Social Benefits Distribution System consists of five interconnected smart contracts:

1. **Benefits Registry** (`benefits-registry.clar`) - Central registry for all benefit programs
2. **Recipient Management** (`recipient-management.clar`) - Handles recipient verification and eligibility
3. **Payment Distribution** (`payment-distribution.clar`) - Manages payment logic and distribution
4. **Fraud Detection** (`fraud-detection.clar`) - Implements fraud prevention mechanisms
5. **Reporting** (`reporting.clar`) - Provides transparency and program effectiveness metrics

## Key Features

### Automated Welfare Payments
- Scheduled benefit distributions
- Multi-tier payment structures
- Emergency payment capabilities
- Conditional cash transfer support

### Fraud Prevention
- Identity verification requirements
- Duplicate recipient detection
- Suspicious activity monitoring
- Multi-signature approval for large payments

### Transparent Reporting
- Real-time program metrics
- Beneficiary statistics
- Fund utilization tracking
- Performance indicators

### Disaster Relief Support
- Emergency aid distribution
- Rapid deployment capabilities
- Crisis-specific benefit programs
- Priority recipient handling

## Contract Architecture

### Benefits Registry
- Program creation and management
- Benefit type definitions
- Funding allocation tracking
- Program status management

### Recipient Management
- Recipient registration and verification
- Eligibility criteria enforcement
- Identity document validation
- Status tracking and updates

### Payment Distribution
- Automated payment scheduling
- Multi-currency support
- Payment history tracking
- Distribution method management

### Fraud Detection
- Real-time fraud monitoring
- Risk scoring algorithms
- Suspicious pattern detection
- Automated flagging system

### Reporting
- Program effectiveness metrics
- Financial transparency reports
- Beneficiary impact analysis
- Compliance reporting

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js 18+ for testing
- Stacks wallet for deployment

### Installation

1. Clone the repository
2. Install dependencies: `npm install`
3. Run tests: `npm test`
4. Deploy contracts: `clarinet deploy`

### Configuration

The system requires initial configuration of:
- Program administrators
- Benefit program parameters
- Verification requirements
- Payment schedules

## Usage Examples

### Creating a Benefit Program
```clarity
(contract-call? .benefits-registry create-program 
  "Emergency Food Assistance" 
  u1000000 
  u30)
