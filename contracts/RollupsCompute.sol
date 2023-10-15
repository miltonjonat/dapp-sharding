// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {ICartesiDAppFactory} from "@cartesi/rollups/contracts/dapp/ICartesiDAppFactory.sol";
import {CartesiDApp} from "@cartesi/rollups/contracts/dapp/CartesiDApp.sol";
import {IInputBox} from "@cartesi/rollups/contracts/inputs/IInputBox.sol";


/// @title RollupsCompute
/// @notice Generic contract for creating child computation instances for a parent main Cartesi DApp
contract RollupsCompute {

    ICartesiDAppFactory internal factory;
    IInputBox internal inputBox;


    /// @notice Constructor
    /// @param _factory factory to create computation instances
    /// @param _inputBox input box to send inputs to Cartesi DApps
    constructor(ICartesiDAppFactory _factory, IInputBox _inputBox) {
        factory = _factory;
        inputBox = _inputBox;
    }


    /// @notice Returns salt used to deterministically calculate instance addresses
    /// @dev Used internally by other methods for consistency
    /// @param _mainDApp Address of the target application for receiving instance outputs
    /// @param _templateHash Template hash for the instance's Cartesi Machine
    /// @param _id Instance identifier
    /// @return salt
    function calculateSalt(
        address _mainDApp,
        bytes32 _templateHash,
        bytes32 _id
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_mainDApp, _templateHash, _id));
    }


    /// @notice Calculates deterministic address for a computation instance
    /// @dev Should be called by clients to allow them to send inputs even if instance is not created
    /// @param _mainDApp Address of the target application for receiving instance outputs
    /// @param _templateHash Template hash for the instance's Cartesi Machine
    /// @param _id Instance identifier
    /// @return address
    function calculateInstanceAddress(
        address payable _mainDApp,
        bytes32 _templateHash,
        bytes32 _id
    )
        external view
        returns (address)
    {
        return factory.calculateApplicationAddress(
            CartesiDApp(_mainDApp).getConsensus(),
            address(this),
            _templateHash,
            calculateSalt(_mainDApp, _templateHash, _id)
        );
    }

    
    /// @notice Created computation instance using a deterministic address
    /// @dev Called by clients to create an instance to process inputs when necessary
    /// @param _mainDApp Address of the target application for receiving instance outputs
    /// @param _templateHash Template hash for the instance's Cartesi Machine
    /// @param _id Instance identifier
    /// @return address
    function instantiate(
        address payable _mainDApp,
        bytes32 _templateHash,
        bytes32 _id
    )
        external
        returns (CartesiDApp)
    {
        CartesiDApp dapp = factory.newApplication(
            CartesiDApp(_mainDApp).getConsensus(),
            address(this),
            _templateHash,
            calculateSalt(_mainDApp, _templateHash, _id)
        );

        // inform mainDApp about instantiation
        inputBox.addInput(
            _mainDApp,
            abi.encodePacked(
                address(dapp),  // instance address
                msg.sender,     // instantiator
                _templateHash,  // templateHash used by the instance
                _id             // instance identifier
            )
        );

        // inform instance about target mainDApp's address
        // - this way, the instance can emit vouchers directly to the mainDApp
        inputBox.addInput(address(dapp), abi.encodePacked(_mainDApp));

        return dapp;
    }
}
