// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.0;

import "./interfaces/IAMBReceiver.sol";
import "./interfaces/IAMB.sol";
// import "./ParentContract.sol";

contract Counter is IAMBReceiver{

  IAMB public immutable iamb;
  address owner;
  uint256 public counter;
  uint16 chainId;
  uint256 nonce;

  //keeping track of contract on other chain 
  mapping (uint16 => bytes) public trustedContracts;

  modifier onlyOwner() {
      require(msg.sender == owner, "Succinct: only owner function");
      _;
  }

  constructor(uint16 _chainId, address _parentContract) {
    chainId = _chainId;

     iamb = IAMB(_parentContract);
     owner = msg.sender; 

  }
  
// this is the final send function 
    function sending(uint16 _dstChainId) public payable {
        _send(_dstChainId, bytes(""), payable(msg.sender), bytes(""), msg.value);

    }
    //This send function calls the send function from the parent contract 
     function _send(
        uint16 _chainId,
        bytes memory _payload, 
        address payable _refundAddress, 
        bytes memory _adapterParams,
        uint _nativeFee
     ) internal virtual {
        bytes memory trustedContract = trustedContracts[_chainId];
        require(trustedContract.length != 0, "LzApp: destination chain is not a trusted source");
        iamb.send{value: _nativeFee}(_chainId, trustedContract, _payload, _refundAddress, _adapterParams);
        nonce+=1;
    }
    //the receive function is called after the send is called 
    //this function should not be called by itself 

    function Receive() external override {
     counter += 1;
    }
//stores trusted contract from the other chain 
  function trustContract(uint16 _destChainId,bytes calldata _path) external onlyOwner {
      trustedContracts[_destChainId] = _path;
  }

}