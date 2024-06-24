// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../contracts/RebasingERC20.sol";
import "forge-std/Test.sol";

/**
 * @title Rebasing Token Challenge Auto-Grading Tests
 * @author BUIDL GUIDL
 * @notice These tests will be used to autograde the challenge within the tech tree. This test file is PURELY EDUCATIONAL, and is not to be used in production code. It is up to the user's discretion to make their own production code, run tests, have audits, etc.
 */
contract RebasingERC20Test is Test {
    RebasingERC20 token;
    // King of the Pirates
    address luffy;
    // World's Greatest Swordsman
    address zoro;
    uint256 luffyBalance1;
    uint256 zoroBalance1;
    uint256 initialBalance;

    /**
     * @dev Emitted when a rebase occurs.
     * @param totalSupply The new total supply of the token after the rebase.
     */
    event Rebase(uint256 totalSupply);

    function setUp() public {
        luffy = address(this);
        zoro = address(0x123);
        token = new RebasingERC20();
        token.transfer(zoro, 1000 * 10 ** token.decimals());
        luffyBalance1 = token.balanceOf(luffy);
        zoroBalance1 = token.balanceOf(zoro);
        initialBalance = 1000000 * 10 ** token.decimals();
    }

    function testInitialSupply() public {
        assertEq(token.totalSupply(), initialBalance);
        assertEq(token.balanceOf(luffy), 999000 * 10 ** token.decimals());
        assertEq(token.balanceOf(zoro), 1000 * 10 ** token.decimals());
    }

    function testTransfer(uint256 transferAmount) public {
        transferAmount = bound(transferAmount, 1e18, 100e18);
        token.transfer(zoro, transferAmount);
        assertEq(token.balanceOf(luffy), luffyBalance1 - transferAmount);
        assertEq(token.balanceOf(zoro), zoroBalance1 + transferAmount);
    }

    function testApproveAndTransferFrom() public {
        uint256 approveAmount = 500 * 10 ** token.decimals();
        uint256 transferAmount = 300 * 10 ** token.decimals();
        token.approve(zoro, approveAmount);
        assertEq(token.allowance(luffy, zoro), approveAmount);

        // Simulate `transferFrom` by the zoro
        vm.prank(zoro);
        token.transferFrom(luffy, zoro, transferAmount);
        assertEq(token.balanceOf(luffy), luffyBalance1 - transferAmount);
        assertEq(token.balanceOf(zoro), zoroBalance1 + transferAmount);
        assertEq(token.allowance(luffy, zoro), approveAmount - transferAmount);
    }

    function testRebasePositive() public {
        int256 supplyDelta = int256(initialBalance);
        uint256 oldTotalSupply = token.totalSupply();
        uint256 expectedTotalSupply = oldTotalSupply + initialBalance;
        
        vm.expectEmit(true, false, false, true);
        emit Rebase(expectedTotalSupply);
        token.rebase(supplyDelta);
        uint256 newTotalSupply = token.totalSupply();

        assertEq(newTotalSupply, oldTotalSupply + uint256(supplyDelta));
        assertEq(token.balanceOf(luffy), luffyBalance1 * (newTotalSupply) / oldTotalSupply);
        assertEq(token.balanceOf(zoro), (zoroBalance1 * newTotalSupply) / oldTotalSupply);
    }

    function testRebaseNegative() public {
        int256 supplyDelta = -int256(initialBalance);
        uint256 oldTotalSupply = token.totalSupply();
        uint256 expectedTotalSupply = oldTotalSupply - initialBalance;
        
        vm.expectEmit(true, false, false, true);
        emit Rebase(expectedTotalSupply);
        token.rebase(supplyDelta);
        uint256 newTotalSupply = token.totalSupply();

        assertEq(newTotalSupply, oldTotalSupply - uint256(-supplyDelta));
        assertEq(token.balanceOf(luffy), (luffyBalance1 * newTotalSupply) / oldTotalSupply);
        assertEq(token.balanceOf(zoro), (zoroBalance1 * newTotalSupply) / oldTotalSupply);
    }

    /**
     * Test that rounding errors don't arise
     */
    function testRoundingErrors() public {
        // Perform multiple small transfers to check for rounding errors
        uint256 transferAmount = 1 * 10 ** token.decimals(); // Small transfer amount
        uint256 numTransfers = 1000;

        for (uint256 i = 0; i < numTransfers; i++) {
            vm.prank(luffy);
            token.transfer(zoro, transferAmount);

            vm.prank(zoro);
            token.transfer(luffy, transferAmount);
        }

        // Check balances after multiple small transfers
        uint256 finalLuffyBalance = token.balanceOf(luffy);
        uint256 finalZoroBalance = token.balanceOf(zoro);

        // Check for rounding errors
        // TODO - check end resultant math
        assertEq(finalLuffyBalance, (token.totalSupply() - 1000 * 10 ** token.decimals()) * token._scalingFactor() / (1e18));
        assertEq(finalZoroBalance, ( 1000 * 10 ** token.decimals() * token._scalingFactor() / (1e18)));
    }

    /// TODO 
    function testTransferAfterRebase() public {

    }

    /// TODO 
    function testTransferFromAfterRebase() public {

    }

    /// TODO - unsure if minting is affected with scaling factor etc.
    function testMint() public {

    }

    /// TODO - unsure if minting is affected with scaling factor etc.
    function testBurn() public {

    }


    // Not Happy Path Tests

    function testFailTransferInsufficientBalance() public {
        // User tries to transfer more tokens than they have
        vm.prank(zoro);
        vm.expectRevert(bytes(abi.encodeWithSelector(RebasingERC20.RebasingERC20__InsufficientBalance.selector, zoro, 2000 * 10 ** token.decimals())));
        token.transfer(luffy, 2000 * 10 ** token.decimals());
    }

    function testRebaseNotOwner() public {
        // Non-owner tries to rebase the contract
        vm.prank(zoro);
        vm.expectRevert("Ownable: caller is not the owner");
        token.rebase(1000);
    }

    function testFailRebaseBadSupplyDelta() public {
        // Owner tries to rebase the contract with a bad value for supplyDelta
        vm.startPrank(luffy);
        vm.expectRevert(bytes(abi.encodeWithSelector(RebasingERC20.RebasingERC20__InvalidSupplyDelta.selector, type(int256).min)));
        token.rebase(type(int256).min);
        vm.stopPrank();
    }
}
