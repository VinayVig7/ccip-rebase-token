// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    // We need to pass the token address to the constructor
    // create a deposit function that mints tokens to the user equal to the amount of the ETH the user has sent.
    // create a redeem function that burns token from the user and sends the user ETH
    // create a way to add rewards to the vault

    ////////////
    // Errors //
    ///////////
    error Vault__RedeemFailed();    

    /////////////////////
    // State Variables //
    ////////////////////
    IRebaseToken private immutable i_rebaseToken;

    ////////////
    // Events //
    ///////////
    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    ///////////////
    // Functions //
    //////////////
    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice Allows users to deposit ETH into the vault and mint rebase tokens in return
     */
    function deposit() external payable {
        // we need to use the amount of ETH the user has sent to mint tokens to the user
        uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Allows users to redeem their rebase tokens for ETH
     * @param _amount The amount of rebase tokens to redeem
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        // 1. burn the tokens from the user
        i_rebaseToken.burn(msg.sender, _amount);

        // 2. we need to send the user ETH
        (bool success,) = payable(msg.sender).call{value: _amount}(""); 
        if (!success){
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice Get the address of the rebase token
     * @return The address of the rebase token
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
