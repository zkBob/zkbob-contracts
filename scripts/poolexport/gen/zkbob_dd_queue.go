// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package gen

import (
	"errors"
	"math/big"
	"strings"

	ethereum "github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
)

// Reference imports to suppress errors if they are not otherwise used.
var (
	_ = errors.New
	_ = big.NewInt
	_ = strings.NewReader
	_ = ethereum.NotFound
	_ = bind.Bind
	_ = common.Big1
	_ = types.BloomLookup
	_ = event.NewSubscription
	_ = abi.ConvertType
)

// IZkBobDirectDepositsDirectDeposit is an auto generated low-level Go binding around an user-defined struct.
type IZkBobDirectDepositsDirectDeposit struct {
	FallbackReceiver common.Address
	Sent             *big.Int
	Deposit          uint64
	Fee              uint64
	Timestamp        *big.Int
	Status           uint8
	Diversifier      [10]byte
	Pk               [32]byte
}

// ZkAddressZkAddress is an auto generated low-level Go binding around an user-defined struct.
type ZkAddressZkAddress struct {
	Diversifier [10]byte
	Pk          [32]byte
}

// ZkBobDirectDepositQueueMetaData contains all meta data concerning the ZkBobDirectDepositQueue contract.
var ZkBobDirectDepositQueueMetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_pool\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"_token\",\"type\":\"address\"}],\"stateMutability\":\"nonpayable\",\"type\":\"constructor\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256[]\",\"name\":\"indices\",\"type\":\"uint256[]\"}],\"name\":\"CompleteDirectDepositBatch\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferred\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"nonce\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"receiver\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"RefundDirectDeposit\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"nonce\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"fallbackUser\",\"type\":\"address\"},{\"components\":[{\"internalType\":\"bytes10\",\"name\":\"diversifier\",\"type\":\"bytes10\"},{\"internalType\":\"bytes32\",\"name\":\"pk\",\"type\":\"bytes32\"}],\"indexed\":false,\"internalType\":\"structZkAddress.ZkAddress\",\"name\":\"zkAddress\",\"type\":\"tuple\"},{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"deposit\",\"type\":\"uint64\"}],\"name\":\"SubmitDirectDeposit\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"fee\",\"type\":\"uint64\"}],\"name\":\"UpdateDirectDepositFee\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint40\",\"name\":\"timeout\",\"type\":\"uint40\"}],\"name\":\"UpdateDirectDepositTimeout\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"manager\",\"type\":\"address\"}],\"name\":\"UpdateOperatorManager\",\"type\":\"event\"},{\"inputs\":[{\"internalType\":\"uint256[]\",\"name\":\"_indices\",\"type\":\"uint256[]\"},{\"internalType\":\"uint256\",\"name\":\"_out_commit\",\"type\":\"uint256\"}],\"name\":\"collect\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"total\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"totalFee\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"hashsum\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"message\",\"type\":\"bytes\"}],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_fallbackUser\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"_amount\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"_rawZkAddress\",\"type\":\"bytes\"}],\"name\":\"directDeposit\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_fallbackUser\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"_amount\",\"type\":\"uint256\"},{\"internalType\":\"string\",\"name\":\"_zkAddress\",\"type\":\"string\"}],\"name\":\"directDeposit\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"directDepositFee\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"directDepositNonce\",\"outputs\":[{\"internalType\":\"uint32\",\"name\":\"\",\"type\":\"uint32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"directDepositTimeout\",\"outputs\":[{\"internalType\":\"uint40\",\"name\":\"\",\"type\":\"uint40\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"_index\",\"type\":\"uint256\"}],\"name\":\"getDirectDeposit\",\"outputs\":[{\"components\":[{\"internalType\":\"address\",\"name\":\"fallbackReceiver\",\"type\":\"address\"},{\"internalType\":\"uint96\",\"name\":\"sent\",\"type\":\"uint96\"},{\"internalType\":\"uint64\",\"name\":\"deposit\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"fee\",\"type\":\"uint64\"},{\"internalType\":\"uint40\",\"name\":\"timestamp\",\"type\":\"uint40\"},{\"internalType\":\"enumIZkBobDirectDeposits.DirectDepositStatus\",\"name\":\"status\",\"type\":\"uint8\"},{\"internalType\":\"bytes10\",\"name\":\"diversifier\",\"type\":\"bytes10\"},{\"internalType\":\"bytes32\",\"name\":\"pk\",\"type\":\"bytes32\"}],\"internalType\":\"structIZkBobDirectDeposits.DirectDeposit\",\"name\":\"\",\"type\":\"tuple\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_from\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"_value\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"_data\",\"type\":\"bytes\"}],\"name\":\"onTokenTransfer\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"operatorManager\",\"outputs\":[{\"internalType\":\"contractIOperatorManager\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"pool\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"pool_id\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256[]\",\"name\":\"_indices\",\"type\":\"uint256[]\"}],\"name\":\"refundDirectDeposit\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"_index\",\"type\":\"uint256\"}],\"name\":\"refundDirectDeposit\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"renounceOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"_fee\",\"type\":\"uint64\"}],\"name\":\"setDirectDepositFee\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint40\",\"name\":\"_timeout\",\"type\":\"uint40\"}],\"name\":\"setDirectDepositTimeout\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"contractIOperatorManager\",\"name\":\"_operatorManager\",\"type\":\"address\"}],\"name\":\"setOperatorManager\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"token\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"transferOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]",
}

// ZkBobDirectDepositQueueABI is the input ABI used to generate the binding from.
// Deprecated: Use ZkBobDirectDepositQueueMetaData.ABI instead.
var ZkBobDirectDepositQueueABI = ZkBobDirectDepositQueueMetaData.ABI

// ZkBobDirectDepositQueue is an auto generated Go binding around an Ethereum contract.
type ZkBobDirectDepositQueue struct {
	ZkBobDirectDepositQueueCaller     // Read-only binding to the contract
	ZkBobDirectDepositQueueTransactor // Write-only binding to the contract
	ZkBobDirectDepositQueueFilterer   // Log filterer for contract events
}

// ZkBobDirectDepositQueueCaller is an auto generated read-only Go binding around an Ethereum contract.
type ZkBobDirectDepositQueueCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ZkBobDirectDepositQueueTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ZkBobDirectDepositQueueTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ZkBobDirectDepositQueueFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ZkBobDirectDepositQueueFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ZkBobDirectDepositQueueSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ZkBobDirectDepositQueueSession struct {
	Contract     *ZkBobDirectDepositQueue // Generic contract binding to set the session for
	CallOpts     bind.CallOpts            // Call options to use throughout this session
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// ZkBobDirectDepositQueueCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ZkBobDirectDepositQueueCallerSession struct {
	Contract *ZkBobDirectDepositQueueCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                  // Call options to use throughout this session
}

// ZkBobDirectDepositQueueTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ZkBobDirectDepositQueueTransactorSession struct {
	Contract     *ZkBobDirectDepositQueueTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                  // Transaction auth options to use throughout this session
}

// ZkBobDirectDepositQueueRaw is an auto generated low-level Go binding around an Ethereum contract.
type ZkBobDirectDepositQueueRaw struct {
	Contract *ZkBobDirectDepositQueue // Generic contract binding to access the raw methods on
}

// ZkBobDirectDepositQueueCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ZkBobDirectDepositQueueCallerRaw struct {
	Contract *ZkBobDirectDepositQueueCaller // Generic read-only contract binding to access the raw methods on
}

// ZkBobDirectDepositQueueTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ZkBobDirectDepositQueueTransactorRaw struct {
	Contract *ZkBobDirectDepositQueueTransactor // Generic write-only contract binding to access the raw methods on
}

// NewZkBobDirectDepositQueue creates a new instance of ZkBobDirectDepositQueue, bound to a specific deployed contract.
func NewZkBobDirectDepositQueue(address common.Address, backend bind.ContractBackend) (*ZkBobDirectDepositQueue, error) {
	contract, err := bindZkBobDirectDepositQueue(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ZkBobDirectDepositQueue{ZkBobDirectDepositQueueCaller: ZkBobDirectDepositQueueCaller{contract: contract}, ZkBobDirectDepositQueueTransactor: ZkBobDirectDepositQueueTransactor{contract: contract}, ZkBobDirectDepositQueueFilterer: ZkBobDirectDepositQueueFilterer{contract: contract}}, nil
}

// NewZkBobDirectDepositQueueCaller creates a new read-only instance of ZkBobDirectDepositQueue, bound to a specific deployed contract.
func NewZkBobDirectDepositQueueCaller(address common.Address, caller bind.ContractCaller) (*ZkBobDirectDepositQueueCaller, error) {
	contract, err := bindZkBobDirectDepositQueue(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ZkBobDirectDepositQueueCaller{contract: contract}, nil
}

// NewZkBobDirectDepositQueueTransactor creates a new write-only instance of ZkBobDirectDepositQueue, bound to a specific deployed contract.
func NewZkBobDirectDepositQueueTransactor(address common.Address, transactor bind.ContractTransactor) (*ZkBobDirectDepositQueueTransactor, error) {
	contract, err := bindZkBobDirectDepositQueue(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ZkBobDirectDepositQueueTransactor{contract: contract}, nil
}

// NewZkBobDirectDepositQueueFilterer creates a new log filterer instance of ZkBobDirectDepositQueue, bound to a specific deployed contract.
func NewZkBobDirectDepositQueueFilterer(address common.Address, filterer bind.ContractFilterer) (*ZkBobDirectDepositQueueFilterer, error) {
	contract, err := bindZkBobDirectDepositQueue(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ZkBobDirectDepositQueueFilterer{contract: contract}, nil
}

// bindZkBobDirectDepositQueue binds a generic wrapper to an already deployed contract.
func bindZkBobDirectDepositQueue(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ZkBobDirectDepositQueueMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ZkBobDirectDepositQueue.Contract.ZkBobDirectDepositQueueCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.ZkBobDirectDepositQueueTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.ZkBobDirectDepositQueueTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ZkBobDirectDepositQueue.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.contract.Transact(opts, method, params...)
}

// DirectDepositFee is a free data retrieval call binding the contract method 0x35d3cbcc.
//
// Solidity: function directDepositFee() view returns(uint64)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCaller) DirectDepositFee(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _ZkBobDirectDepositQueue.contract.Call(opts, &out, "directDepositFee")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// DirectDepositFee is a free data retrieval call binding the contract method 0x35d3cbcc.
//
// Solidity: function directDepositFee() view returns(uint64)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) DirectDepositFee() (uint64, error) {
	return _ZkBobDirectDepositQueue.Contract.DirectDepositFee(&_ZkBobDirectDepositQueue.CallOpts)
}

// DirectDepositFee is a free data retrieval call binding the contract method 0x35d3cbcc.
//
// Solidity: function directDepositFee() view returns(uint64)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCallerSession) DirectDepositFee() (uint64, error) {
	return _ZkBobDirectDepositQueue.Contract.DirectDepositFee(&_ZkBobDirectDepositQueue.CallOpts)
}

// DirectDepositNonce is a free data retrieval call binding the contract method 0xb85369e6.
//
// Solidity: function directDepositNonce() view returns(uint32)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCaller) DirectDepositNonce(opts *bind.CallOpts) (uint32, error) {
	var out []interface{}
	err := _ZkBobDirectDepositQueue.contract.Call(opts, &out, "directDepositNonce")

	if err != nil {
		return *new(uint32), err
	}

	out0 := *abi.ConvertType(out[0], new(uint32)).(*uint32)

	return out0, err

}

// DirectDepositNonce is a free data retrieval call binding the contract method 0xb85369e6.
//
// Solidity: function directDepositNonce() view returns(uint32)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) DirectDepositNonce() (uint32, error) {
	return _ZkBobDirectDepositQueue.Contract.DirectDepositNonce(&_ZkBobDirectDepositQueue.CallOpts)
}

// DirectDepositNonce is a free data retrieval call binding the contract method 0xb85369e6.
//
// Solidity: function directDepositNonce() view returns(uint32)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCallerSession) DirectDepositNonce() (uint32, error) {
	return _ZkBobDirectDepositQueue.Contract.DirectDepositNonce(&_ZkBobDirectDepositQueue.CallOpts)
}

// DirectDepositTimeout is a free data retrieval call binding the contract method 0xb130603e.
//
// Solidity: function directDepositTimeout() view returns(uint40)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCaller) DirectDepositTimeout(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _ZkBobDirectDepositQueue.contract.Call(opts, &out, "directDepositTimeout")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// DirectDepositTimeout is a free data retrieval call binding the contract method 0xb130603e.
//
// Solidity: function directDepositTimeout() view returns(uint40)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) DirectDepositTimeout() (*big.Int, error) {
	return _ZkBobDirectDepositQueue.Contract.DirectDepositTimeout(&_ZkBobDirectDepositQueue.CallOpts)
}

// DirectDepositTimeout is a free data retrieval call binding the contract method 0xb130603e.
//
// Solidity: function directDepositTimeout() view returns(uint40)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCallerSession) DirectDepositTimeout() (*big.Int, error) {
	return _ZkBobDirectDepositQueue.Contract.DirectDepositTimeout(&_ZkBobDirectDepositQueue.CallOpts)
}

// GetDirectDeposit is a free data retrieval call binding the contract method 0xc278b761.
//
// Solidity: function getDirectDeposit(uint256 _index) view returns((address,uint96,uint64,uint64,uint40,uint8,bytes10,bytes32))
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCaller) GetDirectDeposit(opts *bind.CallOpts, _index *big.Int) (IZkBobDirectDepositsDirectDeposit, error) {
	var out []interface{}
	err := _ZkBobDirectDepositQueue.contract.Call(opts, &out, "getDirectDeposit", _index)

	if err != nil {
		return *new(IZkBobDirectDepositsDirectDeposit), err
	}

	out0 := *abi.ConvertType(out[0], new(IZkBobDirectDepositsDirectDeposit)).(*IZkBobDirectDepositsDirectDeposit)

	return out0, err

}

// GetDirectDeposit is a free data retrieval call binding the contract method 0xc278b761.
//
// Solidity: function getDirectDeposit(uint256 _index) view returns((address,uint96,uint64,uint64,uint40,uint8,bytes10,bytes32))
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) GetDirectDeposit(_index *big.Int) (IZkBobDirectDepositsDirectDeposit, error) {
	return _ZkBobDirectDepositQueue.Contract.GetDirectDeposit(&_ZkBobDirectDepositQueue.CallOpts, _index)
}

// GetDirectDeposit is a free data retrieval call binding the contract method 0xc278b761.
//
// Solidity: function getDirectDeposit(uint256 _index) view returns((address,uint96,uint64,uint64,uint40,uint8,bytes10,bytes32))
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCallerSession) GetDirectDeposit(_index *big.Int) (IZkBobDirectDepositsDirectDeposit, error) {
	return _ZkBobDirectDepositQueue.Contract.GetDirectDeposit(&_ZkBobDirectDepositQueue.CallOpts, _index)
}

// OperatorManager is a free data retrieval call binding the contract method 0x2f84c96f.
//
// Solidity: function operatorManager() view returns(address)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCaller) OperatorManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ZkBobDirectDepositQueue.contract.Call(opts, &out, "operatorManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// OperatorManager is a free data retrieval call binding the contract method 0x2f84c96f.
//
// Solidity: function operatorManager() view returns(address)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) OperatorManager() (common.Address, error) {
	return _ZkBobDirectDepositQueue.Contract.OperatorManager(&_ZkBobDirectDepositQueue.CallOpts)
}

// OperatorManager is a free data retrieval call binding the contract method 0x2f84c96f.
//
// Solidity: function operatorManager() view returns(address)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCallerSession) OperatorManager() (common.Address, error) {
	return _ZkBobDirectDepositQueue.Contract.OperatorManager(&_ZkBobDirectDepositQueue.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ZkBobDirectDepositQueue.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) Owner() (common.Address, error) {
	return _ZkBobDirectDepositQueue.Contract.Owner(&_ZkBobDirectDepositQueue.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCallerSession) Owner() (common.Address, error) {
	return _ZkBobDirectDepositQueue.Contract.Owner(&_ZkBobDirectDepositQueue.CallOpts)
}

// Pool is a free data retrieval call binding the contract method 0x16f0115b.
//
// Solidity: function pool() view returns(address)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCaller) Pool(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ZkBobDirectDepositQueue.contract.Call(opts, &out, "pool")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Pool is a free data retrieval call binding the contract method 0x16f0115b.
//
// Solidity: function pool() view returns(address)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) Pool() (common.Address, error) {
	return _ZkBobDirectDepositQueue.Contract.Pool(&_ZkBobDirectDepositQueue.CallOpts)
}

// Pool is a free data retrieval call binding the contract method 0x16f0115b.
//
// Solidity: function pool() view returns(address)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCallerSession) Pool() (common.Address, error) {
	return _ZkBobDirectDepositQueue.Contract.Pool(&_ZkBobDirectDepositQueue.CallOpts)
}

// PoolId is a free data retrieval call binding the contract method 0x9d8ad6e4.
//
// Solidity: function pool_id() view returns(uint256)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCaller) PoolId(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _ZkBobDirectDepositQueue.contract.Call(opts, &out, "pool_id")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PoolId is a free data retrieval call binding the contract method 0x9d8ad6e4.
//
// Solidity: function pool_id() view returns(uint256)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) PoolId() (*big.Int, error) {
	return _ZkBobDirectDepositQueue.Contract.PoolId(&_ZkBobDirectDepositQueue.CallOpts)
}

// PoolId is a free data retrieval call binding the contract method 0x9d8ad6e4.
//
// Solidity: function pool_id() view returns(uint256)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCallerSession) PoolId() (*big.Int, error) {
	return _ZkBobDirectDepositQueue.Contract.PoolId(&_ZkBobDirectDepositQueue.CallOpts)
}

// Token is a free data retrieval call binding the contract method 0xfc0c546a.
//
// Solidity: function token() view returns(address)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCaller) Token(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ZkBobDirectDepositQueue.contract.Call(opts, &out, "token")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Token is a free data retrieval call binding the contract method 0xfc0c546a.
//
// Solidity: function token() view returns(address)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) Token() (common.Address, error) {
	return _ZkBobDirectDepositQueue.Contract.Token(&_ZkBobDirectDepositQueue.CallOpts)
}

// Token is a free data retrieval call binding the contract method 0xfc0c546a.
//
// Solidity: function token() view returns(address)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueCallerSession) Token() (common.Address, error) {
	return _ZkBobDirectDepositQueue.Contract.Token(&_ZkBobDirectDepositQueue.CallOpts)
}

// Collect is a paid mutator transaction binding the contract method 0xe24546f2.
//
// Solidity: function collect(uint256[] _indices, uint256 _out_commit) returns(uint256 total, uint256 totalFee, uint256 hashsum, bytes message)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactor) Collect(opts *bind.TransactOpts, _indices []*big.Int, _out_commit *big.Int) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.contract.Transact(opts, "collect", _indices, _out_commit)
}

// Collect is a paid mutator transaction binding the contract method 0xe24546f2.
//
// Solidity: function collect(uint256[] _indices, uint256 _out_commit) returns(uint256 total, uint256 totalFee, uint256 hashsum, bytes message)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) Collect(_indices []*big.Int, _out_commit *big.Int) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.Collect(&_ZkBobDirectDepositQueue.TransactOpts, _indices, _out_commit)
}

// Collect is a paid mutator transaction binding the contract method 0xe24546f2.
//
// Solidity: function collect(uint256[] _indices, uint256 _out_commit) returns(uint256 total, uint256 totalFee, uint256 hashsum, bytes message)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactorSession) Collect(_indices []*big.Int, _out_commit *big.Int) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.Collect(&_ZkBobDirectDepositQueue.TransactOpts, _indices, _out_commit)
}

// DirectDeposit is a paid mutator transaction binding the contract method 0x02592d37.
//
// Solidity: function directDeposit(address _fallbackUser, uint256 _amount, bytes _rawZkAddress) returns(uint256)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactor) DirectDeposit(opts *bind.TransactOpts, _fallbackUser common.Address, _amount *big.Int, _rawZkAddress []byte) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.contract.Transact(opts, "directDeposit", _fallbackUser, _amount, _rawZkAddress)
}

// DirectDeposit is a paid mutator transaction binding the contract method 0x02592d37.
//
// Solidity: function directDeposit(address _fallbackUser, uint256 _amount, bytes _rawZkAddress) returns(uint256)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) DirectDeposit(_fallbackUser common.Address, _amount *big.Int, _rawZkAddress []byte) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.DirectDeposit(&_ZkBobDirectDepositQueue.TransactOpts, _fallbackUser, _amount, _rawZkAddress)
}

// DirectDeposit is a paid mutator transaction binding the contract method 0x02592d37.
//
// Solidity: function directDeposit(address _fallbackUser, uint256 _amount, bytes _rawZkAddress) returns(uint256)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactorSession) DirectDeposit(_fallbackUser common.Address, _amount *big.Int, _rawZkAddress []byte) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.DirectDeposit(&_ZkBobDirectDepositQueue.TransactOpts, _fallbackUser, _amount, _rawZkAddress)
}

// DirectDeposit0 is a paid mutator transaction binding the contract method 0x6918822d.
//
// Solidity: function directDeposit(address _fallbackUser, uint256 _amount, string _zkAddress) returns(uint256)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactor) DirectDeposit0(opts *bind.TransactOpts, _fallbackUser common.Address, _amount *big.Int, _zkAddress string) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.contract.Transact(opts, "directDeposit0", _fallbackUser, _amount, _zkAddress)
}

// DirectDeposit0 is a paid mutator transaction binding the contract method 0x6918822d.
//
// Solidity: function directDeposit(address _fallbackUser, uint256 _amount, string _zkAddress) returns(uint256)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) DirectDeposit0(_fallbackUser common.Address, _amount *big.Int, _zkAddress string) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.DirectDeposit0(&_ZkBobDirectDepositQueue.TransactOpts, _fallbackUser, _amount, _zkAddress)
}

// DirectDeposit0 is a paid mutator transaction binding the contract method 0x6918822d.
//
// Solidity: function directDeposit(address _fallbackUser, uint256 _amount, string _zkAddress) returns(uint256)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactorSession) DirectDeposit0(_fallbackUser common.Address, _amount *big.Int, _zkAddress string) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.DirectDeposit0(&_ZkBobDirectDepositQueue.TransactOpts, _fallbackUser, _amount, _zkAddress)
}

// OnTokenTransfer is a paid mutator transaction binding the contract method 0xa4c0ed36.
//
// Solidity: function onTokenTransfer(address _from, uint256 _value, bytes _data) returns(bool)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactor) OnTokenTransfer(opts *bind.TransactOpts, _from common.Address, _value *big.Int, _data []byte) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.contract.Transact(opts, "onTokenTransfer", _from, _value, _data)
}

// OnTokenTransfer is a paid mutator transaction binding the contract method 0xa4c0ed36.
//
// Solidity: function onTokenTransfer(address _from, uint256 _value, bytes _data) returns(bool)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) OnTokenTransfer(_from common.Address, _value *big.Int, _data []byte) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.OnTokenTransfer(&_ZkBobDirectDepositQueue.TransactOpts, _from, _value, _data)
}

// OnTokenTransfer is a paid mutator transaction binding the contract method 0xa4c0ed36.
//
// Solidity: function onTokenTransfer(address _from, uint256 _value, bytes _data) returns(bool)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactorSession) OnTokenTransfer(_from common.Address, _value *big.Int, _data []byte) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.OnTokenTransfer(&_ZkBobDirectDepositQueue.TransactOpts, _from, _value, _data)
}

// RefundDirectDeposit is a paid mutator transaction binding the contract method 0x68dc1c55.
//
// Solidity: function refundDirectDeposit(uint256[] _indices) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactor) RefundDirectDeposit(opts *bind.TransactOpts, _indices []*big.Int) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.contract.Transact(opts, "refundDirectDeposit", _indices)
}

// RefundDirectDeposit is a paid mutator transaction binding the contract method 0x68dc1c55.
//
// Solidity: function refundDirectDeposit(uint256[] _indices) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) RefundDirectDeposit(_indices []*big.Int) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.RefundDirectDeposit(&_ZkBobDirectDepositQueue.TransactOpts, _indices)
}

// RefundDirectDeposit is a paid mutator transaction binding the contract method 0x68dc1c55.
//
// Solidity: function refundDirectDeposit(uint256[] _indices) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactorSession) RefundDirectDeposit(_indices []*big.Int) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.RefundDirectDeposit(&_ZkBobDirectDepositQueue.TransactOpts, _indices)
}

// RefundDirectDeposit0 is a paid mutator transaction binding the contract method 0xd7f59caa.
//
// Solidity: function refundDirectDeposit(uint256 _index) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactor) RefundDirectDeposit0(opts *bind.TransactOpts, _index *big.Int) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.contract.Transact(opts, "refundDirectDeposit0", _index)
}

// RefundDirectDeposit0 is a paid mutator transaction binding the contract method 0xd7f59caa.
//
// Solidity: function refundDirectDeposit(uint256 _index) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) RefundDirectDeposit0(_index *big.Int) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.RefundDirectDeposit0(&_ZkBobDirectDepositQueue.TransactOpts, _index)
}

// RefundDirectDeposit0 is a paid mutator transaction binding the contract method 0xd7f59caa.
//
// Solidity: function refundDirectDeposit(uint256 _index) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactorSession) RefundDirectDeposit0(_index *big.Int) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.RefundDirectDeposit0(&_ZkBobDirectDepositQueue.TransactOpts, _index)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) RenounceOwnership() (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.RenounceOwnership(&_ZkBobDirectDepositQueue.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.RenounceOwnership(&_ZkBobDirectDepositQueue.TransactOpts)
}

// SetDirectDepositFee is a paid mutator transaction binding the contract method 0x80a32892.
//
// Solidity: function setDirectDepositFee(uint64 _fee) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactor) SetDirectDepositFee(opts *bind.TransactOpts, _fee uint64) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.contract.Transact(opts, "setDirectDepositFee", _fee)
}

// SetDirectDepositFee is a paid mutator transaction binding the contract method 0x80a32892.
//
// Solidity: function setDirectDepositFee(uint64 _fee) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) SetDirectDepositFee(_fee uint64) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.SetDirectDepositFee(&_ZkBobDirectDepositQueue.TransactOpts, _fee)
}

// SetDirectDepositFee is a paid mutator transaction binding the contract method 0x80a32892.
//
// Solidity: function setDirectDepositFee(uint64 _fee) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactorSession) SetDirectDepositFee(_fee uint64) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.SetDirectDepositFee(&_ZkBobDirectDepositQueue.TransactOpts, _fee)
}

// SetDirectDepositTimeout is a paid mutator transaction binding the contract method 0xdc3ba6a3.
//
// Solidity: function setDirectDepositTimeout(uint40 _timeout) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactor) SetDirectDepositTimeout(opts *bind.TransactOpts, _timeout *big.Int) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.contract.Transact(opts, "setDirectDepositTimeout", _timeout)
}

// SetDirectDepositTimeout is a paid mutator transaction binding the contract method 0xdc3ba6a3.
//
// Solidity: function setDirectDepositTimeout(uint40 _timeout) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) SetDirectDepositTimeout(_timeout *big.Int) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.SetDirectDepositTimeout(&_ZkBobDirectDepositQueue.TransactOpts, _timeout)
}

// SetDirectDepositTimeout is a paid mutator transaction binding the contract method 0xdc3ba6a3.
//
// Solidity: function setDirectDepositTimeout(uint40 _timeout) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactorSession) SetDirectDepositTimeout(_timeout *big.Int) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.SetDirectDepositTimeout(&_ZkBobDirectDepositQueue.TransactOpts, _timeout)
}

// SetOperatorManager is a paid mutator transaction binding the contract method 0xc41100fa.
//
// Solidity: function setOperatorManager(address _operatorManager) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactor) SetOperatorManager(opts *bind.TransactOpts, _operatorManager common.Address) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.contract.Transact(opts, "setOperatorManager", _operatorManager)
}

// SetOperatorManager is a paid mutator transaction binding the contract method 0xc41100fa.
//
// Solidity: function setOperatorManager(address _operatorManager) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) SetOperatorManager(_operatorManager common.Address) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.SetOperatorManager(&_ZkBobDirectDepositQueue.TransactOpts, _operatorManager)
}

// SetOperatorManager is a paid mutator transaction binding the contract method 0xc41100fa.
//
// Solidity: function setOperatorManager(address _operatorManager) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactorSession) SetOperatorManager(_operatorManager common.Address) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.SetOperatorManager(&_ZkBobDirectDepositQueue.TransactOpts, _operatorManager)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.TransferOwnership(&_ZkBobDirectDepositQueue.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ZkBobDirectDepositQueue.Contract.TransferOwnership(&_ZkBobDirectDepositQueue.TransactOpts, newOwner)
}

// ZkBobDirectDepositQueueCompleteDirectDepositBatchIterator is returned from FilterCompleteDirectDepositBatch and is used to iterate over the raw logs and unpacked data for CompleteDirectDepositBatch events raised by the ZkBobDirectDepositQueue contract.
type ZkBobDirectDepositQueueCompleteDirectDepositBatchIterator struct {
	Event *ZkBobDirectDepositQueueCompleteDirectDepositBatch // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *ZkBobDirectDepositQueueCompleteDirectDepositBatchIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ZkBobDirectDepositQueueCompleteDirectDepositBatch)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(ZkBobDirectDepositQueueCompleteDirectDepositBatch)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *ZkBobDirectDepositQueueCompleteDirectDepositBatchIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ZkBobDirectDepositQueueCompleteDirectDepositBatchIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ZkBobDirectDepositQueueCompleteDirectDepositBatch represents a CompleteDirectDepositBatch event raised by the ZkBobDirectDepositQueue contract.
type ZkBobDirectDepositQueueCompleteDirectDepositBatch struct {
	Indices []*big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterCompleteDirectDepositBatch is a free log retrieval operation binding the contract event 0x6158333d85f7dbce81f21c5dfee08ec3a6b81728f0f8ae2f329a8dcb0eac2b60.
//
// Solidity: event CompleteDirectDepositBatch(uint256[] indices)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) FilterCompleteDirectDepositBatch(opts *bind.FilterOpts) (*ZkBobDirectDepositQueueCompleteDirectDepositBatchIterator, error) {

	logs, sub, err := _ZkBobDirectDepositQueue.contract.FilterLogs(opts, "CompleteDirectDepositBatch")
	if err != nil {
		return nil, err
	}
	return &ZkBobDirectDepositQueueCompleteDirectDepositBatchIterator{contract: _ZkBobDirectDepositQueue.contract, event: "CompleteDirectDepositBatch", logs: logs, sub: sub}, nil
}

// WatchCompleteDirectDepositBatch is a free log subscription operation binding the contract event 0x6158333d85f7dbce81f21c5dfee08ec3a6b81728f0f8ae2f329a8dcb0eac2b60.
//
// Solidity: event CompleteDirectDepositBatch(uint256[] indices)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) WatchCompleteDirectDepositBatch(opts *bind.WatchOpts, sink chan<- *ZkBobDirectDepositQueueCompleteDirectDepositBatch) (event.Subscription, error) {

	logs, sub, err := _ZkBobDirectDepositQueue.contract.WatchLogs(opts, "CompleteDirectDepositBatch")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ZkBobDirectDepositQueueCompleteDirectDepositBatch)
				if err := _ZkBobDirectDepositQueue.contract.UnpackLog(event, "CompleteDirectDepositBatch", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseCompleteDirectDepositBatch is a log parse operation binding the contract event 0x6158333d85f7dbce81f21c5dfee08ec3a6b81728f0f8ae2f329a8dcb0eac2b60.
//
// Solidity: event CompleteDirectDepositBatch(uint256[] indices)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) ParseCompleteDirectDepositBatch(log types.Log) (*ZkBobDirectDepositQueueCompleteDirectDepositBatch, error) {
	event := new(ZkBobDirectDepositQueueCompleteDirectDepositBatch)
	if err := _ZkBobDirectDepositQueue.contract.UnpackLog(event, "CompleteDirectDepositBatch", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ZkBobDirectDepositQueueOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the ZkBobDirectDepositQueue contract.
type ZkBobDirectDepositQueueOwnershipTransferredIterator struct {
	Event *ZkBobDirectDepositQueueOwnershipTransferred // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *ZkBobDirectDepositQueueOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ZkBobDirectDepositQueueOwnershipTransferred)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(ZkBobDirectDepositQueueOwnershipTransferred)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *ZkBobDirectDepositQueueOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ZkBobDirectDepositQueueOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ZkBobDirectDepositQueueOwnershipTransferred represents a OwnershipTransferred event raised by the ZkBobDirectDepositQueue contract.
type ZkBobDirectDepositQueueOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*ZkBobDirectDepositQueueOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ZkBobDirectDepositQueue.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &ZkBobDirectDepositQueueOwnershipTransferredIterator{contract: _ZkBobDirectDepositQueue.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *ZkBobDirectDepositQueueOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ZkBobDirectDepositQueue.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ZkBobDirectDepositQueueOwnershipTransferred)
				if err := _ZkBobDirectDepositQueue.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseOwnershipTransferred is a log parse operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) ParseOwnershipTransferred(log types.Log) (*ZkBobDirectDepositQueueOwnershipTransferred, error) {
	event := new(ZkBobDirectDepositQueueOwnershipTransferred)
	if err := _ZkBobDirectDepositQueue.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ZkBobDirectDepositQueueRefundDirectDepositIterator is returned from FilterRefundDirectDeposit and is used to iterate over the raw logs and unpacked data for RefundDirectDeposit events raised by the ZkBobDirectDepositQueue contract.
type ZkBobDirectDepositQueueRefundDirectDepositIterator struct {
	Event *ZkBobDirectDepositQueueRefundDirectDeposit // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *ZkBobDirectDepositQueueRefundDirectDepositIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ZkBobDirectDepositQueueRefundDirectDeposit)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(ZkBobDirectDepositQueueRefundDirectDeposit)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *ZkBobDirectDepositQueueRefundDirectDepositIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ZkBobDirectDepositQueueRefundDirectDepositIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ZkBobDirectDepositQueueRefundDirectDeposit represents a RefundDirectDeposit event raised by the ZkBobDirectDepositQueue contract.
type ZkBobDirectDepositQueueRefundDirectDeposit struct {
	Nonce    *big.Int
	Receiver common.Address
	Amount   *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterRefundDirectDeposit is a free log retrieval operation binding the contract event 0xb0cf2923048b0f1ffd594948402295be48a7de9d3484175e13a2cd4de8650a8c.
//
// Solidity: event RefundDirectDeposit(uint256 indexed nonce, address receiver, uint256 amount)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) FilterRefundDirectDeposit(opts *bind.FilterOpts, nonce []*big.Int) (*ZkBobDirectDepositQueueRefundDirectDepositIterator, error) {

	var nonceRule []interface{}
	for _, nonceItem := range nonce {
		nonceRule = append(nonceRule, nonceItem)
	}

	logs, sub, err := _ZkBobDirectDepositQueue.contract.FilterLogs(opts, "RefundDirectDeposit", nonceRule)
	if err != nil {
		return nil, err
	}
	return &ZkBobDirectDepositQueueRefundDirectDepositIterator{contract: _ZkBobDirectDepositQueue.contract, event: "RefundDirectDeposit", logs: logs, sub: sub}, nil
}

// WatchRefundDirectDeposit is a free log subscription operation binding the contract event 0xb0cf2923048b0f1ffd594948402295be48a7de9d3484175e13a2cd4de8650a8c.
//
// Solidity: event RefundDirectDeposit(uint256 indexed nonce, address receiver, uint256 amount)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) WatchRefundDirectDeposit(opts *bind.WatchOpts, sink chan<- *ZkBobDirectDepositQueueRefundDirectDeposit, nonce []*big.Int) (event.Subscription, error) {

	var nonceRule []interface{}
	for _, nonceItem := range nonce {
		nonceRule = append(nonceRule, nonceItem)
	}

	logs, sub, err := _ZkBobDirectDepositQueue.contract.WatchLogs(opts, "RefundDirectDeposit", nonceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ZkBobDirectDepositQueueRefundDirectDeposit)
				if err := _ZkBobDirectDepositQueue.contract.UnpackLog(event, "RefundDirectDeposit", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseRefundDirectDeposit is a log parse operation binding the contract event 0xb0cf2923048b0f1ffd594948402295be48a7de9d3484175e13a2cd4de8650a8c.
//
// Solidity: event RefundDirectDeposit(uint256 indexed nonce, address receiver, uint256 amount)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) ParseRefundDirectDeposit(log types.Log) (*ZkBobDirectDepositQueueRefundDirectDeposit, error) {
	event := new(ZkBobDirectDepositQueueRefundDirectDeposit)
	if err := _ZkBobDirectDepositQueue.contract.UnpackLog(event, "RefundDirectDeposit", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ZkBobDirectDepositQueueSubmitDirectDepositIterator is returned from FilterSubmitDirectDeposit and is used to iterate over the raw logs and unpacked data for SubmitDirectDeposit events raised by the ZkBobDirectDepositQueue contract.
type ZkBobDirectDepositQueueSubmitDirectDepositIterator struct {
	Event *ZkBobDirectDepositQueueSubmitDirectDeposit // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *ZkBobDirectDepositQueueSubmitDirectDepositIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ZkBobDirectDepositQueueSubmitDirectDeposit)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(ZkBobDirectDepositQueueSubmitDirectDeposit)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *ZkBobDirectDepositQueueSubmitDirectDepositIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ZkBobDirectDepositQueueSubmitDirectDepositIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ZkBobDirectDepositQueueSubmitDirectDeposit represents a SubmitDirectDeposit event raised by the ZkBobDirectDepositQueue contract.
type ZkBobDirectDepositQueueSubmitDirectDeposit struct {
	Sender       common.Address
	Nonce        *big.Int
	FallbackUser common.Address
	ZkAddress    ZkAddressZkAddress
	Deposit      uint64
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterSubmitDirectDeposit is a free log retrieval operation binding the contract event 0xcde1b1a4bd18b6b8ddb2a80b1fce51c4eee01748267692ac6bc0770a84bc6c58.
//
// Solidity: event SubmitDirectDeposit(address indexed sender, uint256 indexed nonce, address fallbackUser, (bytes10,bytes32) zkAddress, uint64 deposit)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) FilterSubmitDirectDeposit(opts *bind.FilterOpts, sender []common.Address, nonce []*big.Int) (*ZkBobDirectDepositQueueSubmitDirectDepositIterator, error) {

	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}
	var nonceRule []interface{}
	for _, nonceItem := range nonce {
		nonceRule = append(nonceRule, nonceItem)
	}

	logs, sub, err := _ZkBobDirectDepositQueue.contract.FilterLogs(opts, "SubmitDirectDeposit", senderRule, nonceRule)
	if err != nil {
		return nil, err
	}
	return &ZkBobDirectDepositQueueSubmitDirectDepositIterator{contract: _ZkBobDirectDepositQueue.contract, event: "SubmitDirectDeposit", logs: logs, sub: sub}, nil
}

// WatchSubmitDirectDeposit is a free log subscription operation binding the contract event 0xcde1b1a4bd18b6b8ddb2a80b1fce51c4eee01748267692ac6bc0770a84bc6c58.
//
// Solidity: event SubmitDirectDeposit(address indexed sender, uint256 indexed nonce, address fallbackUser, (bytes10,bytes32) zkAddress, uint64 deposit)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) WatchSubmitDirectDeposit(opts *bind.WatchOpts, sink chan<- *ZkBobDirectDepositQueueSubmitDirectDeposit, sender []common.Address, nonce []*big.Int) (event.Subscription, error) {

	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}
	var nonceRule []interface{}
	for _, nonceItem := range nonce {
		nonceRule = append(nonceRule, nonceItem)
	}

	logs, sub, err := _ZkBobDirectDepositQueue.contract.WatchLogs(opts, "SubmitDirectDeposit", senderRule, nonceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ZkBobDirectDepositQueueSubmitDirectDeposit)
				if err := _ZkBobDirectDepositQueue.contract.UnpackLog(event, "SubmitDirectDeposit", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseSubmitDirectDeposit is a log parse operation binding the contract event 0xcde1b1a4bd18b6b8ddb2a80b1fce51c4eee01748267692ac6bc0770a84bc6c58.
//
// Solidity: event SubmitDirectDeposit(address indexed sender, uint256 indexed nonce, address fallbackUser, (bytes10,bytes32) zkAddress, uint64 deposit)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) ParseSubmitDirectDeposit(log types.Log) (*ZkBobDirectDepositQueueSubmitDirectDeposit, error) {
	event := new(ZkBobDirectDepositQueueSubmitDirectDeposit)
	if err := _ZkBobDirectDepositQueue.contract.UnpackLog(event, "SubmitDirectDeposit", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ZkBobDirectDepositQueueUpdateDirectDepositFeeIterator is returned from FilterUpdateDirectDepositFee and is used to iterate over the raw logs and unpacked data for UpdateDirectDepositFee events raised by the ZkBobDirectDepositQueue contract.
type ZkBobDirectDepositQueueUpdateDirectDepositFeeIterator struct {
	Event *ZkBobDirectDepositQueueUpdateDirectDepositFee // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *ZkBobDirectDepositQueueUpdateDirectDepositFeeIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ZkBobDirectDepositQueueUpdateDirectDepositFee)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(ZkBobDirectDepositQueueUpdateDirectDepositFee)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *ZkBobDirectDepositQueueUpdateDirectDepositFeeIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ZkBobDirectDepositQueueUpdateDirectDepositFeeIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ZkBobDirectDepositQueueUpdateDirectDepositFee represents a UpdateDirectDepositFee event raised by the ZkBobDirectDepositQueue contract.
type ZkBobDirectDepositQueueUpdateDirectDepositFee struct {
	Fee uint64
	Raw types.Log // Blockchain specific contextual infos
}

// FilterUpdateDirectDepositFee is a free log retrieval operation binding the contract event 0x4fc5798183ecfb36b62f43c657e712d8b6e8661646d3c90bd3a5202335203180.
//
// Solidity: event UpdateDirectDepositFee(uint64 fee)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) FilterUpdateDirectDepositFee(opts *bind.FilterOpts) (*ZkBobDirectDepositQueueUpdateDirectDepositFeeIterator, error) {

	logs, sub, err := _ZkBobDirectDepositQueue.contract.FilterLogs(opts, "UpdateDirectDepositFee")
	if err != nil {
		return nil, err
	}
	return &ZkBobDirectDepositQueueUpdateDirectDepositFeeIterator{contract: _ZkBobDirectDepositQueue.contract, event: "UpdateDirectDepositFee", logs: logs, sub: sub}, nil
}

// WatchUpdateDirectDepositFee is a free log subscription operation binding the contract event 0x4fc5798183ecfb36b62f43c657e712d8b6e8661646d3c90bd3a5202335203180.
//
// Solidity: event UpdateDirectDepositFee(uint64 fee)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) WatchUpdateDirectDepositFee(opts *bind.WatchOpts, sink chan<- *ZkBobDirectDepositQueueUpdateDirectDepositFee) (event.Subscription, error) {

	logs, sub, err := _ZkBobDirectDepositQueue.contract.WatchLogs(opts, "UpdateDirectDepositFee")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ZkBobDirectDepositQueueUpdateDirectDepositFee)
				if err := _ZkBobDirectDepositQueue.contract.UnpackLog(event, "UpdateDirectDepositFee", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseUpdateDirectDepositFee is a log parse operation binding the contract event 0x4fc5798183ecfb36b62f43c657e712d8b6e8661646d3c90bd3a5202335203180.
//
// Solidity: event UpdateDirectDepositFee(uint64 fee)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) ParseUpdateDirectDepositFee(log types.Log) (*ZkBobDirectDepositQueueUpdateDirectDepositFee, error) {
	event := new(ZkBobDirectDepositQueueUpdateDirectDepositFee)
	if err := _ZkBobDirectDepositQueue.contract.UnpackLog(event, "UpdateDirectDepositFee", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ZkBobDirectDepositQueueUpdateDirectDepositTimeoutIterator is returned from FilterUpdateDirectDepositTimeout and is used to iterate over the raw logs and unpacked data for UpdateDirectDepositTimeout events raised by the ZkBobDirectDepositQueue contract.
type ZkBobDirectDepositQueueUpdateDirectDepositTimeoutIterator struct {
	Event *ZkBobDirectDepositQueueUpdateDirectDepositTimeout // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *ZkBobDirectDepositQueueUpdateDirectDepositTimeoutIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ZkBobDirectDepositQueueUpdateDirectDepositTimeout)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(ZkBobDirectDepositQueueUpdateDirectDepositTimeout)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *ZkBobDirectDepositQueueUpdateDirectDepositTimeoutIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ZkBobDirectDepositQueueUpdateDirectDepositTimeoutIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ZkBobDirectDepositQueueUpdateDirectDepositTimeout represents a UpdateDirectDepositTimeout event raised by the ZkBobDirectDepositQueue contract.
type ZkBobDirectDepositQueueUpdateDirectDepositTimeout struct {
	Timeout *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUpdateDirectDepositTimeout is a free log retrieval operation binding the contract event 0x237f465c227da0b7fcd48ae7b5e7ec9d2ee347abbf6c93b008a616220d06ee39.
//
// Solidity: event UpdateDirectDepositTimeout(uint40 timeout)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) FilterUpdateDirectDepositTimeout(opts *bind.FilterOpts) (*ZkBobDirectDepositQueueUpdateDirectDepositTimeoutIterator, error) {

	logs, sub, err := _ZkBobDirectDepositQueue.contract.FilterLogs(opts, "UpdateDirectDepositTimeout")
	if err != nil {
		return nil, err
	}
	return &ZkBobDirectDepositQueueUpdateDirectDepositTimeoutIterator{contract: _ZkBobDirectDepositQueue.contract, event: "UpdateDirectDepositTimeout", logs: logs, sub: sub}, nil
}

// WatchUpdateDirectDepositTimeout is a free log subscription operation binding the contract event 0x237f465c227da0b7fcd48ae7b5e7ec9d2ee347abbf6c93b008a616220d06ee39.
//
// Solidity: event UpdateDirectDepositTimeout(uint40 timeout)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) WatchUpdateDirectDepositTimeout(opts *bind.WatchOpts, sink chan<- *ZkBobDirectDepositQueueUpdateDirectDepositTimeout) (event.Subscription, error) {

	logs, sub, err := _ZkBobDirectDepositQueue.contract.WatchLogs(opts, "UpdateDirectDepositTimeout")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ZkBobDirectDepositQueueUpdateDirectDepositTimeout)
				if err := _ZkBobDirectDepositQueue.contract.UnpackLog(event, "UpdateDirectDepositTimeout", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseUpdateDirectDepositTimeout is a log parse operation binding the contract event 0x237f465c227da0b7fcd48ae7b5e7ec9d2ee347abbf6c93b008a616220d06ee39.
//
// Solidity: event UpdateDirectDepositTimeout(uint40 timeout)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) ParseUpdateDirectDepositTimeout(log types.Log) (*ZkBobDirectDepositQueueUpdateDirectDepositTimeout, error) {
	event := new(ZkBobDirectDepositQueueUpdateDirectDepositTimeout)
	if err := _ZkBobDirectDepositQueue.contract.UnpackLog(event, "UpdateDirectDepositTimeout", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ZkBobDirectDepositQueueUpdateOperatorManagerIterator is returned from FilterUpdateOperatorManager and is used to iterate over the raw logs and unpacked data for UpdateOperatorManager events raised by the ZkBobDirectDepositQueue contract.
type ZkBobDirectDepositQueueUpdateOperatorManagerIterator struct {
	Event *ZkBobDirectDepositQueueUpdateOperatorManager // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *ZkBobDirectDepositQueueUpdateOperatorManagerIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ZkBobDirectDepositQueueUpdateOperatorManager)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(ZkBobDirectDepositQueueUpdateOperatorManager)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *ZkBobDirectDepositQueueUpdateOperatorManagerIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ZkBobDirectDepositQueueUpdateOperatorManagerIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ZkBobDirectDepositQueueUpdateOperatorManager represents a UpdateOperatorManager event raised by the ZkBobDirectDepositQueue contract.
type ZkBobDirectDepositQueueUpdateOperatorManager struct {
	Manager common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUpdateOperatorManager is a free log retrieval operation binding the contract event 0x267052ecaebdd552dc1b20904f59d83d51ae7add7514165322a7da9ef6cf543b.
//
// Solidity: event UpdateOperatorManager(address manager)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) FilterUpdateOperatorManager(opts *bind.FilterOpts) (*ZkBobDirectDepositQueueUpdateOperatorManagerIterator, error) {

	logs, sub, err := _ZkBobDirectDepositQueue.contract.FilterLogs(opts, "UpdateOperatorManager")
	if err != nil {
		return nil, err
	}
	return &ZkBobDirectDepositQueueUpdateOperatorManagerIterator{contract: _ZkBobDirectDepositQueue.contract, event: "UpdateOperatorManager", logs: logs, sub: sub}, nil
}

// WatchUpdateOperatorManager is a free log subscription operation binding the contract event 0x267052ecaebdd552dc1b20904f59d83d51ae7add7514165322a7da9ef6cf543b.
//
// Solidity: event UpdateOperatorManager(address manager)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) WatchUpdateOperatorManager(opts *bind.WatchOpts, sink chan<- *ZkBobDirectDepositQueueUpdateOperatorManager) (event.Subscription, error) {

	logs, sub, err := _ZkBobDirectDepositQueue.contract.WatchLogs(opts, "UpdateOperatorManager")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ZkBobDirectDepositQueueUpdateOperatorManager)
				if err := _ZkBobDirectDepositQueue.contract.UnpackLog(event, "UpdateOperatorManager", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseUpdateOperatorManager is a log parse operation binding the contract event 0x267052ecaebdd552dc1b20904f59d83d51ae7add7514165322a7da9ef6cf543b.
//
// Solidity: event UpdateOperatorManager(address manager)
func (_ZkBobDirectDepositQueue *ZkBobDirectDepositQueueFilterer) ParseUpdateOperatorManager(log types.Log) (*ZkBobDirectDepositQueueUpdateOperatorManager, error) {
	event := new(ZkBobDirectDepositQueueUpdateOperatorManager)
	if err := _ZkBobDirectDepositQueue.contract.UnpackLog(event, "UpdateOperatorManager", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
