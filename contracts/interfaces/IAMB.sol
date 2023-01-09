// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;


interface IAMB {
       function send(
        uint16 _chainId,
        bytes memory _path, 
        bytes calldata _payload, 
        address payable _refundAddress, 
        bytes memory _adapterParams
        ) external payable;

    function receivePayload(uint16 _srcChainId, bytes calldata _srcAddress, address _dstAddress, uint64 _nonce, uint _gasLimit, bytes calldata _payload) external;


    //    function toReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external;

}