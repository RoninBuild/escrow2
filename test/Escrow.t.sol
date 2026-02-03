// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/EscrowFactory.sol";
import "../src/Escrow.sol";

// Mock ERC20 for testing
contract MockUSDC is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    string public constant name = "USD Coin";
    string public constant symbol = "USDC";
    uint8 public constant decimals = 6;

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        _totalSupply += amount;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        return true;
    }
}

contract EscrowTest is Test {
    EscrowFactory public factory;
    MockUSDC public usdc;

    address public buyer = address(0x1);
    address public seller = address(0x2);
    address public arbiter = address(0x3);
    address public other = address(0x4);

    uint256 public constant AMOUNT = 100e6; // 100 USDC
    uint256 public deadline;
    bytes32 public constant MEMO_HASH = keccak256("Test deal memo");

    function setUp() public {
        // Deploy contracts
        usdc = new MockUSDC();
        factory = new EscrowFactory(address(usdc));

        // Disable swap for tests to trigger USDC fallback
        factory.setSwapRouter(address(0));

        // Setup deadline (1 hour from now)
        deadline = block.timestamp + 1 hours;

        // Mint USDC to buyer
        usdc.mint(buyer, 1000e6);
    }

    // ==================== FACTORY TESTS ====================

    function test_CreateEscrow() public {
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            arbiter,
            MEMO_HASH
        );

        assertTrue(escrowAddr != address(0));
        assertEq(factory.getEscrowCount(), 1);

        Escrow escrow = Escrow(escrowAddr);
        assertEq(escrow.buyer(), buyer);
        assertEq(escrow.seller(), seller);
        assertEq(escrow.amount(), AMOUNT);
    }

    function test_CreateEscrow_WithoutArbiter() public {
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            address(0), // no arbiter
            MEMO_HASH
        );

        Escrow escrow = Escrow(escrowAddr);
        assertEq(escrow.arbiter(), address(0));
    }

    function test_RevertCreateEscrow_TokenNotAllowed() public {
        address badToken = address(0x999);

        vm.prank(buyer);
        vm.expectRevert("Token not allowed");
        factory.createEscrow(seller, badToken, AMOUNT, deadline, arbiter, MEMO_HASH);
    }

    // ==================== FUNDING TESTS ====================

    function test_Fund_Success() public {
        // Create escrow
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            arbiter,
            MEMO_HASH
        );
        Escrow escrow = Escrow(escrowAddr);

        // Approve and fund
        vm.startPrank(buyer);
        usdc.approve(escrowAddr, AMOUNT);
        escrow.fund();
        vm.stopPrank();

        assertEq(uint256(escrow.status()), uint256(Escrow.Status.FUNDED));
        assertEq(usdc.balanceOf(escrowAddr), AMOUNT);
    }

    function test_RevertFund_NotBuyer() public {
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            arbiter,
            MEMO_HASH
        );
        Escrow escrow = Escrow(escrowAddr);

        vm.prank(other);
        vm.expectRevert(Escrow.Unauthorized.selector);
        escrow.fund();
    }

    function test_RevertFund_AfterDeadline() public {
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            arbiter,
            MEMO_HASH
        );
        Escrow escrow = Escrow(escrowAddr);

        // Warp past deadline
        vm.warp(deadline + 1);

        vm.startPrank(buyer);
        usdc.approve(escrowAddr, AMOUNT);
        vm.expectRevert(Escrow.DeadlinePassed.selector);
        escrow.fund();
        vm.stopPrank();
    }

    // ==================== RELEASE TESTS ====================

    function test_Release_Success() public {
        // Create and fund escrow
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            arbiter,
            MEMO_HASH
        );
        Escrow escrow = Escrow(escrowAddr);

        vm.startPrank(buyer);
        usdc.approve(escrowAddr, AMOUNT);
        escrow.fund();

        // Release
        uint256 sellerBalanceBefore = usdc.balanceOf(seller);
        escrow.release();
        vm.stopPrank();

        assertEq(uint256(escrow.status()), uint256(Escrow.Status.RELEASED));
        
        // Calculate expected fee
        uint256 expectedFee = (AMOUNT * factory.arbiterFeeBps()) / 10000;
        assertEq(usdc.balanceOf(seller), sellerBalanceBefore + AMOUNT - expectedFee);
        assertEq(usdc.balanceOf(arbiter), expectedFee); // Fallback to USDC in mock
    }

    function test_RevertRelease_NotBuyer() public {
        // Create and fund
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            arbiter,
            MEMO_HASH
        );
        Escrow escrow = Escrow(escrowAddr);

        vm.startPrank(buyer);
        usdc.approve(escrowAddr, AMOUNT);
        escrow.fund();
        vm.stopPrank();

        // Try to release as seller
        vm.prank(seller);
        vm.expectRevert(Escrow.Unauthorized.selector);
        escrow.release();
    }

    // ==================== REFUND TESTS ====================

    function test_RefundAfterDeadline_Success() public {
        // Create and fund
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            arbiter,
            MEMO_HASH
        );
        Escrow escrow = Escrow(escrowAddr);

        vm.startPrank(buyer);
        usdc.approve(escrowAddr, AMOUNT);
        escrow.fund();
        vm.stopPrank();

        // Warp past deadline
        vm.warp(deadline + 1);

        // Refund (can be called by anyone)
        uint256 buyerBalanceBefore = usdc.balanceOf(buyer);
        vm.prank(other);
        escrow.refundAfterDeadline();

        assertEq(uint256(escrow.status()), uint256(Escrow.Status.REFUNDED));
        assertEq(usdc.balanceOf(buyer), buyerBalanceBefore + AMOUNT);
    }

    function test_RevertRefund_BeforeDeadline() public {
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            arbiter,
            MEMO_HASH
        );
        Escrow escrow = Escrow(escrowAddr);

        vm.startPrank(buyer);
        usdc.approve(escrowAddr, AMOUNT);
        escrow.fund();
        vm.stopPrank();

        // Try to refund before deadline
        vm.prank(buyer);
        vm.expectRevert(Escrow.DeadlineNotPassed.selector);
        escrow.refundAfterDeadline();
    }

    // ==================== DISPUTE TESTS ====================

    function test_OpenDispute_Success() public {
        // Create and fund
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            arbiter,
            MEMO_HASH
        );
        Escrow escrow = Escrow(escrowAddr);

        vm.startPrank(buyer);
        usdc.approve(escrowAddr, AMOUNT);
        escrow.fund();
        vm.stopPrank();

        // Open dispute as buyer
        vm.prank(buyer);
        escrow.openDispute();

        assertEq(uint256(escrow.status()), uint256(Escrow.Status.DISPUTED));
    }

    function test_OpenDispute_BySeller() public {
        // Create and fund
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            arbiter,
            MEMO_HASH
        );
        Escrow escrow = Escrow(escrowAddr);

        vm.startPrank(buyer);
        usdc.approve(escrowAddr, AMOUNT);
        escrow.fund();
        vm.stopPrank();

        // Open dispute as seller
        vm.prank(seller);
        escrow.openDispute();

        assertEq(uint256(escrow.status()), uint256(Escrow.Status.DISPUTED));
    }

    function test_RevertOpenDispute_NoArbiter() public {
        // Create without arbiter
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            address(0), // no arbiter
            MEMO_HASH
        );
        Escrow escrow = Escrow(escrowAddr);

        vm.startPrank(buyer);
        usdc.approve(escrowAddr, AMOUNT);
        escrow.fund();
        vm.stopPrank();

        // Try to dispute
        vm.prank(buyer);
        vm.expectRevert(Escrow.NoArbiter.selector);
        escrow.openDispute();
    }

    function test_RevertOpenDispute_Unauthorized() public {
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            arbiter,
            MEMO_HASH
        );
        Escrow escrow = Escrow(escrowAddr);

        vm.startPrank(buyer);
        usdc.approve(escrowAddr, AMOUNT);
        escrow.fund();
        vm.stopPrank();

        // Try to dispute as other
        vm.prank(other);
        vm.expectRevert(Escrow.Unauthorized.selector);
        escrow.openDispute();
    }

    // ==================== RESOLVE TESTS ====================

    function test_Resolve_PaySeller() public {
        // Create, fund, and dispute
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            arbiter,
            MEMO_HASH
        );
        Escrow escrow = Escrow(escrowAddr);

        vm.startPrank(buyer);
        usdc.approve(escrowAddr, AMOUNT);
        escrow.fund();
        escrow.openDispute();
        vm.stopPrank();

        // Resolve in favor of seller
        uint256 sellerBalanceBefore = usdc.balanceOf(seller);
        vm.prank(arbiter);
        escrow.resolve(true);

        assertEq(uint256(escrow.status()), uint256(Escrow.Status.RESOLVED));
        
        uint256 expectedFee = (AMOUNT * factory.arbiterFeeBps()) / 10000;
        assertEq(usdc.balanceOf(seller), sellerBalanceBefore + AMOUNT - expectedFee);
        assertEq(usdc.balanceOf(arbiter), expectedFee);
    }

    function test_Resolve_RefundBuyer() public {
        // Create, fund, and dispute
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            arbiter,
            MEMO_HASH
        );
        Escrow escrow = Escrow(escrowAddr);

        vm.startPrank(buyer);
        usdc.approve(escrowAddr, AMOUNT);
        escrow.fund();
        escrow.openDispute();
        vm.stopPrank();

        // Resolve in favor of buyer
        uint256 buyerBalanceBefore = usdc.balanceOf(buyer);
        vm.prank(arbiter);
        escrow.resolve(false);

        assertEq(uint256(escrow.status()), uint256(Escrow.Status.RESOLVED));
        
        uint256 expectedFee = (AMOUNT * factory.arbiterFeeBps()) / 10000;
        assertEq(usdc.balanceOf(buyer), buyerBalanceBefore + AMOUNT - expectedFee);
        assertEq(usdc.balanceOf(arbiter), expectedFee);
    }

    function test_RevertResolve_NotArbiter() public {
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            arbiter,
            MEMO_HASH
        );
        Escrow escrow = Escrow(escrowAddr);

        vm.startPrank(buyer);
        usdc.approve(escrowAddr, AMOUNT);
        escrow.fund();
        escrow.openDispute();
        vm.stopPrank();

        // Try to resolve as buyer
        vm.prank(buyer);
        vm.expectRevert(Escrow.Unauthorized.selector);
        escrow.resolve(true);
    }

    function test_RevertResolve_NotDisputed() public {
        vm.prank(buyer);
        address escrowAddr = factory.createEscrow(
            seller,
            address(usdc),
            AMOUNT,
            deadline,
            arbiter,
            MEMO_HASH
        );
        Escrow escrow = Escrow(escrowAddr);

        vm.startPrank(buyer);
        usdc.approve(escrowAddr, AMOUNT);
        escrow.fund();
        vm.stopPrank();

        // Try to resolve without dispute
        vm.prank(arbiter);
        vm.expectRevert(Escrow.InvalidStatus.selector);
        escrow.resolve(true);
    }

    // ==================== REGISTRY TESTS ====================

    function test_BuyerEscrows() public {
        // Create 2 escrows as buyer
        vm.startPrank(buyer);
        factory.createEscrow(seller, address(usdc), AMOUNT, deadline, arbiter, MEMO_HASH);
        factory.createEscrow(seller, address(usdc), AMOUNT * 2, deadline, arbiter, MEMO_HASH);
        vm.stopPrank();

        address[] memory buyerEscrows = factory.getBuyerEscrows(buyer);
        assertEq(buyerEscrows.length, 2);
    }

    function test_SellerEscrows() public {
        // Create escrows with different sellers
        vm.startPrank(buyer);
        factory.createEscrow(seller, address(usdc), AMOUNT, deadline, arbiter, MEMO_HASH);
        factory.createEscrow(seller, address(usdc), AMOUNT, deadline, arbiter, MEMO_HASH);
        vm.stopPrank();

        address[] memory sellerEscrows = factory.getSellerEscrows(seller);
        assertEq(sellerEscrows.length, 2);
    }
}
