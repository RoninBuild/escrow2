// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Escrow.sol";

/**
 * @title EscrowFactory
 * @notice Factory for creating and tracking escrow deals
 * @dev Maintains registry of all escrows and emits events for indexing
 */
contract EscrowFactory {
    // Allowed tokens (USDC on Base)
    mapping(address => bool) public allowedTokens;
    address public owner;

    // Registry
    address[] public allEscrows;
    mapping(address => address[]) public buyerEscrows;
    mapping(address => address[]) public sellerEscrows;

    // Events
    event EscrowCreated(
        address indexed escrowAddress,
        uint256 indexed escrowId,
        address indexed buyer,
        address seller,
        address token,
        uint256 amount,
        uint256 deadline,
        address arbiter,
        bytes32 memoHash
    );

    event TokenAllowed(address indexed token, bool allowed);

    constructor(address _initialToken) {
        owner = msg.sender;
        allowedTokens[_initialToken] = true;
        emit TokenAllowed(_initialToken, true);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /**
     * @notice Create new escrow deal
     * @param seller Address of seller
     * @param token Token address (must be allowed)
     * @param amount Amount to escrow
     * @param deadline Unix timestamp deadline
     * @param arbiter Optional arbiter address (0x0 for none)
     * @param memoHash Hash of deal description
     * @return escrowAddress Address of created escrow contract
     */
    function createEscrow(
        address seller,
        address token,
        uint256 amount,
        uint256 deadline,
        address arbiter,
        bytes32 memoHash
    ) external returns (address escrowAddress) {
        require(allowedTokens[token], "Token not allowed");

        // Create new Escrow contract
        Escrow escrow = new Escrow(
            msg.sender, // buyer
            seller,
            token,
            amount,
            deadline,
            arbiter,
            memoHash
        );

        escrowAddress = address(escrow);
        uint256 escrowId = allEscrows.length;

        // Register
        allEscrows.push(escrowAddress);
        buyerEscrows[msg.sender].push(escrowAddress);
        sellerEscrows[seller].push(escrowAddress);

        emit EscrowCreated(
            escrowAddress,
            escrowId,
            msg.sender,
            seller,
            token,
            amount,
            deadline,
            arbiter,
            memoHash
        );

        return escrowAddress;
    }

    /**
     * @notice Set token allowlist status
     */
    function setTokenAllowed(address token, bool allowed) external onlyOwner {
        allowedTokens[token] = allowed;
        emit TokenAllowed(token, allowed);
    }

    /**
     * @notice Get total number of escrows created
     */
    function getEscrowCount() external view returns (uint256) {
        return allEscrows.length;
    }

    /**
     * @notice Get escrows for a buyer
     */
    function getBuyerEscrows(address _buyer) external view returns (address[] memory) {
        return buyerEscrows[_buyer];
    }

    /**
     * @notice Get escrows for a seller
     */
    function getSellerEscrows(address _seller) external view returns (address[] memory) {
        return sellerEscrows[_seller];
    }

    /**
     * @notice Get escrow by ID
     */
    function getEscrowById(uint256 id) external view returns (address) {
        require(id < allEscrows.length, "Invalid ID");
        return allEscrows[id];
    }
}
