// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {ICartesiDAppFactory} from "@cartesi/rollups/contracts/dapp/ICartesiDAppFactory.sol";
import {CartesiDApp} from "@cartesi/rollups/contracts/dapp/CartesiDApp.sol";
import {IInputBox} from "@cartesi/rollups/contracts/inputs/IInputBox.sol";


/// @title DAppSharding
/// @notice Generic contract for creating child DApp shards for a parent main Cartesi DApp
contract DAppSharding {

    ICartesiDAppFactory internal factory;
    IInputBox internal inputBox;


    /// @notice Constructor
    /// @param _factory factory to create DApp shards
    /// @param _inputBox input box to send inputs to Cartesi DApps
    constructor(ICartesiDAppFactory _factory, IInputBox _inputBox) {
        factory = _factory;
        inputBox = _inputBox;
    }


    /// @notice Returns salt used to deterministically calculate shard addresses
    /// @dev Used internally by other methods for consistency
    /// @param _mainDApp Address of the target application for receiving shard outputs
    /// @param _templateHash Template hash for the shard's Cartesi Machine
    /// @param _id Shard identifier
    /// @return salt
    function calculateShardSalt(
        address _mainDApp,
        bytes32 _templateHash,
        bytes32 _id
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_mainDApp, _templateHash, _id));
    }


    /// @notice Calculates deterministic address for a DApp shard
    /// @dev Should be called by clients to allow them to send inputs even if shard is not created
    /// @param _mainDApp Address of the target application for receiving shard outputs
    /// @param _templateHash Template hash for the shard's Cartesi Machine
    /// @param _id Shard identifier
    /// @return address
    function calculateShardAddress(
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
            calculateShardSalt(_mainDApp, _templateHash, _id)
        );
    }

    
    /// @notice Create DApp shard using a deterministic address
    /// @dev Called by clients to create a shard to process inputs when necessary
    /// @param _mainDApp Address of the target application for receiving shard outputs
    /// @param _templateHash Template hash for the shard's Cartesi Machine
    /// @param _id Shard identifier
    /// @return address
    function createShard(
        address payable _mainDApp,
        bytes32 _templateHash,
        bytes32 _id
    )
        external
        returns (CartesiDApp)
    {
        CartesiDApp shard = factory.newApplication(
            CartesiDApp(_mainDApp).getConsensus(),
            address(this),
            _templateHash,
            calculateShardSalt(_mainDApp, _templateHash, _id)
        );

        // inform mainDApp about new shard
        inputBox.addInput(
            _mainDApp,
            abi.encodePacked(
                address(shard), // shard address
                msg.sender,     // shard creator
                _templateHash,  // templateHash used by the shard
                _id             // shard identifier
            )
        );

        // inform shard about target mainDApp's address
        // - this way, the shard can emit vouchers directly to the mainDApp
        inputBox.addInput(address(shard), abi.encodePacked(_mainDApp));

        return shard;
    }
}
