//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "./interfaces/ISubjectsRegistryV1.sol";
import "./SubjectSharesV1.sol";

contract SubjectsRegistryV1 is ISubjectsRegistryV1, Ownable {
    error PoolCreationFailed();
    error SubjectRegistered();
    error InvalidInputs();

    address public protocolFeeDestination;
    mapping(address => uint16) public protocolFeeRates;//In basis points
    mapping(address => bool) public isBlacklisted;
    mapping(address => address) public bondingPair;
    IERC20 public immutable JOKER_TOKEN;
    
    event SharePoolCreation(address subject, address subjectSharePool, string symbol);

    constructor (IERC20 _jokerToken) {
        JOKER_TOKEN = _jokerToken;
    }

    function addToRegistry(
        address _subject,
        address _subjectOwner,
        uint256 _seed,
        string memory _name,
        string memory _symbol,
        uint112 _maxSupply,  
        uint256 _halfMaxprice,
        uint112 _midwaySupply
        ) external returns (address) {
        if(bondingPair[_subject] != address(0)) revert SubjectRegistered();
        bytes32 _salt = bytes32(uint256(keccak256(abi.encodePacked(block.chainid, _subject, _seed, _name, _symbol))));
       
        SubjectSharesV1 newSharePool = new SubjectSharesV1{salt: _salt}(
            JOKER_TOKEN,
            _subjectOwner, 
            _name, 
            _symbol, 
            _maxSupply, 
            _halfMaxprice, 
            _midwaySupply
            );
        address _newSharePool = address(newSharePool);
        if(_newSharePool == address(0)) revert PoolCreationFailed();
        
        protocolFeeRates[_newSharePool] = 25;// 1/6 cut of trading fees
        bondingPair[_newSharePool] = _subject;
        

        emit SharePoolCreation(_subject, _newSharePool, _symbol);

        return _newSharePool;
    }

    function blacklist(address _evilPool, bool _isBlacklisted) external onlyOwner { 
        if(bondingPair[_evilPool] == address(0)) revert InvalidInputs();
        isBlacklisted[_evilPool] = _isBlacklisted;
        SubjectSharesV1(_evilPool).updatePoolStatus(true);
        
    }

    function setProtocolFeeDestination(address _protocolFeeDestination) external onlyOwner{
        protocolFeeDestination =_protocolFeeDestination;
    }

    //In basis points
    function setProtocolFeeRate(address _subjectSharePool, uint16 _protocolFeeRate) external onlyOwner {
        if(_protocolFeeRate > 150) revert InvalidInputs();
        protocolFeeRates[_subjectSharePool] = _protocolFeeRate;
        SubjectSharesV1(_subjectSharePool).updateProtocolFeeRate(_protocolFeeRate);
    }
}