# 🌾 Agri Data DAO

A decentralized autonomous organization where farmers can pool and sell their agricultural sensor data to researchers and agri-tech companies on the Stacks blockchain.

## 🚀 Features

- 👨‍🌾 **Farmer Registration**: Join the DAO as a verified farmer
- 📊 **Data Submission**: Upload sensor data with pricing
- 💰 **Data Marketplace**: Buy and sell agricultural data
- 🗳️ **DAO Governance**: Vote on proposals using reputation-based system
- 💎 **Reputation System**: Build credibility through data sales
- 🏦 **Treasury Management**: Community-controlled funds

## 📋 How It Works

### For Farmers 🌱

1. **Register** as a farmer in the DAO
2. **Submit sensor data** with location, type, and price
3. **Earn STX** when researchers purchase your data (80% to farmer, 20% to DAO)
4. **Build reputation** with each successful sale
5. **Participate in governance** with reputation-weighted voting

### For Researchers/Companies 🔬

1. **Browse available data** from verified farmers
2. **Purchase data** directly with STX tokens
3. **Access high-quality** agricultural sensor information
4. **Support sustainable** farming practices

### For DAO Members 🏛️

1. **Create proposals** for treasury spending (requires 5+ reputation)
2. **Vote on proposals** using reputation as voting power
3. **Execute approved** proposals automatically
4. **Grow the ecosystem** through community decisions

## 🛠️ Contract Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `register-farmer` | Join the DAO as a farmer | None |
| `submit-sensor-data` | Upload new sensor data | `data-type`, `location`, `price` |
| `purchase-data` | Buy sensor data | `data-id` |
| `create-proposal` | Create governance proposal | `title`, `description`, `amount`, `recipient` |
| `vote-proposal` | Vote on DAO proposal | `proposal-id`, `vote-for` |
| `execute-proposal` | Execute approved proposal | `proposal-id` |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-farmer-info` | Get farmer details | Farmer stats |
| `get-sensor-data` | Get data by ID | Data details |
| `get-proposal` | Get proposal details | Proposal info |
| `get-treasury-balance` | Current DAO treasury | Balance in STX |
| `is-data-available` | Check if data is unsold | Boolean |
| `get-data-count` | Total data submissions | Count |

## 💡 Usage Examples

### Register as Farmer
```clarity
(contract-call? .agri-data-dao register-farmer)
```

### Submit Sensor Data
```clarity
(contract-call? .agri-data-dao submit-sensor-data "soil-moisture" "Iowa-Farm-A" u1000000)
```

### Purchase Data
```clarity
(contract-call? .agri-data-dao purchase-data u1)
```

### Create Proposal
```clarity
(contract-call? .agri-data-dao create-proposal 
  "Research Grant" 
  "Fund climate research project" 
  u5000000 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 🎯 Revenue Model

- **80%** of data sales go to the farmer
- **20%** goes to DAO treasury for:
  - Research grants
  - Platform development
  - Community incentives
  - Infrastructure costs

## 🔒 Security Features

- Reputation-based governance prevents spam
- Multi-signature treasury management
- Time-locked proposal execution
- Farmer verification system

## 🌟 Getting Started

1. Deploy the contract to Stacks testnet
2. Register as a farmer using `register-farmer`
3. Start submitting your agricultural sensor data
4. Participate in DAO governance as you build reputation

## 📈 Roadmap

- [ ] Multi-token support
- [ ] Data quality verification
- [ ] Mobile app integration
- [ ] Advanced analytics dashboard
- [ ] Cross-chain compatibility

---

*Building the future of agricultural data sharing, one sensor at a time* 🌾✨
```

**Git Commit Message:**
```
feat: implement agri data DAO MVP with farmer registration, data marketplace, and governance system
```

**GitHub Pull Request Title:**
```
🌾 Add Agri Data DAO
