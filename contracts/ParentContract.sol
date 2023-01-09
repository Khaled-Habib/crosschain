// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./interfaces/IAMB.sol";
import "./interfaces/IAMBReceiver.sol";

contract ParentContract is IAMB {
    // sending and Receiving function entrance security parameters
    uint8 internal constant _NOT_ENTERED = 1;
    uint8 internal constant _ENTERED = 2;

    // Reentrancy guard parameters  
    uint8 internal _send_entered_state = 1;
    uint8 internal _receive_entered_state = 1;

    // this mapping stores the addresses of the trusted counter contracts deployed 
    mapping(address => address) public trustedAddresses;

    uint16 public chainId;

    // gas-fee configurtions
    RelayerFeeConfig public relayerFeeConfig;
    bytes public defaultAdapterParams;

    // keeps track for in and out Nonce for security 
    mapping(uint16 => mapping(bytes => uint64)) public inboundNonce;
    mapping(uint16 => mapping(address => uint64))  public outboundNonce;
    
    // the structs will hold all fee parameters for source-chain and destination-chain 

    struct RelayerFeeConfig {
        uint128 dstPriceRatio; 
        uint128 dstGasPriceInWei;
        uint128 dstNativeAmtCap;
        uint64 baseGas;
        uint64 gasPerByte;
    }
    //Security modifiers 
    modifier sendNonReentrant() {
        require(_send_entered_state == _NOT_ENTERED, "Succinct: no reentrancy");
        _send_entered_state = _ENTERED;
        _;
        _send_entered_state = _NOT_ENTERED;
    }
    modifier receiveNonReentrant() {
        require(_receive_entered_state == _NOT_ENTERED, "Succinct: no reentrancy");
        _receive_entered_state = _ENTERED;
        _;
        _receive_entered_state = _NOT_ENTERED;
    }
    // this event emits when destination chain does not receive funds 
    event destChainTransferFailed(address indexed to, uint256 indexed amount);

    constructor(uint16 _chainId) {
// setting up the parameters for gas fees 
        chainId = _chainId;
            relayerFeeConfig = RelayerFeeConfig({
            dstPriceRatio: 1e10, // 1:1, same chain, same native coin
            dstGasPriceInWei: 1e10,
            dstNativeAmtCap: 1e19,
            baseGas: 100,
            gasPerByte: 1
        });
        defaultAdapterParams = buildDefaultAdapterParams(200000);  

    }
    function send(
        uint16 _chainId, // chain Id for destination blockchain
        bytes memory _path, // this is destination chain address, and msg.sender combined
        bytes calldata _payload, //used for calculating gas fees 
        address payable _refundAddress, // sender pays for all the fees across both chains, any leftovers will be refunded back to the sender 
        bytes memory _adapterParams // there for gas calculations 
        ) external payable override sendNonReentrant {
            //contract only works with evm
        require(_path.length == 40, "Succinct: wrong address size "); 

        address dstAddr;
        
        assembly {
            dstAddr := mload(add(_path, 20))
        }

        address destinationAddress = trustedAddresses[dstAddr];
        require(destinationAddress != address(0), "Succinct: contract address non-existant");

        // calculates all gas fees 
        bytes memory adapterParams = _adapterParams.length > 0 ? _adapterParams : defaultAdapterParams;
        (uint nativeFee, ) = estimateFees(_payload, adapterParams);
        require(msg.value >= nativeFee, "Succinct: insufficient fees paid");
        // keeping track of the nonce and the sender address  
        uint64 nonce = ++outboundNonce[_chainId][msg.sender];

        // refund if they send too much
        uint amount = msg.value - nativeFee;
        if (amount > 0) {
            (bool success, ) = _refundAddress.call{value: amount}("");
            require(success, "Succinct: failed to refund");
        }

        // the messaging is being sent to destination address and checking if the transaction was successful 
        (, uint256 extraGas, uint256 dstNativeAmt, address payable dstNativeAddr) = decodeAdapterParams(adapterParams); 
        if (dstNativeAmt > 0) {
            (bool success, ) = dstNativeAddr.call{value: dstNativeAmt}("");
            if (!success) {
                 emit destChainTransferFailed(dstNativeAddr, dstNativeAmt);
            }
        }
        //creating the path to be able to check if the message was queued 
        bytes memory srcAddress = abi.encodePacked(msg.sender, dstAddr); 
        bytes memory payload = _payload;
        //after automatically checking this calls the receive function 
        ParentContract(destinationAddress).receivePayload(chainId, srcAddress, dstAddr, nonce, extraGas, payload);
    }
    //All this function does, is call the receive function on the same contract at the other chain 
    function receivePayload(uint16 _srcChainId, bytes calldata _path, address _dstAddress, uint64 _nonce, uint _gasLimit, bytes calldata _payload) external override receiveNonReentrant {
         require(_nonce == ++inboundNonce[_srcChainId][_path], "Succinct: wrong nonce");
         try IAMBReceiver(_dstAddress).Receive{gas: _gasLimit}() {} catch (bytes memory reason){}
     }
     //this is a security function to keep track of contract addresses 
    function setDestAddress(address destAddr, address parentAddress) external {
        trustedAddresses[destAddr] = parentAddress;
    }  

    function estimateFees(bytes memory _payload, bytes memory _adapterParams) public view returns (uint nativeFee, uint zroFee) {
        bytes memory adapterParams = _adapterParams.length > 0 ? _adapterParams : defaultAdapterParams;

        // Relayer Fee
        uint relayerFee = _getRelayerFee(_payload.length, adapterParams);

        // return the sum of fees
        nativeFee = relayerFee;
    }


    function _getRelayerFee(
        uint _payloadSize,
        bytes memory _adapterParams
    ) internal view returns (uint) {
        (uint16 txType, uint extraGas, uint dstNativeAmt, ) = decodeAdapterParams(_adapterParams); 
        uint totalRemoteToken; // = baseGas + extraGas + requiredNativeAmount
        if (txType == 2) {
            require(relayerFeeConfig.dstNativeAmtCap >= dstNativeAmt, "LayerZeroMock: dstNativeAmt too large ");
            totalRemoteToken += dstNativeAmt;
        }
        // remoteGasTotal = dstGasPriceInWei * (baseGas + extraGas)
        uint remoteGasTotal = relayerFeeConfig.dstGasPriceInWei * (relayerFeeConfig.baseGas + extraGas);
        totalRemoteToken += remoteGasTotal;

        // tokenConversionRate = dstPrice / localPrice
        // basePrice = totalRemoteToken * tokenConversionRate
        uint basePrice = (totalRemoteToken * relayerFeeConfig.dstPriceRatio) / 10**10;

        // pricePerByte = (dstGasPriceInWei * gasPerBytes) * tokenConversionRate
        uint pricePerByte = (relayerFeeConfig.dstGasPriceInWei * relayerFeeConfig.gasPerByte * relayerFeeConfig.dstPriceRatio) / 10**10;

        return basePrice + _payloadSize * pricePerByte;
    }
  
    function buildDefaultAdapterParams(uint _uaGas) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(1), _uaGas);
    }
    //function callculated the fees, and finds all addresses used 
    function decodeAdapterParams(bytes memory _adapterParams) internal pure returns (uint16 txType, uint uaGas, uint airdropAmount, address payable airdropAddress) {
        require(_adapterParams.length == 34 || _adapterParams.length > 66, "Invalid adapterParams");
        assembly {
            txType := mload(add(_adapterParams, 2))
            uaGas := mload(add(_adapterParams, 34))
        }
        //checks for the write txtype and some gas paid 
        require(txType == 1 || txType == 2, "Unsupported txType");
        require(uaGas > 0, "Gas too low");

        if (txType == 2) {
            assembly {
                airdropAmount := mload(add(_adapterParams, 66))
                airdropAddress := mload(add(_adapterParams, 86))
            }
        }
    }


    }
