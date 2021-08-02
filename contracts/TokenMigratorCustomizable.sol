// SPDX-License-Identifier: MIT
//By: Ryan Rong

pragma solidity ^0.6.12;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}


interface IOLD is IERC20{
    function burn ( uint256 amount ) external;
}

contract TokenMigratorCustomizable is Ownable{
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    bool BurnOnSwap = true;
    bool SwapPaused = true;

    uint256 public totalSwapped = 0;

    IOLD public OLD = IOLD(address(0));
    IOLD public NEW = IOLD(address(0));

    function SetOriginToken(address token) public onlyOwner{
        OLD = IOLD(token);
    }

    function SetSwapToken(address token) public onlyOwner{
        NEW = IOLD(token);
    }

    function setBurn(bool fBurn) public onlyOwner{
        BurnOnSwap = fBurn;
    }

    function swapTokens(uint256 tokensToSwap) public {
        require((!SwapPaused || _msgSender() == owner()),"Swap is paused");
        //Transfer tokens from user to contract
        OLD.transferFrom(msg.sender,address(this),tokensToSwap);
        require(getTokenBalance(address(OLD)) == tokensToSwap,"Dont have enough tokens sent");

        //Transfer same amount of tokens from contract to user of new token
        NEW.transfer(msg.sender,tokensToSwap);
        if(BurnOnSwap){
            //Burn the tokens we have left after swapping
            OLD.burn(tokensToSwap);
        }
        //Update total swapped figure
        totalSwapped = totalSwapped.add(tokensToSwap);
    }

    function unpauseSwap() public onlyOwner {
        SwapPaused = false;
    }

    function pauseSwap() public onlyOwner {
        SwapPaused = true;
    }

    function recoverERC20(address tokenAddress) public onlyOwner {
        IERC20(tokenAddress).transfer(msg.sender, getTokenBalance(tokenAddress));
    }

    function getTokenBalance(address tokenAddress) public view returns (uint256){
        return IERC20(tokenAddress).balanceOf(address(this));
    }
}
