pragma solidity ^0.4.11;


/*

  Copyright 2017 Askchain Foundation.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

//                            _           _           _
//  __      ____ _ _ __   ___| |__   __ _(_)_ __   __| | _____   __
//  \ \ /\ / / _` | '_ \ / __| '_ \ / _` | | '_ \@/ _` |/ _ \ \ / /
//   \ V  V / (_| | | | | (__| | | | (_| | | | | | (_| |  __/\ V /
//    \_/\_/ \__,_|_| |_|\___|_| |_|\__,_|_|_| |_|\__,_|\___| \_/
//
//  Code style according to: https://github.com/askchain/askchain-token/blob/master/style-guide.rst

/**
 * Math operations with safety checks
 */
library SafeMath {
    function mul(uint a, uint b) internal returns (uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint a, uint b) internal returns (uint) {
        assert(b > 0);
        uint c = a / b;
        assert(a == b * c + a % b);
        return c;
    }

    function sub(uint a, uint b) internal returns (uint) {
        assert(b <= a);
        return a - b;
    }

    function add(uint a, uint b) internal returns (uint) {
        uint c = a + b;
        assert(c >= a);
        return c;
    }

    function max64(uint64 a, uint64 b) internal constant returns (uint64) {
        return a >= b ? a : b;
    }

    function min64(uint64 a, uint64 b) internal constant returns (uint64) {
        return a < b ? a : b;
    }

    function max256(uint256 a, uint256 b) internal constant returns (uint256) {
        return a >= b ? a : b;
    }

    function min256(uint256 a, uint256 b) internal constant returns (uint256) {
        return a < b ? a : b;
    }
}

/// @dev `Owned` is a base level contract that assigns an `owner` that can be
///  later changed
contract Owned {
    /// @dev `owner` is the only address that can call a function with this
    /// modifier
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    address public owner;
    /// @notice The Constructor assigns the message sender to be `owner`
    function Owned() {
        owner = msg.sender;
    }

    address public newOwner;
    /// @notice `owner` can step down and assign some other address to this role
    /// @param _newOwner The address of the new owner. 0x0 can be used to create
    ///  an unowned neutral vault, however that cannot be undone
    function changeOwner(address _newOwner) onlyOwner {
        newOwner = _newOwner;
    }

    function acceptOwnership() {
        if (msg.sender == newOwner) {
            owner = newOwner;
        }
    }
}

contract ERC20Protocol {
    /// total amount of tokens
    uint public totalSupply;

    function balanceOf(address _owner) constant returns (uint balance);
    function transfer(address _to, uint _value) returns (bool success);
    function transferFrom(address _from, address _to, uint _value) returns (bool success);
    function approve(address _spender, uint _value) returns (bool success);
    function alloaskce(address _owner, address _spender) constant returns (uint remaining);
    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}


contract StandardToken is ERC20Protocol {
    using SafeMath for uint;
    /**
    * @dev Fix for the ERC20 short address attack.
    */
    modifier onlyPayloadSize(uint size) {
        require(msg.data.length >= size + 4);
        _;
    }

    function transfer(address _to, uint _value) onlyPayloadSize(2 * 32) returns (bool success) {
        //Default assumes totalSupply can't be over max (2^256 - 1).
        //If your token leaves out totalSupply and can issue more tokens as time goes on, you need to check if it doesn't wrap.
        //Replace the if with this one instead.
        //if (balances[msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
        if (balances[msg.sender] >= _value) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        } else { return false; }
    }

    function transferFrom(address _from, address _to, uint _value) onlyPayloadSize(3 * 32) returns (bool success) {
        //same as above. Replace this line with the following if you askt to protect against wrapping uints.
        //if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            Transfer(_from, _to, _value);
            return true;
        } else { return false; }
    }

    function balanceOf(address _owner) constant returns (uint balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint _value) onlyPayloadSize(2 * 32) returns (bool success) {
        // To change the approve amount you first have to reduce the addresses`
        //  alloaskce to zero by calling `approve(_spender, 0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        assert((_value == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function alloaskce(address _owner, address _spender) constant returns (uint remaining) {
        return allowed[_owner][_spender];
    }

    mapping (address => uint) balances;
    mapping (address => mapping (address => uint)) allowed;
}

/// @title Askchain Token Contract
/// For more information about this token sale, please visit https://askchain.org
/// @author Cathy - <cathy@askchain.org>
contract AskToken is StandardToken,Owned{
    using SafeMath for uint;

    /// Constant token specific fields
    string public constant name = "AllSparkToken";
    string public constant symbol = "ASK";
    uint public constant decimals = 18;
    uint public totalMintSupply = 0 ether;

    /// Askchain total tokens supply
    uint public constant MAX_TOTAL_TOKEN_AMOUNT = 30000000000 ether;
    uint public constant ASK_TOTAL_SUPPLY = 30000000000 ether;

    // Addresses of Patrons
    address internal constant PRIVATE_PLACEMENT_HOLDER1 = 0x8F62Ce1f46eA9822ed44ECfbe1a9817226F65ebe;
    address internal constant PRIVATE_PLACEMENT_HOLDER2 = 0xdC9180045E8A06C2c8800C06948D1bBe9aC5B48D;
    address internal constant PRIVATE_PLACEMENT_HOLDER3 = 0x680F377B0bBfa6F6100A45fBB18fF57E01a657B9;
    address internal constant PRIVATE_PLACEMENT_HOLDER4 = 0xA23C96ecc1e8D1EaCe86B84AA7B75E79e7736922;
    address internal constant FOUNDATION_HOLDER1 = 0x21494661905F5A671244848A28f4Ba0F7db2d465;
    address internal constant FOUNDATION_HOLDER2 = 0x54ec7B937e9AF148d91adCFf8ED13197f58E0373;
    address internal constant FOUNDATION_HOLDER3 = 0x8e50e6788ADcC60355AB75c90246acAa891F7FBe;
    address internal constant FOUNDATION_HOLDER4 = 0x31C51238B3994496516E745cC33136cB5044ba39;
    address internal constant COMMUNITY_INCENTIVES_HOLDER1 = 0x4A260A3F5E3c2E90CBD6aB012336c18DdC952191;
    address internal constant COMMUNITY_INCENTIVES_HOLDER2 = 0x035F3a4d748D137731C9Fc144bFC33479F91bc94;

    // coins of Patrons
    uint public constant PRIVATE_PLACEMENT_COIN1 = 1200000000 ether;
    uint public constant PRIVATE_PLACEMENT_COIN2 = 1200000000 ether;
    uint public constant PRIVATE_PLACEMENT_COIN3 = 1200000000 ether;
    uint public constant PRIVATE_PLACEMENT_COIN4 = 1200000000 ether;
    uint public constant FOUNDATION_COIN1 = 2250000000 ether;
    uint public constant FOUNDATION_COIN2 = 2250000000 ether;
    uint public constant FOUNDATION_COIN3 = 2250000000 ether;
    uint public constant FOUNDATION_COIN4 = 2250000000 ether;
    uint public constant COMMUNITY_INCENTIVES_COIN1 = 4500000000 ether;
    uint public constant COMMUNITY_INCENTIVES_COIN2 = 4500000000 ether;

    /// Fields that are only changed in constructor
    /// Askchain contribution contract
    address public minter;

    /*
     * MODIFIERS
     */

    modifier onlyMinter {
        require(msg.sender == minter);
        _;
    }

    modifier maxWanTokenAmountNotReached (uint amount){
        require(totalSupply.add(amount) <= MAX_TOTAL_TOKEN_AMOUNT);
        _;
    }
    /**
     * CONSTRUCTOR
     *
     * @dev Initialize the Askchain Token
     * @param _minter The Askchain Contribution Contract
     */
    function AskToken(address _minter){
        require(_minter != 0x0);

        minter = _minter;
        balances[msg.sender] = 7200000000 ether;

        mintToken(PRIVATE_PLACEMENT_HOLDER1, PRIVATE_PLACEMENT_COIN1);
        mintToken(PRIVATE_PLACEMENT_HOLDER2, PRIVATE_PLACEMENT_COIN2);
        mintToken(PRIVATE_PLACEMENT_HOLDER3, PRIVATE_PLACEMENT_COIN3);
        mintToken(PRIVATE_PLACEMENT_HOLDER4, PRIVATE_PLACEMENT_COIN4);
        mintToken(FOUNDATION_HOLDER1, FOUNDATION_COIN1);
        mintToken(FOUNDATION_HOLDER2, FOUNDATION_COIN2);
        mintToken(FOUNDATION_HOLDER3, FOUNDATION_COIN3);
        mintToken(FOUNDATION_HOLDER4, FOUNDATION_COIN4);
        mintToken(COMMUNITY_INCENTIVES_HOLDER1, COMMUNITY_INCENTIVES_COIN1);
        mintToken(COMMUNITY_INCENTIVES_HOLDER2, COMMUNITY_INCENTIVES_COIN2);
    }

    /**
     * Fallback function
     *
     * @dev If anybody sends Ether directly to this  contract, consider he is getting ask token
     */
    function() public payable {
        if (msg.value > 0) {
            msg.sender.transfer(msg.value);
        }
    }

    /// @dev Emergency situation
    function changeWalletAddress(address newAddress) onlyMinter {
        if (newAddress == address(0x0)) throw;
        minter = newAddress;
    }

    /**
     * EXTERNAL FUNCTION
     *
     * @dev Contribution contract instance mint token
     * @param recipient The destination account owned mint tokens
     * @param amount The amount of mint token
     * be sent to this address.
     */
    function mintToken(address recipient, uint amount) internal onlyMinter maxWanTokenAmountNotReached(amount) returns (bool){
        balances[recipient] = balances[recipient].add(amount);
        totalMintSupply = totalMintSupply.add(amount);
        totalSupply = totalMintSupply + 7200000000 ether;
        return true;
    }
}

