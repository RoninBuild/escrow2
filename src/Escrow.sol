// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Escrow
 * @notice Single escrow deal between buyer and seller with optional arbiter
 * @dev Handles USDC escrow with deadline-based refunds and dispute resolution
 */
contract Escrow is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Status {
        CREATED,    // Deal created, awaiting funding
        FUNDED,     // Funds locked in contract
        RELEASED,   // Funds released to seller
        REFUNDED,   // Funds returned to buyer
        DISPUTED,   // Dispute opened
        RESOLVED    // Dispute resolved by arbiter
    }

    // Deal parameters
    address public immutable buyer;
    address public immutable seller;
    address public immutable token;
    uint256 public immutable amount;
    uint256 public immutable deadline;
    address public immutable arbiter; // address(0) if no arbiter
    bytes32 public immutable memoHash;

    // State
    Status public status;
    uint256 public fundedAt;

    // Events
    event Funded(uint256 amount, uint256 timestamp);
    event Released(uint256 amount, uint256 timestamp);
    event Refunded(uint256 amount, uint256 timestamp);
    event DisputeOpened(address indexed initiator, uint256 timestamp);
    event DisputeResolved(address indexed winner, uint256 amount, uint256 timestamp);

    // Errors
    error Unauthorized();
    error InvalidStatus();
    error DeadlineNotPassed();
    error DeadlinePassed();
    error NoArbiter();
    error InvalidAmount();

    constructor(
        address _buyer,
        address _seller,
        address _token,
        uint256 _amount,
        uint256 _deadline,
        address _arbiter,
        bytes32 _memoHash
    ) {
        require(_buyer != address(0), "Invalid buyer");
        require(_seller != address(0), "Invalid seller");
        require(_buyer != _seller, "Buyer and seller must differ");
        require(_token != address(0), "Invalid token");
        require(_amount > 0, "Amount must be > 0");
        require(_deadline > block.timestamp, "Deadline must be in future");

        buyer = _buyer;
        seller = _seller;
        token = _token;
        amount = _amount;
        deadline = _deadline;
        arbiter = _arbiter;
        memoHash = _memoHash;
        status = Status.CREATED;
    }

    /**
     * @notice Fund the escrow (buyer deposits tokens)
     * @dev Requires prior approval of tokens
     */
    function fund() external nonReentrant {
        if (msg.sender != buyer) revert Unauthorized();
        if (status != Status.CREATED) revert InvalidStatus();
        if (block.timestamp >= deadline) revert DeadlinePassed();

        status = Status.FUNDED;
        fundedAt = block.timestamp;

        IERC20(token).safeTransferFrom(buyer, address(this), amount);

        emit Funded(amount, block.timestamp);
    }

    /**
     * @notice Release funds to seller (happy path)
     * @dev Only buyer can release. Sends 0.5% fee to arbiter if set.
     */
    function release() external nonReentrant {
        if (msg.sender != buyer) revert Unauthorized();
        if (status != Status.FUNDED) revert InvalidStatus();

        status = Status.RELEASED;

        uint256 fee = 0;
        if (arbiter != address(0)) {
            fee = (amount * 5) / 1000;
            IERC20(token).safeTransfer(arbiter, fee);
        }

        IERC20(token).safeTransfer(seller, amount - fee);

        emit Released(amount, block.timestamp);
    }

    /**
     * @notice Refund to buyer after deadline passes
     * @dev Can be called by buyer or anyone (funds go to buyer regardless)
     */
    function refundAfterDeadline() external nonReentrant {
        if (status != Status.FUNDED) revert InvalidStatus();
        if (block.timestamp < deadline) revert DeadlineNotPassed();

        status = Status.REFUNDED;

        IERC20(token).safeTransfer(buyer, amount);

        emit Refunded(amount, block.timestamp);
    }

    /**
     * @notice Open a dispute (requires arbiter to be set)
     * @dev Can be called by buyer or seller
     */
    function openDispute() external {
        if (msg.sender != buyer && msg.sender != seller) revert Unauthorized();
        if (status != Status.FUNDED) revert InvalidStatus();
        if (arbiter == address(0)) revert NoArbiter();

        status = Status.DISPUTED;

        emit DisputeOpened(msg.sender, block.timestamp);
    }

    /**
     * @notice Resolve dispute (arbiter decides winner)
     * @param _payToSeller If true, pay seller; if false, refund buyer
     */
    function resolve(bool _payToSeller) external nonReentrant {
        if (msg.sender != arbiter) revert Unauthorized();
        if (status != Status.DISPUTED) revert InvalidStatus();

        status = Status.RESOLVED;

        uint256 fee = (amount * 5) / 1000;
        IERC20(token).safeTransfer(arbiter, fee);

        address winner = _payToSeller ? seller : buyer;
        IERC20(token).safeTransfer(winner, amount - fee);

        emit DisputeResolved(winner, amount, block.timestamp);
    }

    /**
     * @notice Get current deal info
     */
    function getDealInfo()
        external
        view
        returns (
            address _buyer,
            address _seller,
            address _token,
            uint256 _amount,
            uint256 _deadline,
            address _arbiter,
            bytes32 _memoHash,
            Status _status,
            uint256 _fundedAt
        )
    {
        return (buyer, seller, token, amount, deadline, arbiter, memoHash, status, fundedAt);
    }
}
