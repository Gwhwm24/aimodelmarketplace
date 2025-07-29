# AI Models Marketplace

A decentralized marketplace for AI model creators to monetize their models and users to access AI services through blockchain payments.

## Overview

The AI Models Marketplace is a smart contract-based platform that enables:
- **AI Model Creators** to register, monetize, and distribute their AI models as NFTs
- **Users** to discover and execute AI models by paying with ERC20 tokens
- **Oracle Services** to handle secure execution completion and result delivery
- **Platform Governance** through decentralized ownership and fee management

## Features

### Core Functionality
- **Model Registration**: Creators can register AI models as ERC721 NFTs with metadata stored on IPFS
- **Model Execution**: Users pay to execute models with secure payment handling
- **Oracle Integration**: Trusted oracles complete executions and deliver results
- **Rating System**: Users can rate completed executions to build model reputation
- **Category Organization**: Models are organized by type (Text Generation, Image Generation, etc.)

### Security Features
- **Reentrancy Protection**: Guards against reentrancy attacks during payments
- **Access Control**: Role-based permissions for oracles and contract owner
- **Payment Guarantees**: Automatic refunds for failed executions
- **Emergency Controls**: Owner can toggle model availability if needed

### Economic Model
- **Pay-per-Execution**: Users pay per model execution
- **Platform Fees**: Configurable platform fee (default 2.5%)
- **Creator Revenue**: Model creators receive payment minus platform fees
- **NFT Ownership**: Model creators own NFTs representing their models

## Smart Contract Architecture

### Main Contract: `Project.sol`
- **Inherits**: ERC721, ReentrancyGuard, Ownable
- **Dependencies**: OpenZeppelin contracts for security and standards compliance

### Key Data Structures

#### AIModel
```solidity
struct AIModel {
    uint256 modelId;
    address creator;
    string name;
    string description;
    string modelHash; // IPFS hash
    uint256 pricePerExecution;
    uint256 totalExecutions;
    uint256 rating; // Average rating * 100
    uint256 ratingCount;
    bool isActive;
    ModelCategory category;
    uint256 createdAt;
}
```

#### ExecutionRecord
```solidity
struct ExecutionRecord {
    uint256 executionId;
    uint256 modelId;
    address user;
    uint256 timestamp;
    uint256 paidAmount;
    ExecutionStatus status;
    string inputHash;
    string outputHash;
    uint8 userRating; // 1-5 stars
}
```

## Usage Guide

### For AI Model Creators

1. **Register a Model**
   ```solidity
   registerModel(
       "GPT-4 Clone",
       "Advanced text generation model",
       "QmX1234...", // IPFS hash
       1000000000000000000, // 1 token per execution
       ModelCategory.TextGeneration
   )
   ```

2. **Monitor Executions**
   - Track your model's usage via `getUserModels()`
   - View execution history and ratings

3. **Earn Revenue**
   - Receive payments automatically when executions complete
   - Platform fee is deducted (default 2.5%)

### For Users

1. **Discover Models**
   ```solidity
   getModelsByCategory(ModelCategory.ImageGeneration)
   ```

2. **Execute a Model**
   ```solidity
   executeModel(modelId, "QmInputHash123...")
   ```

3. **Rate Completed Executions**
   ```solidity
   rateExecution(executionId, 5) // 5-star rating
   ```

### For Oracles

1. **Complete Executions**
   ```solidity
   completeExecution(
       executionId,
       ExecutionStatus.Completed,
       "QmOutputHash456..."
   )
   ```

## Deployment Guide

### Prerequisites
- Node.js and npm
- Hardhat or Truffle development environment
- ERC20 token contract for payments

### Installation
```bash
npm install @openzeppelin/contracts
```

### Constructor Parameters
```solidity
constructor(
    address _paymentToken,  // ERC20 token for payments
    string memory _name,    // NFT collection name
    string memory _symbol   // NFT collection symbol
)
```

### Deployment Script Example
```javascript
const paymentTokenAddress = "0x..."; // Your ERC20 token
const marketplace = await Project.deploy(
    paymentTokenAddress,
    "AI Models Marketplace",
    "AIML"
);
```

## Model Categories

- `TextGeneration` - Language models, chatbots, content generation
- `ImageGeneration` - Image creation, art generation, photo editing
- `DataAnalysis` - Data processing, insights, analytics
- `Translation` - Language translation services
- `Classification` - Content classification, sentiment analysis
- `Other` - Miscellaneous AI services

## Events

The contract emits several events for off-chain monitoring:

- `ModelRegistered` - New model registered
- `ExecutionRequested` - User requested model execution
- `ExecutionCompleted` - Oracle completed execution
- `ModelRated` - User rated a model
- `OracleUpdated` - Oracle address changed

## Security Considerations

### Access Control
- Only contract owner can set oracle address
- Only oracle or owner can complete executions
- Only execution owner can rate their executions

### Payment Security
- Uses `nonReentrant` modifier on payment functions
- Automatic refunds for failed executions
- Platform fees capped at 10%

### Emergency Mechanisms
- Owner can toggle model availability
- Emergency withdrawal of platform fees

## Integration Examples

### Web3.js Integration
```javascript
const contract = new web3.eth.Contract(abi, contractAddress);

// Register a model
await contract.methods.registerModel(
    "My AI Model",
    "Description",
    "QmIPFSHash",
    web3.utils.toWei("1", "ether"),
    0 // TextGeneration
).send({ from: creatorAddress });

// Execute a model
await contract.methods.executeModel(
    modelId,
    "QmInputHash"
).send({ from: userAddress });
```

### Oracle Service Integration
```javascript
// Monitor for execution requests
contract.events.ExecutionRequested({}, (error, event) => {
    if (!error) {
        processExecution(event.returnValues.executionId);
    }
});

// Complete execution
await contract.methods.completeExecution(
    executionId,
    1, // Completed status
    "QmOutputHash"
).send({ from: oracleAddress });
```

## Gas Optimization Tips

- Batch multiple operations when possible
- Use view functions for reading data
- Consider implementing execution queuing for high-volume models
- Cache frequently accessed model data off-chain

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions or support:
- Create an issue on GitHub
- Check the documentation
- Review the smart contract tests

## Roadmap

- [ ] Multi-token payment support
- [ ] Model versioning system
- [ ] Subscription-based pricing models
- [ ] Advanced reputation algorithms
- [ ] Cross-chain compatibility
- [ ] Decentralized model hosting integration

---

*Built with ❤️ for the decentralized AI ecosystem*
