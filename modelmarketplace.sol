// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title AI Models Marketplace
 * @dev A decentralized marketplace for AI model creators to monetize their models
 * and users to access AI services through blockchain payments
 */
contract Project is ERC721, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    
    // Counters for unique IDs
    Counters.Counter private _modelIds;
    Counters.Counter private _executionIds;
    
    // Payment token for transactions
    IERC20 public immutable paymentToken;
    
    // Platform fee in basis points (250 = 2.5%)
    uint256 public platformFee = 250;
    
    // Oracle address for completing executions
    address public oracle;
    
    // Model categories
    enum ModelCategory {
        TextGeneration,
        ImageGeneration,
        DataAnalysis,
        Translation,
        Classification,
        Other
    }
    
    // Execution status
    enum ExecutionStatus {
        Pending,
        Completed,
        Failed
    }
    
    // AI Model structure
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
    
    // Execution record structure
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
    
    // Storage mappings
    mapping(uint256 => AIModel) public models;
    mapping(uint256 => ExecutionRecord) public executions;
    mapping(address => uint256[]) public userModels;
    mapping(address => uint256[]) public userExecutions;
    
    // Events
    event ModelRegistered(
        uint256 indexed modelId, 
        address indexed creator, 
        string name, 
        uint256 price
    );
    
    event ExecutionRequested(
        uint256 indexed executionId, 
        uint256 indexed modelId, 
        address indexed user,
        uint256 amount
    );
    
    event ExecutionCompleted(
        uint256 indexed executionId, 
        ExecutionStatus status,
        uint8 rating
    );
    
    event ModelRated(
        uint256 indexed modelId,
        uint256 indexed executionId,
        uint8 rating,
        address indexed user
    );
    
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    
    // Modifier to restrict access to oracle or owner
    modifier onlyOracleOrOwner() {
        require(msg.sender == oracle || msg.sender == owner(), "Not authorized");
        _;
    }
    
    constructor(
        address _paymentToken,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) Ownable(msg.sender) {
        require(_paymentToken != address(0), "Invalid payment token");
        paymentToken = IERC20(_paymentToken);
    }
    
    /**
     * @dev Check if a model exists
     * @param _modelId ID of the model to check
     * @return bool True if model exists
     */
    function modelExists(uint256 _modelId) public view returns (bool) {
        return _modelId > 0 && _modelId <= _modelIds.current() && models[_modelId].creator != address(0);
    }
    
    /**
     * @dev Set oracle address (only owner)
     * @param _oracle Address of the oracle service
     */
    function setOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle address");
        address oldOracle = oracle;
        oracle = _oracle;
        emit OracleUpdated(oldOracle, _oracle);
    }
    
    /**
     * @dev Core Function 1: Register AI Model
     * @param _name Model name
     * @param _description Model description
     * @param _modelHash IPFS hash of the model
     * @param _pricePerExecution Price per execution in payment tokens
     * @param _category Model category
     * @return modelId The ID of the registered model
     */
    function registerModel(
        string memory _name,
        string memory _description,
        string memory _modelHash,
        uint256 _pricePerExecution,
        ModelCategory _category
    ) external returns (uint256) {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_modelHash).length > 0, "Model hash cannot be empty");
        require(_pricePerExecution > 0, "Price must be greater than 0");
        
        _modelIds.increment();
        uint256 newModelId = _modelIds.current();
        
        // Create new model
        models[newModelId] = AIModel({
            modelId: newModelId,
            creator: msg.sender,
            name: _name,
            description: _description,
            modelHash: _modelHash,
            pricePerExecution: _pricePerExecution,
            totalExecutions: 0,
            rating: 0,
            ratingCount: 0,
            isActive: true,
            category: _category,
            createdAt: block.timestamp
        });
        
        // Track user's models
        userModels[msg.sender].push(newModelId);
        
        // Mint NFT to creator
        _safeMint(msg.sender, newModelId);
        
        emit ModelRegistered(newModelId, msg.sender, _name, _pricePerExecution);
        return newModelId;
    }
    
    /**
     * @dev Core Function 2: Execute AI Model
     * @param _modelId ID of the model to execute
     * @param _inputHash Hash of the input data
     * @return executionId The ID of the execution request
     */
    function executeModel(
        uint256 _modelId,
        string memory _inputHash
    ) external nonReentrant returns (uint256) {
        require(modelExists(_modelId), "Model does not exist");
        require(models[_modelId].isActive, "Model is not active");
        require(bytes(_inputHash).length > 0, "Input hash cannot be empty");
        
        AIModel storage model = models[_modelId];
        uint256 totalCost = model.pricePerExecution;
        
        // Transfer payment from user
        require(
            paymentToken.transferFrom(msg.sender, address(this), totalCost),
            "Payment transfer failed"
        );
        
        _executionIds.increment();
        uint256 newExecutionId = _executionIds.current();
        
        // Create execution record
        executions[newExecutionId] = ExecutionRecord({
            executionId: newExecutionId,
            modelId: _modelId,
            user: msg.sender,
            timestamp: block.timestamp,
            paidAmount: totalCost,
            status: ExecutionStatus.Pending,
            inputHash: _inputHash,
            outputHash: "",
            userRating: 0
        });
        
        // Track user's executions
        userExecutions[msg.sender].push(newExecutionId);
        
        emit ExecutionRequested(newExecutionId, _modelId, msg.sender, totalCost);
        return newExecutionId;
    }
    
    /**
     * @dev Core Function 3: Complete Execution (Oracle Only)
     * @param _executionId ID of the execution to complete
     * @param _status Final status of the execution
     * @param _outputHash Hash of the output data
     */
    function completeExecution(
        uint256 _executionId,
        ExecutionStatus _status,
        string memory _outputHash
    ) external onlyOracleOrOwner {
        require(_executionId <= _executionIds.current(), "Invalid execution ID");
        
        ExecutionRecord storage execution = executions[_executionId];
        require(execution.status == ExecutionStatus.Pending, "Already processed");
        
        // Update execution record
        execution.status = _status;
        execution.outputHash = _outputHash;
        
        AIModel storage model = models[execution.modelId];
        
        if (_status == ExecutionStatus.Completed) {
            // Increment total executions
            model.totalExecutions++;
            
            // Calculate payments
            uint256 totalCost = execution.paidAmount;
            uint256 platformCut = (totalCost * platformFee) / 10000;
            uint256 creatorCut = totalCost - platformCut;
            
            // Pay model creator
            require(
                paymentToken.transfer(model.creator, creatorCut),
                "Creator payment failed"
            );
            
        } else {
            // Refund user if execution failed
            require(
                paymentToken.transfer(execution.user, execution.paidAmount),
                "Refund failed"
            );
        }
        
        emit ExecutionCompleted(_executionId, _status, 0);
    }
    
    /**
     * @dev Rate a completed execution (User Only)
     * @param _executionId ID of the execution to rate
     * @param _rating User rating for the model (1-5)
     */
    function rateExecution(
        uint256 _executionId,
        uint8 _rating
    ) external {
        require(_executionId <= _executionIds.current(), "Invalid execution ID");
        require(_rating >= 1 && _rating <= 5, "Rating must be 1-5");
        
        ExecutionRecord storage execution = executions[_executionId];
        require(execution.user == msg.sender, "Not your execution");
        require(execution.status == ExecutionStatus.Completed, "Execution not completed");
        require(execution.userRating == 0, "Already rated");
        
        // Update execution rating
        execution.userRating = _rating;
        
        // Update model rating
        AIModel storage model = models[execution.modelId];
        uint256 totalRating = (model.rating * model.ratingCount) + (_rating * 100);
        model.ratingCount++;
        model.rating = totalRating / model.ratingCount;
        
        emit ExecutionCompleted(_executionId, ExecutionStatus.Completed, _rating);
        emit ModelRated(execution.modelId, _executionId, _rating, msg.sender);
    }
    
    // View functions
    function getModelsByCategory(ModelCategory _category) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256[] memory categoryModels = new uint256[](_modelIds.current());
        uint256 count = 0;
        
        for (uint256 i = 1; i <= _modelIds.current(); i++) {
            if (models[i].category == _category && models[i].isActive) {
                categoryModels[count] = i;
                count++;
            }
        }
        
        // Resize array
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = categoryModels[i];
        }
        
        return result;
    }
    
    function getUserModels(address _user) external view returns (uint256[] memory) {
        return userModels[_user];
    }
    
    function getUserExecutions(address _user) external view returns (uint256[] memory) {
        return userExecutions[_user];
    }
    
    function getTotalModels() external view returns (uint256) {
        return _modelIds.current();
    }
    
    function getTotalExecutions() external view returns (uint256) {
        return _executionIds.current();
    }
    
    // Owner functions
    function updatePlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 1000, "Fee cannot exceed 10%");
        platformFee = _newFee;
    }
    
    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = paymentToken.balanceOf(address(this));
        require(balance > 0, "No fees to withdraw");
        require(paymentToken.transfer(owner(), balance), "Transfer failed");
    }
    
    function emergencyToggleModel(uint256 _modelId) external onlyOwner {
        require(modelExists(_modelId), "Model does not exist");
        models[_modelId].isActive = !models[_modelId].isActive;
    }
}
