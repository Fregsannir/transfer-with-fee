// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.0;

contract TransferERC20WithFee is ReentrancyGuard {
    using SafeMath for uint256;

    // As solidity does not provide floating numbers, we use 10000 for 100% rate to provide floating percentages up to 2 digits
    uint256 public constant MAX_PERCENTAGE_RATE = 1e4;
    // Minimal percentage rate is 100 (1%)
    uint256 public constant MIN_PERCENTAGE_RATE = 1e2;

    address private immutable owner;
    address private feeReciever;
    address private reciever;
    uint256 private percentage;
    bool private stopped = false;

    constructor(
        address _feeReciever,
        address _reciever,
        uint256 _percentage
    )
        notNullAddress(_feeReciever)
        notNullAddress(_reciever)
        onlyWallet(_feeReciever)
        onlyWallet(_reciever)
        validPercentage(_percentage)
    {
        owner = msg.sender;
        feeReciever = _feeReciever;
        reciever = _reciever;
        percentage = _percentage;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Forbidden: only owner can do this operation"
        );
        _;
    }

    modifier onlyWallet(address _account) {
        require(
            _account.code.length == 0,
            "Error: account cannot be a contract"
        );
        _;
    }

    modifier validAllowance(address _token, uint256 _amount) {
        require(
            IERC20(_token).allowance(msg.sender, address(this)) >= _amount,
            "ERC20: not enough allowance"
        );
        _;
    }

    modifier notNullAddress(address _account) {
        require(_account != address(0x0), "Error: address cannot be null");
        _;
    }

    modifier isStopped() {
        require(!stopped, "Error: contract was stopped by its owner");
        _;
    }

    modifier validPercentage(uint256 _percentage) {
        require(
            _percentage >= MIN_PERCENTAGE_RATE && _percentage <= (MAX_PERCENTAGE_RATE - 1000),
            "Error: percentage must be at least 1% and lower or equal 90%"
        );
        _;
    }

    function transferWithFee(address token, uint256 amount)
        public
        nonReentrant
        onlyWallet(msg.sender)
        validAllowance(token, amount)
        isStopped
        returns (bool)
    {
        require(
            IERC20(token).balanceOf(msg.sender) >= amount,
            "Insufficient Funds"
        );
        return (_transferWithFee(
            token,
            msg.sender,
            reciever,
            amount.mul(MAX_PERCENTAGE_RATE - percentage).div(
                MAX_PERCENTAGE_RATE
            )
        ) &&
            _transferWithFee(
                token,
                msg.sender,
                feeReciever,
                amount.mul(percentage).div(MAX_PERCENTAGE_RATE)
            ));
    }

    function transferWithFeeFromContractBalance(address token, uint256 amount)
        public
        nonReentrant
        onlyOwner
        onlyWallet(msg.sender)
        isStopped
        returns (bool)
    {
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "Insufficient Funds"
        );
        return (_transferWithFeeFromContractBalance(
            token,
            reciever,
            amount.mul(MAX_PERCENTAGE_RATE - percentage).div(
                MAX_PERCENTAGE_RATE
            )
        ) &&
            _transferWithFeeFromContractBalance(
                token,
                feeReciever,
                amount.mul(percentage).div(MAX_PERCENTAGE_RATE)
            ));
    }

    function updateFeeReciever(address _feeReciever)
        public
        onlyOwner
        onlyWallet(_feeReciever)
        notNullAddress(_feeReciever)
    {
        feeReciever = _feeReciever;
    }

    function updateReciever(address _reciever)
        public
        onlyOwner
        onlyWallet(_reciever)
        notNullAddress(_reciever)
    {
        reciever = _reciever;
    }

    function updatePercentage(uint256 _percentage)
        public
        onlyOwner
        validPercentage(_percentage)
    {
        percentage = _percentage;
    }

    function updateStopped() public onlyOwner {
        stopped = !stopped;
    }

    function getFeeReciever() public view returns (address) {
        return feeReciever;
    }

    function getReciever() public view returns (address) {
        return reciever;
    }

    function getPercentage() public view returns (uint256) {
        return percentage;
    }

    function _transferWithFee(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) internal returns (bool) {
        return IERC20(_token).transferFrom(_from, _to, _amount);
    }

    function _transferWithFeeFromContractBalance(
        address _token,
        address _to,
        uint256 _amount
    ) internal returns (bool) {
        return IERC20(_token).transfer(_to, _amount);
    }

    function getContractBalance(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }
}
