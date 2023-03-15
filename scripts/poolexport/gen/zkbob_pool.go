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

// ZkBobAccountingLimits is an auto generated low-level Go binding around an user-defined struct.
type ZkBobAccountingLimits struct {
	TvlCap                         *big.Int
	Tvl                            *big.Int
	DailyDepositCap                *big.Int
	DailyDepositCapUsage           *big.Int
	DailyWithdrawalCap             *big.Int
	DailyWithdrawalCapUsage        *big.Int
	DailyUserDepositCap            *big.Int
	DailyUserDepositCapUsage       *big.Int
	DepositCap                     *big.Int
	Tier                           uint8
	DailyUserDirectDepositCap      *big.Int
	DailyUserDirectDepositCapUsage *big.Int
	DirectDepositCap               *big.Int
}

// ZkBobAccountingTierLimits is an auto generated low-level Go binding around an user-defined struct.
type ZkBobAccountingTierLimits struct {
	TvlCap                    *big.Int
	DailyDepositCap           uint32
	DailyWithdrawalCap        uint32
	DailyUserDepositCap       uint32
	DepositCap                uint32
	DirectDepositCap          uint32
	DailyUserDirectDepositCap uint32
}

// ZkBobPoolMetaData contains all meta data concerning the ZkBobPool contract.
var ZkBobPoolMetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"__pool_id\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"_token\",\"type\":\"address\"},{\"internalType\":\"contractITransferVerifier\",\"name\":\"_transfer_verifier\",\"type\":\"address\"},{\"internalType\":\"contractITreeVerifier\",\"name\":\"_tree_verifier\",\"type\":\"address\"},{\"internalType\":\"contractIBatchDepositVerifier\",\"name\":\"_batch_deposit_verifier\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"_direct_deposit_queue\",\"type\":\"address\"}],\"stateMutability\":\"nonpayable\",\"type\":\"constructor\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"index\",\"type\":\"uint256\"},{\"indexed\":true,\"internalType\":\"bytes32\",\"name\":\"hash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"bytes\",\"name\":\"message\",\"type\":\"bytes\"}],\"name\":\"Message\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferred\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"manager\",\"type\":\"address\"}],\"name\":\"UpdateKYCProvidersManager\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint8\",\"name\":\"tier\",\"type\":\"uint8\"},{\"components\":[{\"internalType\":\"uint56\",\"name\":\"tvlCap\",\"type\":\"uint56\"},{\"internalType\":\"uint32\",\"name\":\"dailyDepositCap\",\"type\":\"uint32\"},{\"internalType\":\"uint32\",\"name\":\"dailyWithdrawalCap\",\"type\":\"uint32\"},{\"internalType\":\"uint32\",\"name\":\"dailyUserDepositCap\",\"type\":\"uint32\"},{\"internalType\":\"uint32\",\"name\":\"depositCap\",\"type\":\"uint32\"},{\"internalType\":\"uint32\",\"name\":\"directDepositCap\",\"type\":\"uint32\"},{\"internalType\":\"uint32\",\"name\":\"dailyUserDirectDepositCap\",\"type\":\"uint32\"}],\"indexed\":false,\"internalType\":\"structZkBobAccounting.TierLimits\",\"name\":\"limits\",\"type\":\"tuple\"}],\"name\":\"UpdateLimits\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"manager\",\"type\":\"address\"}],\"name\":\"UpdateOperatorManager\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"user\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint8\",\"name\":\"tier\",\"type\":\"uint8\"}],\"name\":\"UpdateTier\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"seller\",\"type\":\"address\"}],\"name\":\"UpdateTokenSeller\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"operator\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"fee\",\"type\":\"uint256\"}],\"name\":\"WithdrawFee\",\"type\":\"event\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"accumulatedFee\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"all_messages_hash\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"_root_after\",\"type\":\"uint256\"},{\"internalType\":\"uint256[]\",\"name\":\"_indices\",\"type\":\"uint256[]\"},{\"internalType\":\"uint256\",\"name\":\"_out_commit\",\"type\":\"uint256\"},{\"internalType\":\"uint256[8]\",\"name\":\"_batch_deposit_proof\",\"type\":\"uint256[8]\"},{\"internalType\":\"uint256[8]\",\"name\":\"_tree_proof\",\"type\":\"uint256[8]\"}],\"name\":\"appendDirectDeposits\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"batch_deposit_verifier\",\"outputs\":[{\"internalType\":\"contractIBatchDepositVerifier\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"denominator\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"pure\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"direct_deposit_queue\",\"outputs\":[{\"internalType\":\"contractIZkBobDirectDepositQueue\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_user\",\"type\":\"address\"}],\"name\":\"getLimitsFor\",\"outputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"tvlCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tvl\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"dailyDepositCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"dailyDepositCapUsage\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"dailyWithdrawalCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"dailyWithdrawalCapUsage\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"dailyUserDepositCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"dailyUserDepositCapUsage\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"depositCap\",\"type\":\"uint256\"},{\"internalType\":\"uint8\",\"name\":\"tier\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"dailyUserDirectDepositCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"dailyUserDirectDepositCapUsage\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"directDepositCap\",\"type\":\"uint256\"}],\"internalType\":\"structZkBobAccounting.Limits\",\"name\":\"\",\"type\":\"tuple\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"_root\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"_tvlCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"_dailyDepositCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"_dailyWithdrawalCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"_dailyUserDepositCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"_depositCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"_dailyUserDirectDepositCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"_directDepositCap\",\"type\":\"uint256\"}],\"name\":\"initialize\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"kycProvidersManager\",\"outputs\":[{\"internalType\":\"contractIKycProvidersManager\",\"name\":\"res\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"nullifiers\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"operatorManager\",\"outputs\":[{\"internalType\":\"contractIOperatorManager\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"pool_id\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"pool_index\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_sender\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"_amount\",\"type\":\"uint256\"}],\"name\":\"recordDirectDeposit\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"renounceOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint8\",\"name\":\"_tier\",\"type\":\"uint8\"}],\"name\":\"resetDailyLimits\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"roots\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"contractIKycProvidersManager\",\"name\":\"_kycProvidersManager\",\"type\":\"address\"}],\"name\":\"setKycProvidersManager\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint8\",\"name\":\"_tier\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"_tvlCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"_dailyDepositCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"_dailyWithdrawalCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"_dailyUserDepositCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"_depositCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"_dailyUserDirectDepositCap\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"_directDepositCap\",\"type\":\"uint256\"}],\"name\":\"setLimits\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"contractIOperatorManager\",\"name\":\"_operatorManager\",\"type\":\"address\"}],\"name\":\"setOperatorManager\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_seller\",\"type\":\"address\"}],\"name\":\"setTokenSeller\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint8\",\"name\":\"_tier\",\"type\":\"uint8\"},{\"internalType\":\"address[]\",\"name\":\"_users\",\"type\":\"address[]\"}],\"name\":\"setUsersTier\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"token\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"tokenSeller\",\"outputs\":[{\"internalType\":\"contractITokenSeller\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"transact\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"transferOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"transfer_verifier\",\"outputs\":[{\"internalType\":\"contractITransferVerifier\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"tree_verifier\",\"outputs\":[{\"internalType\":\"contractITreeVerifier\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"index\",\"type\":\"uint256\"},{\"internalType\":\"bytes32[]\",\"name\":\"hashes\",\"type\":\"bytes32[]\"},{\"internalType\":\"bytes[]\",\"name\":\"messages\",\"type\":\"bytes[]\"}],\"name\":\"uploadMessages\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32[]\",\"name\":\"keys\",\"type\":\"bytes32[]\"},{\"internalType\":\"bytes32[]\",\"name\":\"values\",\"type\":\"bytes32[]\"}],\"name\":\"uploadState\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_operator\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"_to\",\"type\":\"address\"}],\"name\":\"withdrawFee\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]",
}

// ZkBobPoolABI is the input ABI used to generate the binding from.
// Deprecated: Use ZkBobPoolMetaData.ABI instead.
var ZkBobPoolABI = ZkBobPoolMetaData.ABI

// ZkBobPool is an auto generated Go binding around an Ethereum contract.
type ZkBobPool struct {
	ZkBobPoolCaller     // Read-only binding to the contract
	ZkBobPoolTransactor // Write-only binding to the contract
	ZkBobPoolFilterer   // Log filterer for contract events
}

// ZkBobPoolCaller is an auto generated read-only Go binding around an Ethereum contract.
type ZkBobPoolCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ZkBobPoolTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ZkBobPoolTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ZkBobPoolFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ZkBobPoolFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ZkBobPoolSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ZkBobPoolSession struct {
	Contract     *ZkBobPool        // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// ZkBobPoolCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ZkBobPoolCallerSession struct {
	Contract *ZkBobPoolCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts    // Call options to use throughout this session
}

// ZkBobPoolTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ZkBobPoolTransactorSession struct {
	Contract     *ZkBobPoolTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts    // Transaction auth options to use throughout this session
}

// ZkBobPoolRaw is an auto generated low-level Go binding around an Ethereum contract.
type ZkBobPoolRaw struct {
	Contract *ZkBobPool // Generic contract binding to access the raw methods on
}

// ZkBobPoolCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ZkBobPoolCallerRaw struct {
	Contract *ZkBobPoolCaller // Generic read-only contract binding to access the raw methods on
}

// ZkBobPoolTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ZkBobPoolTransactorRaw struct {
	Contract *ZkBobPoolTransactor // Generic write-only contract binding to access the raw methods on
}

// NewZkBobPool creates a new instance of ZkBobPool, bound to a specific deployed contract.
func NewZkBobPool(address common.Address, backend bind.ContractBackend) (*ZkBobPool, error) {
	contract, err := bindZkBobPool(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ZkBobPool{ZkBobPoolCaller: ZkBobPoolCaller{contract: contract}, ZkBobPoolTransactor: ZkBobPoolTransactor{contract: contract}, ZkBobPoolFilterer: ZkBobPoolFilterer{contract: contract}}, nil
}

// NewZkBobPoolCaller creates a new read-only instance of ZkBobPool, bound to a specific deployed contract.
func NewZkBobPoolCaller(address common.Address, caller bind.ContractCaller) (*ZkBobPoolCaller, error) {
	contract, err := bindZkBobPool(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ZkBobPoolCaller{contract: contract}, nil
}

// NewZkBobPoolTransactor creates a new write-only instance of ZkBobPool, bound to a specific deployed contract.
func NewZkBobPoolTransactor(address common.Address, transactor bind.ContractTransactor) (*ZkBobPoolTransactor, error) {
	contract, err := bindZkBobPool(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ZkBobPoolTransactor{contract: contract}, nil
}

// NewZkBobPoolFilterer creates a new log filterer instance of ZkBobPool, bound to a specific deployed contract.
func NewZkBobPoolFilterer(address common.Address, filterer bind.ContractFilterer) (*ZkBobPoolFilterer, error) {
	contract, err := bindZkBobPool(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ZkBobPoolFilterer{contract: contract}, nil
}

// bindZkBobPool binds a generic wrapper to an already deployed contract.
func bindZkBobPool(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ZkBobPoolMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ZkBobPool *ZkBobPoolRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ZkBobPool.Contract.ZkBobPoolCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ZkBobPool *ZkBobPoolRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ZkBobPool.Contract.ZkBobPoolTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ZkBobPool *ZkBobPoolRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ZkBobPool.Contract.ZkBobPoolTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ZkBobPool *ZkBobPoolCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ZkBobPool.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ZkBobPool *ZkBobPoolTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ZkBobPool.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ZkBobPool *ZkBobPoolTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ZkBobPool.Contract.contract.Transact(opts, method, params...)
}

// AccumulatedFee is a free data retrieval call binding the contract method 0x50840040.
//
// Solidity: function accumulatedFee(address ) view returns(uint256)
func (_ZkBobPool *ZkBobPoolCaller) AccumulatedFee(opts *bind.CallOpts, arg0 common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "accumulatedFee", arg0)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// AccumulatedFee is a free data retrieval call binding the contract method 0x50840040.
//
// Solidity: function accumulatedFee(address ) view returns(uint256)
func (_ZkBobPool *ZkBobPoolSession) AccumulatedFee(arg0 common.Address) (*big.Int, error) {
	return _ZkBobPool.Contract.AccumulatedFee(&_ZkBobPool.CallOpts, arg0)
}

// AccumulatedFee is a free data retrieval call binding the contract method 0x50840040.
//
// Solidity: function accumulatedFee(address ) view returns(uint256)
func (_ZkBobPool *ZkBobPoolCallerSession) AccumulatedFee(arg0 common.Address) (*big.Int, error) {
	return _ZkBobPool.Contract.AccumulatedFee(&_ZkBobPool.CallOpts, arg0)
}

// AllMessagesHash is a free data retrieval call binding the contract method 0x1dd69d06.
//
// Solidity: function all_messages_hash() view returns(bytes32)
func (_ZkBobPool *ZkBobPoolCaller) AllMessagesHash(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "all_messages_hash")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// AllMessagesHash is a free data retrieval call binding the contract method 0x1dd69d06.
//
// Solidity: function all_messages_hash() view returns(bytes32)
func (_ZkBobPool *ZkBobPoolSession) AllMessagesHash() ([32]byte, error) {
	return _ZkBobPool.Contract.AllMessagesHash(&_ZkBobPool.CallOpts)
}

// AllMessagesHash is a free data retrieval call binding the contract method 0x1dd69d06.
//
// Solidity: function all_messages_hash() view returns(bytes32)
func (_ZkBobPool *ZkBobPoolCallerSession) AllMessagesHash() ([32]byte, error) {
	return _ZkBobPool.Contract.AllMessagesHash(&_ZkBobPool.CallOpts)
}

// BatchDepositVerifier is a free data retrieval call binding the contract method 0x83f26e3b.
//
// Solidity: function batch_deposit_verifier() view returns(address)
func (_ZkBobPool *ZkBobPoolCaller) BatchDepositVerifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "batch_deposit_verifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// BatchDepositVerifier is a free data retrieval call binding the contract method 0x83f26e3b.
//
// Solidity: function batch_deposit_verifier() view returns(address)
func (_ZkBobPool *ZkBobPoolSession) BatchDepositVerifier() (common.Address, error) {
	return _ZkBobPool.Contract.BatchDepositVerifier(&_ZkBobPool.CallOpts)
}

// BatchDepositVerifier is a free data retrieval call binding the contract method 0x83f26e3b.
//
// Solidity: function batch_deposit_verifier() view returns(address)
func (_ZkBobPool *ZkBobPoolCallerSession) BatchDepositVerifier() (common.Address, error) {
	return _ZkBobPool.Contract.BatchDepositVerifier(&_ZkBobPool.CallOpts)
}

// Denominator is a free data retrieval call binding the contract method 0x96ce0795.
//
// Solidity: function denominator() pure returns(uint256)
func (_ZkBobPool *ZkBobPoolCaller) Denominator(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "denominator")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// Denominator is a free data retrieval call binding the contract method 0x96ce0795.
//
// Solidity: function denominator() pure returns(uint256)
func (_ZkBobPool *ZkBobPoolSession) Denominator() (*big.Int, error) {
	return _ZkBobPool.Contract.Denominator(&_ZkBobPool.CallOpts)
}

// Denominator is a free data retrieval call binding the contract method 0x96ce0795.
//
// Solidity: function denominator() pure returns(uint256)
func (_ZkBobPool *ZkBobPoolCallerSession) Denominator() (*big.Int, error) {
	return _ZkBobPool.Contract.Denominator(&_ZkBobPool.CallOpts)
}

// DirectDepositQueue is a free data retrieval call binding the contract method 0x2747f41d.
//
// Solidity: function direct_deposit_queue() view returns(address)
func (_ZkBobPool *ZkBobPoolCaller) DirectDepositQueue(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "direct_deposit_queue")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// DirectDepositQueue is a free data retrieval call binding the contract method 0x2747f41d.
//
// Solidity: function direct_deposit_queue() view returns(address)
func (_ZkBobPool *ZkBobPoolSession) DirectDepositQueue() (common.Address, error) {
	return _ZkBobPool.Contract.DirectDepositQueue(&_ZkBobPool.CallOpts)
}

// DirectDepositQueue is a free data retrieval call binding the contract method 0x2747f41d.
//
// Solidity: function direct_deposit_queue() view returns(address)
func (_ZkBobPool *ZkBobPoolCallerSession) DirectDepositQueue() (common.Address, error) {
	return _ZkBobPool.Contract.DirectDepositQueue(&_ZkBobPool.CallOpts)
}

// GetLimitsFor is a free data retrieval call binding the contract method 0x4279a99e.
//
// Solidity: function getLimitsFor(address _user) view returns((uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint8,uint256,uint256,uint256))
func (_ZkBobPool *ZkBobPoolCaller) GetLimitsFor(opts *bind.CallOpts, _user common.Address) (ZkBobAccountingLimits, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "getLimitsFor", _user)

	if err != nil {
		return *new(ZkBobAccountingLimits), err
	}

	out0 := *abi.ConvertType(out[0], new(ZkBobAccountingLimits)).(*ZkBobAccountingLimits)

	return out0, err

}

// GetLimitsFor is a free data retrieval call binding the contract method 0x4279a99e.
//
// Solidity: function getLimitsFor(address _user) view returns((uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint8,uint256,uint256,uint256))
func (_ZkBobPool *ZkBobPoolSession) GetLimitsFor(_user common.Address) (ZkBobAccountingLimits, error) {
	return _ZkBobPool.Contract.GetLimitsFor(&_ZkBobPool.CallOpts, _user)
}

// GetLimitsFor is a free data retrieval call binding the contract method 0x4279a99e.
//
// Solidity: function getLimitsFor(address _user) view returns((uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint8,uint256,uint256,uint256))
func (_ZkBobPool *ZkBobPoolCallerSession) GetLimitsFor(_user common.Address) (ZkBobAccountingLimits, error) {
	return _ZkBobPool.Contract.GetLimitsFor(&_ZkBobPool.CallOpts, _user)
}

// KycProvidersManager is a free data retrieval call binding the contract method 0x002befce.
//
// Solidity: function kycProvidersManager() view returns(address res)
func (_ZkBobPool *ZkBobPoolCaller) KycProvidersManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "kycProvidersManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// KycProvidersManager is a free data retrieval call binding the contract method 0x002befce.
//
// Solidity: function kycProvidersManager() view returns(address res)
func (_ZkBobPool *ZkBobPoolSession) KycProvidersManager() (common.Address, error) {
	return _ZkBobPool.Contract.KycProvidersManager(&_ZkBobPool.CallOpts)
}

// KycProvidersManager is a free data retrieval call binding the contract method 0x002befce.
//
// Solidity: function kycProvidersManager() view returns(address res)
func (_ZkBobPool *ZkBobPoolCallerSession) KycProvidersManager() (common.Address, error) {
	return _ZkBobPool.Contract.KycProvidersManager(&_ZkBobPool.CallOpts)
}

// Nullifiers is a free data retrieval call binding the contract method 0xd21e82ab.
//
// Solidity: function nullifiers(uint256 ) view returns(uint256)
func (_ZkBobPool *ZkBobPoolCaller) Nullifiers(opts *bind.CallOpts, arg0 *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "nullifiers", arg0)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// Nullifiers is a free data retrieval call binding the contract method 0xd21e82ab.
//
// Solidity: function nullifiers(uint256 ) view returns(uint256)
func (_ZkBobPool *ZkBobPoolSession) Nullifiers(arg0 *big.Int) (*big.Int, error) {
	return _ZkBobPool.Contract.Nullifiers(&_ZkBobPool.CallOpts, arg0)
}

// Nullifiers is a free data retrieval call binding the contract method 0xd21e82ab.
//
// Solidity: function nullifiers(uint256 ) view returns(uint256)
func (_ZkBobPool *ZkBobPoolCallerSession) Nullifiers(arg0 *big.Int) (*big.Int, error) {
	return _ZkBobPool.Contract.Nullifiers(&_ZkBobPool.CallOpts, arg0)
}

// OperatorManager is a free data retrieval call binding the contract method 0x2f84c96f.
//
// Solidity: function operatorManager() view returns(address)
func (_ZkBobPool *ZkBobPoolCaller) OperatorManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "operatorManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// OperatorManager is a free data retrieval call binding the contract method 0x2f84c96f.
//
// Solidity: function operatorManager() view returns(address)
func (_ZkBobPool *ZkBobPoolSession) OperatorManager() (common.Address, error) {
	return _ZkBobPool.Contract.OperatorManager(&_ZkBobPool.CallOpts)
}

// OperatorManager is a free data retrieval call binding the contract method 0x2f84c96f.
//
// Solidity: function operatorManager() view returns(address)
func (_ZkBobPool *ZkBobPoolCallerSession) OperatorManager() (common.Address, error) {
	return _ZkBobPool.Contract.OperatorManager(&_ZkBobPool.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ZkBobPool *ZkBobPoolCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ZkBobPool *ZkBobPoolSession) Owner() (common.Address, error) {
	return _ZkBobPool.Contract.Owner(&_ZkBobPool.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ZkBobPool *ZkBobPoolCallerSession) Owner() (common.Address, error) {
	return _ZkBobPool.Contract.Owner(&_ZkBobPool.CallOpts)
}

// PoolId is a free data retrieval call binding the contract method 0x9d8ad6e4.
//
// Solidity: function pool_id() view returns(uint256)
func (_ZkBobPool *ZkBobPoolCaller) PoolId(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "pool_id")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PoolId is a free data retrieval call binding the contract method 0x9d8ad6e4.
//
// Solidity: function pool_id() view returns(uint256)
func (_ZkBobPool *ZkBobPoolSession) PoolId() (*big.Int, error) {
	return _ZkBobPool.Contract.PoolId(&_ZkBobPool.CallOpts)
}

// PoolId is a free data retrieval call binding the contract method 0x9d8ad6e4.
//
// Solidity: function pool_id() view returns(uint256)
func (_ZkBobPool *ZkBobPoolCallerSession) PoolId() (*big.Int, error) {
	return _ZkBobPool.Contract.PoolId(&_ZkBobPool.CallOpts)
}

// PoolIndex is a free data retrieval call binding the contract method 0x8fff4676.
//
// Solidity: function pool_index() view returns(uint256)
func (_ZkBobPool *ZkBobPoolCaller) PoolIndex(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "pool_index")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// PoolIndex is a free data retrieval call binding the contract method 0x8fff4676.
//
// Solidity: function pool_index() view returns(uint256)
func (_ZkBobPool *ZkBobPoolSession) PoolIndex() (*big.Int, error) {
	return _ZkBobPool.Contract.PoolIndex(&_ZkBobPool.CallOpts)
}

// PoolIndex is a free data retrieval call binding the contract method 0x8fff4676.
//
// Solidity: function pool_index() view returns(uint256)
func (_ZkBobPool *ZkBobPoolCallerSession) PoolIndex() (*big.Int, error) {
	return _ZkBobPool.Contract.PoolIndex(&_ZkBobPool.CallOpts)
}

// Roots is a free data retrieval call binding the contract method 0xc2b40ae4.
//
// Solidity: function roots(uint256 ) view returns(uint256)
func (_ZkBobPool *ZkBobPoolCaller) Roots(opts *bind.CallOpts, arg0 *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "roots", arg0)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// Roots is a free data retrieval call binding the contract method 0xc2b40ae4.
//
// Solidity: function roots(uint256 ) view returns(uint256)
func (_ZkBobPool *ZkBobPoolSession) Roots(arg0 *big.Int) (*big.Int, error) {
	return _ZkBobPool.Contract.Roots(&_ZkBobPool.CallOpts, arg0)
}

// Roots is a free data retrieval call binding the contract method 0xc2b40ae4.
//
// Solidity: function roots(uint256 ) view returns(uint256)
func (_ZkBobPool *ZkBobPoolCallerSession) Roots(arg0 *big.Int) (*big.Int, error) {
	return _ZkBobPool.Contract.Roots(&_ZkBobPool.CallOpts, arg0)
}

// Token is a free data retrieval call binding the contract method 0xfc0c546a.
//
// Solidity: function token() view returns(address)
func (_ZkBobPool *ZkBobPoolCaller) Token(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "token")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Token is a free data retrieval call binding the contract method 0xfc0c546a.
//
// Solidity: function token() view returns(address)
func (_ZkBobPool *ZkBobPoolSession) Token() (common.Address, error) {
	return _ZkBobPool.Contract.Token(&_ZkBobPool.CallOpts)
}

// Token is a free data retrieval call binding the contract method 0xfc0c546a.
//
// Solidity: function token() view returns(address)
func (_ZkBobPool *ZkBobPoolCallerSession) Token() (common.Address, error) {
	return _ZkBobPool.Contract.Token(&_ZkBobPool.CallOpts)
}

// TokenSeller is a free data retrieval call binding the contract method 0x0c6248de.
//
// Solidity: function tokenSeller() view returns(address)
func (_ZkBobPool *ZkBobPoolCaller) TokenSeller(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "tokenSeller")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// TokenSeller is a free data retrieval call binding the contract method 0x0c6248de.
//
// Solidity: function tokenSeller() view returns(address)
func (_ZkBobPool *ZkBobPoolSession) TokenSeller() (common.Address, error) {
	return _ZkBobPool.Contract.TokenSeller(&_ZkBobPool.CallOpts)
}

// TokenSeller is a free data retrieval call binding the contract method 0x0c6248de.
//
// Solidity: function tokenSeller() view returns(address)
func (_ZkBobPool *ZkBobPoolCallerSession) TokenSeller() (common.Address, error) {
	return _ZkBobPool.Contract.TokenSeller(&_ZkBobPool.CallOpts)
}

// TransferVerifier is a free data retrieval call binding the contract method 0x171ef300.
//
// Solidity: function transfer_verifier() view returns(address)
func (_ZkBobPool *ZkBobPoolCaller) TransferVerifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "transfer_verifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// TransferVerifier is a free data retrieval call binding the contract method 0x171ef300.
//
// Solidity: function transfer_verifier() view returns(address)
func (_ZkBobPool *ZkBobPoolSession) TransferVerifier() (common.Address, error) {
	return _ZkBobPool.Contract.TransferVerifier(&_ZkBobPool.CallOpts)
}

// TransferVerifier is a free data retrieval call binding the contract method 0x171ef300.
//
// Solidity: function transfer_verifier() view returns(address)
func (_ZkBobPool *ZkBobPoolCallerSession) TransferVerifier() (common.Address, error) {
	return _ZkBobPool.Contract.TransferVerifier(&_ZkBobPool.CallOpts)
}

// TreeVerifier is a free data retrieval call binding the contract method 0x3701f979.
//
// Solidity: function tree_verifier() view returns(address)
func (_ZkBobPool *ZkBobPoolCaller) TreeVerifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ZkBobPool.contract.Call(opts, &out, "tree_verifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// TreeVerifier is a free data retrieval call binding the contract method 0x3701f979.
//
// Solidity: function tree_verifier() view returns(address)
func (_ZkBobPool *ZkBobPoolSession) TreeVerifier() (common.Address, error) {
	return _ZkBobPool.Contract.TreeVerifier(&_ZkBobPool.CallOpts)
}

// TreeVerifier is a free data retrieval call binding the contract method 0x3701f979.
//
// Solidity: function tree_verifier() view returns(address)
func (_ZkBobPool *ZkBobPoolCallerSession) TreeVerifier() (common.Address, error) {
	return _ZkBobPool.Contract.TreeVerifier(&_ZkBobPool.CallOpts)
}

// AppendDirectDeposits is a paid mutator transaction binding the contract method 0x1dc4cb33.
//
// Solidity: function appendDirectDeposits(uint256 _root_after, uint256[] _indices, uint256 _out_commit, uint256[8] _batch_deposit_proof, uint256[8] _tree_proof) returns()
func (_ZkBobPool *ZkBobPoolTransactor) AppendDirectDeposits(opts *bind.TransactOpts, _root_after *big.Int, _indices []*big.Int, _out_commit *big.Int, _batch_deposit_proof [8]*big.Int, _tree_proof [8]*big.Int) (*types.Transaction, error) {
	return _ZkBobPool.contract.Transact(opts, "appendDirectDeposits", _root_after, _indices, _out_commit, _batch_deposit_proof, _tree_proof)
}

// AppendDirectDeposits is a paid mutator transaction binding the contract method 0x1dc4cb33.
//
// Solidity: function appendDirectDeposits(uint256 _root_after, uint256[] _indices, uint256 _out_commit, uint256[8] _batch_deposit_proof, uint256[8] _tree_proof) returns()
func (_ZkBobPool *ZkBobPoolSession) AppendDirectDeposits(_root_after *big.Int, _indices []*big.Int, _out_commit *big.Int, _batch_deposit_proof [8]*big.Int, _tree_proof [8]*big.Int) (*types.Transaction, error) {
	return _ZkBobPool.Contract.AppendDirectDeposits(&_ZkBobPool.TransactOpts, _root_after, _indices, _out_commit, _batch_deposit_proof, _tree_proof)
}

// AppendDirectDeposits is a paid mutator transaction binding the contract method 0x1dc4cb33.
//
// Solidity: function appendDirectDeposits(uint256 _root_after, uint256[] _indices, uint256 _out_commit, uint256[8] _batch_deposit_proof, uint256[8] _tree_proof) returns()
func (_ZkBobPool *ZkBobPoolTransactorSession) AppendDirectDeposits(_root_after *big.Int, _indices []*big.Int, _out_commit *big.Int, _batch_deposit_proof [8]*big.Int, _tree_proof [8]*big.Int) (*types.Transaction, error) {
	return _ZkBobPool.Contract.AppendDirectDeposits(&_ZkBobPool.TransactOpts, _root_after, _indices, _out_commit, _batch_deposit_proof, _tree_proof)
}

// Initialize is a paid mutator transaction binding the contract method 0x6d55160c.
//
// Solidity: function initialize(uint256 _root, uint256 _tvlCap, uint256 _dailyDepositCap, uint256 _dailyWithdrawalCap, uint256 _dailyUserDepositCap, uint256 _depositCap, uint256 _dailyUserDirectDepositCap, uint256 _directDepositCap) returns()
func (_ZkBobPool *ZkBobPoolTransactor) Initialize(opts *bind.TransactOpts, _root *big.Int, _tvlCap *big.Int, _dailyDepositCap *big.Int, _dailyWithdrawalCap *big.Int, _dailyUserDepositCap *big.Int, _depositCap *big.Int, _dailyUserDirectDepositCap *big.Int, _directDepositCap *big.Int) (*types.Transaction, error) {
	return _ZkBobPool.contract.Transact(opts, "initialize", _root, _tvlCap, _dailyDepositCap, _dailyWithdrawalCap, _dailyUserDepositCap, _depositCap, _dailyUserDirectDepositCap, _directDepositCap)
}

// Initialize is a paid mutator transaction binding the contract method 0x6d55160c.
//
// Solidity: function initialize(uint256 _root, uint256 _tvlCap, uint256 _dailyDepositCap, uint256 _dailyWithdrawalCap, uint256 _dailyUserDepositCap, uint256 _depositCap, uint256 _dailyUserDirectDepositCap, uint256 _directDepositCap) returns()
func (_ZkBobPool *ZkBobPoolSession) Initialize(_root *big.Int, _tvlCap *big.Int, _dailyDepositCap *big.Int, _dailyWithdrawalCap *big.Int, _dailyUserDepositCap *big.Int, _depositCap *big.Int, _dailyUserDirectDepositCap *big.Int, _directDepositCap *big.Int) (*types.Transaction, error) {
	return _ZkBobPool.Contract.Initialize(&_ZkBobPool.TransactOpts, _root, _tvlCap, _dailyDepositCap, _dailyWithdrawalCap, _dailyUserDepositCap, _depositCap, _dailyUserDirectDepositCap, _directDepositCap)
}

// Initialize is a paid mutator transaction binding the contract method 0x6d55160c.
//
// Solidity: function initialize(uint256 _root, uint256 _tvlCap, uint256 _dailyDepositCap, uint256 _dailyWithdrawalCap, uint256 _dailyUserDepositCap, uint256 _depositCap, uint256 _dailyUserDirectDepositCap, uint256 _directDepositCap) returns()
func (_ZkBobPool *ZkBobPoolTransactorSession) Initialize(_root *big.Int, _tvlCap *big.Int, _dailyDepositCap *big.Int, _dailyWithdrawalCap *big.Int, _dailyUserDepositCap *big.Int, _depositCap *big.Int, _dailyUserDirectDepositCap *big.Int, _directDepositCap *big.Int) (*types.Transaction, error) {
	return _ZkBobPool.Contract.Initialize(&_ZkBobPool.TransactOpts, _root, _tvlCap, _dailyDepositCap, _dailyWithdrawalCap, _dailyUserDepositCap, _depositCap, _dailyUserDirectDepositCap, _directDepositCap)
}

// RecordDirectDeposit is a paid mutator transaction binding the contract method 0x1cbec711.
//
// Solidity: function recordDirectDeposit(address _sender, uint256 _amount) returns()
func (_ZkBobPool *ZkBobPoolTransactor) RecordDirectDeposit(opts *bind.TransactOpts, _sender common.Address, _amount *big.Int) (*types.Transaction, error) {
	return _ZkBobPool.contract.Transact(opts, "recordDirectDeposit", _sender, _amount)
}

// RecordDirectDeposit is a paid mutator transaction binding the contract method 0x1cbec711.
//
// Solidity: function recordDirectDeposit(address _sender, uint256 _amount) returns()
func (_ZkBobPool *ZkBobPoolSession) RecordDirectDeposit(_sender common.Address, _amount *big.Int) (*types.Transaction, error) {
	return _ZkBobPool.Contract.RecordDirectDeposit(&_ZkBobPool.TransactOpts, _sender, _amount)
}

// RecordDirectDeposit is a paid mutator transaction binding the contract method 0x1cbec711.
//
// Solidity: function recordDirectDeposit(address _sender, uint256 _amount) returns()
func (_ZkBobPool *ZkBobPoolTransactorSession) RecordDirectDeposit(_sender common.Address, _amount *big.Int) (*types.Transaction, error) {
	return _ZkBobPool.Contract.RecordDirectDeposit(&_ZkBobPool.TransactOpts, _sender, _amount)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ZkBobPool *ZkBobPoolTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ZkBobPool.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ZkBobPool *ZkBobPoolSession) RenounceOwnership() (*types.Transaction, error) {
	return _ZkBobPool.Contract.RenounceOwnership(&_ZkBobPool.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ZkBobPool *ZkBobPoolTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _ZkBobPool.Contract.RenounceOwnership(&_ZkBobPool.TransactOpts)
}

// ResetDailyLimits is a paid mutator transaction binding the contract method 0x46adf6ce.
//
// Solidity: function resetDailyLimits(uint8 _tier) returns()
func (_ZkBobPool *ZkBobPoolTransactor) ResetDailyLimits(opts *bind.TransactOpts, _tier uint8) (*types.Transaction, error) {
	return _ZkBobPool.contract.Transact(opts, "resetDailyLimits", _tier)
}

// ResetDailyLimits is a paid mutator transaction binding the contract method 0x46adf6ce.
//
// Solidity: function resetDailyLimits(uint8 _tier) returns()
func (_ZkBobPool *ZkBobPoolSession) ResetDailyLimits(_tier uint8) (*types.Transaction, error) {
	return _ZkBobPool.Contract.ResetDailyLimits(&_ZkBobPool.TransactOpts, _tier)
}

// ResetDailyLimits is a paid mutator transaction binding the contract method 0x46adf6ce.
//
// Solidity: function resetDailyLimits(uint8 _tier) returns()
func (_ZkBobPool *ZkBobPoolTransactorSession) ResetDailyLimits(_tier uint8) (*types.Transaction, error) {
	return _ZkBobPool.Contract.ResetDailyLimits(&_ZkBobPool.TransactOpts, _tier)
}

// SetKycProvidersManager is a paid mutator transaction binding the contract method 0x790c3a33.
//
// Solidity: function setKycProvidersManager(address _kycProvidersManager) returns()
func (_ZkBobPool *ZkBobPoolTransactor) SetKycProvidersManager(opts *bind.TransactOpts, _kycProvidersManager common.Address) (*types.Transaction, error) {
	return _ZkBobPool.contract.Transact(opts, "setKycProvidersManager", _kycProvidersManager)
}

// SetKycProvidersManager is a paid mutator transaction binding the contract method 0x790c3a33.
//
// Solidity: function setKycProvidersManager(address _kycProvidersManager) returns()
func (_ZkBobPool *ZkBobPoolSession) SetKycProvidersManager(_kycProvidersManager common.Address) (*types.Transaction, error) {
	return _ZkBobPool.Contract.SetKycProvidersManager(&_ZkBobPool.TransactOpts, _kycProvidersManager)
}

// SetKycProvidersManager is a paid mutator transaction binding the contract method 0x790c3a33.
//
// Solidity: function setKycProvidersManager(address _kycProvidersManager) returns()
func (_ZkBobPool *ZkBobPoolTransactorSession) SetKycProvidersManager(_kycProvidersManager common.Address) (*types.Transaction, error) {
	return _ZkBobPool.Contract.SetKycProvidersManager(&_ZkBobPool.TransactOpts, _kycProvidersManager)
}

// SetLimits is a paid mutator transaction binding the contract method 0xe8fd02e4.
//
// Solidity: function setLimits(uint8 _tier, uint256 _tvlCap, uint256 _dailyDepositCap, uint256 _dailyWithdrawalCap, uint256 _dailyUserDepositCap, uint256 _depositCap, uint256 _dailyUserDirectDepositCap, uint256 _directDepositCap) returns()
func (_ZkBobPool *ZkBobPoolTransactor) SetLimits(opts *bind.TransactOpts, _tier uint8, _tvlCap *big.Int, _dailyDepositCap *big.Int, _dailyWithdrawalCap *big.Int, _dailyUserDepositCap *big.Int, _depositCap *big.Int, _dailyUserDirectDepositCap *big.Int, _directDepositCap *big.Int) (*types.Transaction, error) {
	return _ZkBobPool.contract.Transact(opts, "setLimits", _tier, _tvlCap, _dailyDepositCap, _dailyWithdrawalCap, _dailyUserDepositCap, _depositCap, _dailyUserDirectDepositCap, _directDepositCap)
}

// SetLimits is a paid mutator transaction binding the contract method 0xe8fd02e4.
//
// Solidity: function setLimits(uint8 _tier, uint256 _tvlCap, uint256 _dailyDepositCap, uint256 _dailyWithdrawalCap, uint256 _dailyUserDepositCap, uint256 _depositCap, uint256 _dailyUserDirectDepositCap, uint256 _directDepositCap) returns()
func (_ZkBobPool *ZkBobPoolSession) SetLimits(_tier uint8, _tvlCap *big.Int, _dailyDepositCap *big.Int, _dailyWithdrawalCap *big.Int, _dailyUserDepositCap *big.Int, _depositCap *big.Int, _dailyUserDirectDepositCap *big.Int, _directDepositCap *big.Int) (*types.Transaction, error) {
	return _ZkBobPool.Contract.SetLimits(&_ZkBobPool.TransactOpts, _tier, _tvlCap, _dailyDepositCap, _dailyWithdrawalCap, _dailyUserDepositCap, _depositCap, _dailyUserDirectDepositCap, _directDepositCap)
}

// SetLimits is a paid mutator transaction binding the contract method 0xe8fd02e4.
//
// Solidity: function setLimits(uint8 _tier, uint256 _tvlCap, uint256 _dailyDepositCap, uint256 _dailyWithdrawalCap, uint256 _dailyUserDepositCap, uint256 _depositCap, uint256 _dailyUserDirectDepositCap, uint256 _directDepositCap) returns()
func (_ZkBobPool *ZkBobPoolTransactorSession) SetLimits(_tier uint8, _tvlCap *big.Int, _dailyDepositCap *big.Int, _dailyWithdrawalCap *big.Int, _dailyUserDepositCap *big.Int, _depositCap *big.Int, _dailyUserDirectDepositCap *big.Int, _directDepositCap *big.Int) (*types.Transaction, error) {
	return _ZkBobPool.Contract.SetLimits(&_ZkBobPool.TransactOpts, _tier, _tvlCap, _dailyDepositCap, _dailyWithdrawalCap, _dailyUserDepositCap, _depositCap, _dailyUserDirectDepositCap, _directDepositCap)
}

// SetOperatorManager is a paid mutator transaction binding the contract method 0xc41100fa.
//
// Solidity: function setOperatorManager(address _operatorManager) returns()
func (_ZkBobPool *ZkBobPoolTransactor) SetOperatorManager(opts *bind.TransactOpts, _operatorManager common.Address) (*types.Transaction, error) {
	return _ZkBobPool.contract.Transact(opts, "setOperatorManager", _operatorManager)
}

// SetOperatorManager is a paid mutator transaction binding the contract method 0xc41100fa.
//
// Solidity: function setOperatorManager(address _operatorManager) returns()
func (_ZkBobPool *ZkBobPoolSession) SetOperatorManager(_operatorManager common.Address) (*types.Transaction, error) {
	return _ZkBobPool.Contract.SetOperatorManager(&_ZkBobPool.TransactOpts, _operatorManager)
}

// SetOperatorManager is a paid mutator transaction binding the contract method 0xc41100fa.
//
// Solidity: function setOperatorManager(address _operatorManager) returns()
func (_ZkBobPool *ZkBobPoolTransactorSession) SetOperatorManager(_operatorManager common.Address) (*types.Transaction, error) {
	return _ZkBobPool.Contract.SetOperatorManager(&_ZkBobPool.TransactOpts, _operatorManager)
}

// SetTokenSeller is a paid mutator transaction binding the contract method 0x7a22393b.
//
// Solidity: function setTokenSeller(address _seller) returns()
func (_ZkBobPool *ZkBobPoolTransactor) SetTokenSeller(opts *bind.TransactOpts, _seller common.Address) (*types.Transaction, error) {
	return _ZkBobPool.contract.Transact(opts, "setTokenSeller", _seller)
}

// SetTokenSeller is a paid mutator transaction binding the contract method 0x7a22393b.
//
// Solidity: function setTokenSeller(address _seller) returns()
func (_ZkBobPool *ZkBobPoolSession) SetTokenSeller(_seller common.Address) (*types.Transaction, error) {
	return _ZkBobPool.Contract.SetTokenSeller(&_ZkBobPool.TransactOpts, _seller)
}

// SetTokenSeller is a paid mutator transaction binding the contract method 0x7a22393b.
//
// Solidity: function setTokenSeller(address _seller) returns()
func (_ZkBobPool *ZkBobPoolTransactorSession) SetTokenSeller(_seller common.Address) (*types.Transaction, error) {
	return _ZkBobPool.Contract.SetTokenSeller(&_ZkBobPool.TransactOpts, _seller)
}

// SetUsersTier is a paid mutator transaction binding the contract method 0xe0ec0374.
//
// Solidity: function setUsersTier(uint8 _tier, address[] _users) returns()
func (_ZkBobPool *ZkBobPoolTransactor) SetUsersTier(opts *bind.TransactOpts, _tier uint8, _users []common.Address) (*types.Transaction, error) {
	return _ZkBobPool.contract.Transact(opts, "setUsersTier", _tier, _users)
}

// SetUsersTier is a paid mutator transaction binding the contract method 0xe0ec0374.
//
// Solidity: function setUsersTier(uint8 _tier, address[] _users) returns()
func (_ZkBobPool *ZkBobPoolSession) SetUsersTier(_tier uint8, _users []common.Address) (*types.Transaction, error) {
	return _ZkBobPool.Contract.SetUsersTier(&_ZkBobPool.TransactOpts, _tier, _users)
}

// SetUsersTier is a paid mutator transaction binding the contract method 0xe0ec0374.
//
// Solidity: function setUsersTier(uint8 _tier, address[] _users) returns()
func (_ZkBobPool *ZkBobPoolTransactorSession) SetUsersTier(_tier uint8, _users []common.Address) (*types.Transaction, error) {
	return _ZkBobPool.Contract.SetUsersTier(&_ZkBobPool.TransactOpts, _tier, _users)
}

// Transact is a paid mutator transaction binding the contract method 0xaf989083.
//
// Solidity: function transact() returns()
func (_ZkBobPool *ZkBobPoolTransactor) Transact(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ZkBobPool.contract.Transact(opts, "transact")
}

// Transact is a paid mutator transaction binding the contract method 0xaf989083.
//
// Solidity: function transact() returns()
func (_ZkBobPool *ZkBobPoolSession) Transact() (*types.Transaction, error) {
	return _ZkBobPool.Contract.Transact(&_ZkBobPool.TransactOpts)
}

// Transact is a paid mutator transaction binding the contract method 0xaf989083.
//
// Solidity: function transact() returns()
func (_ZkBobPool *ZkBobPoolTransactorSession) Transact() (*types.Transaction, error) {
	return _ZkBobPool.Contract.Transact(&_ZkBobPool.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ZkBobPool *ZkBobPoolTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _ZkBobPool.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ZkBobPool *ZkBobPoolSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ZkBobPool.Contract.TransferOwnership(&_ZkBobPool.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ZkBobPool *ZkBobPoolTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ZkBobPool.Contract.TransferOwnership(&_ZkBobPool.TransactOpts, newOwner)
}

// UploadMessages is a paid mutator transaction binding the contract method 0xc952fc3e.
//
// Solidity: function uploadMessages(uint256 index, bytes32[] hashes, bytes[] messages) returns()
func (_ZkBobPool *ZkBobPoolTransactor) UploadMessages(opts *bind.TransactOpts, index *big.Int, hashes [][32]byte, messages [][]byte) (*types.Transaction, error) {
	return _ZkBobPool.contract.Transact(opts, "uploadMessages", index, hashes, messages)
}

// UploadMessages is a paid mutator transaction binding the contract method 0xc952fc3e.
//
// Solidity: function uploadMessages(uint256 index, bytes32[] hashes, bytes[] messages) returns()
func (_ZkBobPool *ZkBobPoolSession) UploadMessages(index *big.Int, hashes [][32]byte, messages [][]byte) (*types.Transaction, error) {
	return _ZkBobPool.Contract.UploadMessages(&_ZkBobPool.TransactOpts, index, hashes, messages)
}

// UploadMessages is a paid mutator transaction binding the contract method 0xc952fc3e.
//
// Solidity: function uploadMessages(uint256 index, bytes32[] hashes, bytes[] messages) returns()
func (_ZkBobPool *ZkBobPoolTransactorSession) UploadMessages(index *big.Int, hashes [][32]byte, messages [][]byte) (*types.Transaction, error) {
	return _ZkBobPool.Contract.UploadMessages(&_ZkBobPool.TransactOpts, index, hashes, messages)
}

// UploadState is a paid mutator transaction binding the contract method 0xa45f1773.
//
// Solidity: function uploadState(bytes32[] keys, bytes32[] values) returns()
func (_ZkBobPool *ZkBobPoolTransactor) UploadState(opts *bind.TransactOpts, keys [][32]byte, values [][32]byte) (*types.Transaction, error) {
	return _ZkBobPool.contract.Transact(opts, "uploadState", keys, values)
}

// UploadState is a paid mutator transaction binding the contract method 0xa45f1773.
//
// Solidity: function uploadState(bytes32[] keys, bytes32[] values) returns()
func (_ZkBobPool *ZkBobPoolSession) UploadState(keys [][32]byte, values [][32]byte) (*types.Transaction, error) {
	return _ZkBobPool.Contract.UploadState(&_ZkBobPool.TransactOpts, keys, values)
}

// UploadState is a paid mutator transaction binding the contract method 0xa45f1773.
//
// Solidity: function uploadState(bytes32[] keys, bytes32[] values) returns()
func (_ZkBobPool *ZkBobPoolTransactorSession) UploadState(keys [][32]byte, values [][32]byte) (*types.Transaction, error) {
	return _ZkBobPool.Contract.UploadState(&_ZkBobPool.TransactOpts, keys, values)
}

// WithdrawFee is a paid mutator transaction binding the contract method 0xc879c6d8.
//
// Solidity: function withdrawFee(address _operator, address _to) returns()
func (_ZkBobPool *ZkBobPoolTransactor) WithdrawFee(opts *bind.TransactOpts, _operator common.Address, _to common.Address) (*types.Transaction, error) {
	return _ZkBobPool.contract.Transact(opts, "withdrawFee", _operator, _to)
}

// WithdrawFee is a paid mutator transaction binding the contract method 0xc879c6d8.
//
// Solidity: function withdrawFee(address _operator, address _to) returns()
func (_ZkBobPool *ZkBobPoolSession) WithdrawFee(_operator common.Address, _to common.Address) (*types.Transaction, error) {
	return _ZkBobPool.Contract.WithdrawFee(&_ZkBobPool.TransactOpts, _operator, _to)
}

// WithdrawFee is a paid mutator transaction binding the contract method 0xc879c6d8.
//
// Solidity: function withdrawFee(address _operator, address _to) returns()
func (_ZkBobPool *ZkBobPoolTransactorSession) WithdrawFee(_operator common.Address, _to common.Address) (*types.Transaction, error) {
	return _ZkBobPool.Contract.WithdrawFee(&_ZkBobPool.TransactOpts, _operator, _to)
}

// ZkBobPoolMessageIterator is returned from FilterMessage and is used to iterate over the raw logs and unpacked data for Message events raised by the ZkBobPool contract.
type ZkBobPoolMessageIterator struct {
	Event *ZkBobPoolMessage // Event containing the contract specifics and raw log

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
func (it *ZkBobPoolMessageIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ZkBobPoolMessage)
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
		it.Event = new(ZkBobPoolMessage)
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
func (it *ZkBobPoolMessageIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ZkBobPoolMessageIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ZkBobPoolMessage represents a Message event raised by the ZkBobPool contract.
type ZkBobPoolMessage struct {
	Index   *big.Int
	Hash    [32]byte
	Message []byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterMessage is a free log retrieval operation binding the contract event 0x7d39f8a6bc8929456fba511441be7361aa014ac6f8e21b99990ce9e1c7373536.
//
// Solidity: event Message(uint256 indexed index, bytes32 indexed hash, bytes message)
func (_ZkBobPool *ZkBobPoolFilterer) FilterMessage(opts *bind.FilterOpts, index []*big.Int, hash [][32]byte) (*ZkBobPoolMessageIterator, error) {

	var indexRule []interface{}
	for _, indexItem := range index {
		indexRule = append(indexRule, indexItem)
	}
	var hashRule []interface{}
	for _, hashItem := range hash {
		hashRule = append(hashRule, hashItem)
	}

	logs, sub, err := _ZkBobPool.contract.FilterLogs(opts, "Message", indexRule, hashRule)
	if err != nil {
		return nil, err
	}
	return &ZkBobPoolMessageIterator{contract: _ZkBobPool.contract, event: "Message", logs: logs, sub: sub}, nil
}

// WatchMessage is a free log subscription operation binding the contract event 0x7d39f8a6bc8929456fba511441be7361aa014ac6f8e21b99990ce9e1c7373536.
//
// Solidity: event Message(uint256 indexed index, bytes32 indexed hash, bytes message)
func (_ZkBobPool *ZkBobPoolFilterer) WatchMessage(opts *bind.WatchOpts, sink chan<- *ZkBobPoolMessage, index []*big.Int, hash [][32]byte) (event.Subscription, error) {

	var indexRule []interface{}
	for _, indexItem := range index {
		indexRule = append(indexRule, indexItem)
	}
	var hashRule []interface{}
	for _, hashItem := range hash {
		hashRule = append(hashRule, hashItem)
	}

	logs, sub, err := _ZkBobPool.contract.WatchLogs(opts, "Message", indexRule, hashRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ZkBobPoolMessage)
				if err := _ZkBobPool.contract.UnpackLog(event, "Message", log); err != nil {
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

// ParseMessage is a log parse operation binding the contract event 0x7d39f8a6bc8929456fba511441be7361aa014ac6f8e21b99990ce9e1c7373536.
//
// Solidity: event Message(uint256 indexed index, bytes32 indexed hash, bytes message)
func (_ZkBobPool *ZkBobPoolFilterer) ParseMessage(log types.Log) (*ZkBobPoolMessage, error) {
	event := new(ZkBobPoolMessage)
	if err := _ZkBobPool.contract.UnpackLog(event, "Message", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ZkBobPoolOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the ZkBobPool contract.
type ZkBobPoolOwnershipTransferredIterator struct {
	Event *ZkBobPoolOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *ZkBobPoolOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ZkBobPoolOwnershipTransferred)
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
		it.Event = new(ZkBobPoolOwnershipTransferred)
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
func (it *ZkBobPoolOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ZkBobPoolOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ZkBobPoolOwnershipTransferred represents a OwnershipTransferred event raised by the ZkBobPool contract.
type ZkBobPoolOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ZkBobPool *ZkBobPoolFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*ZkBobPoolOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ZkBobPool.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &ZkBobPoolOwnershipTransferredIterator{contract: _ZkBobPool.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ZkBobPool *ZkBobPoolFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *ZkBobPoolOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ZkBobPool.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ZkBobPoolOwnershipTransferred)
				if err := _ZkBobPool.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_ZkBobPool *ZkBobPoolFilterer) ParseOwnershipTransferred(log types.Log) (*ZkBobPoolOwnershipTransferred, error) {
	event := new(ZkBobPoolOwnershipTransferred)
	if err := _ZkBobPool.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ZkBobPoolUpdateKYCProvidersManagerIterator is returned from FilterUpdateKYCProvidersManager and is used to iterate over the raw logs and unpacked data for UpdateKYCProvidersManager events raised by the ZkBobPool contract.
type ZkBobPoolUpdateKYCProvidersManagerIterator struct {
	Event *ZkBobPoolUpdateKYCProvidersManager // Event containing the contract specifics and raw log

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
func (it *ZkBobPoolUpdateKYCProvidersManagerIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ZkBobPoolUpdateKYCProvidersManager)
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
		it.Event = new(ZkBobPoolUpdateKYCProvidersManager)
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
func (it *ZkBobPoolUpdateKYCProvidersManagerIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ZkBobPoolUpdateKYCProvidersManagerIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ZkBobPoolUpdateKYCProvidersManager represents a UpdateKYCProvidersManager event raised by the ZkBobPool contract.
type ZkBobPoolUpdateKYCProvidersManager struct {
	Manager common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUpdateKYCProvidersManager is a free log retrieval operation binding the contract event 0xcfca215f2134266880a5d2c68d2f52493a9d57fe6dd1245086a201e78871348e.
//
// Solidity: event UpdateKYCProvidersManager(address manager)
func (_ZkBobPool *ZkBobPoolFilterer) FilterUpdateKYCProvidersManager(opts *bind.FilterOpts) (*ZkBobPoolUpdateKYCProvidersManagerIterator, error) {

	logs, sub, err := _ZkBobPool.contract.FilterLogs(opts, "UpdateKYCProvidersManager")
	if err != nil {
		return nil, err
	}
	return &ZkBobPoolUpdateKYCProvidersManagerIterator{contract: _ZkBobPool.contract, event: "UpdateKYCProvidersManager", logs: logs, sub: sub}, nil
}

// WatchUpdateKYCProvidersManager is a free log subscription operation binding the contract event 0xcfca215f2134266880a5d2c68d2f52493a9d57fe6dd1245086a201e78871348e.
//
// Solidity: event UpdateKYCProvidersManager(address manager)
func (_ZkBobPool *ZkBobPoolFilterer) WatchUpdateKYCProvidersManager(opts *bind.WatchOpts, sink chan<- *ZkBobPoolUpdateKYCProvidersManager) (event.Subscription, error) {

	logs, sub, err := _ZkBobPool.contract.WatchLogs(opts, "UpdateKYCProvidersManager")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ZkBobPoolUpdateKYCProvidersManager)
				if err := _ZkBobPool.contract.UnpackLog(event, "UpdateKYCProvidersManager", log); err != nil {
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

// ParseUpdateKYCProvidersManager is a log parse operation binding the contract event 0xcfca215f2134266880a5d2c68d2f52493a9d57fe6dd1245086a201e78871348e.
//
// Solidity: event UpdateKYCProvidersManager(address manager)
func (_ZkBobPool *ZkBobPoolFilterer) ParseUpdateKYCProvidersManager(log types.Log) (*ZkBobPoolUpdateKYCProvidersManager, error) {
	event := new(ZkBobPoolUpdateKYCProvidersManager)
	if err := _ZkBobPool.contract.UnpackLog(event, "UpdateKYCProvidersManager", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ZkBobPoolUpdateLimitsIterator is returned from FilterUpdateLimits and is used to iterate over the raw logs and unpacked data for UpdateLimits events raised by the ZkBobPool contract.
type ZkBobPoolUpdateLimitsIterator struct {
	Event *ZkBobPoolUpdateLimits // Event containing the contract specifics and raw log

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
func (it *ZkBobPoolUpdateLimitsIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ZkBobPoolUpdateLimits)
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
		it.Event = new(ZkBobPoolUpdateLimits)
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
func (it *ZkBobPoolUpdateLimitsIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ZkBobPoolUpdateLimitsIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ZkBobPoolUpdateLimits represents a UpdateLimits event raised by the ZkBobPool contract.
type ZkBobPoolUpdateLimits struct {
	Tier   uint8
	Limits ZkBobAccountingTierLimits
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterUpdateLimits is a free log retrieval operation binding the contract event 0x3cb26612e7105331adad836a65ae9b7f1d30a9e469ec70510a7c7ea36b0185ed.
//
// Solidity: event UpdateLimits(uint8 indexed tier, (uint56,uint32,uint32,uint32,uint32,uint32,uint32) limits)
func (_ZkBobPool *ZkBobPoolFilterer) FilterUpdateLimits(opts *bind.FilterOpts, tier []uint8) (*ZkBobPoolUpdateLimitsIterator, error) {

	var tierRule []interface{}
	for _, tierItem := range tier {
		tierRule = append(tierRule, tierItem)
	}

	logs, sub, err := _ZkBobPool.contract.FilterLogs(opts, "UpdateLimits", tierRule)
	if err != nil {
		return nil, err
	}
	return &ZkBobPoolUpdateLimitsIterator{contract: _ZkBobPool.contract, event: "UpdateLimits", logs: logs, sub: sub}, nil
}

// WatchUpdateLimits is a free log subscription operation binding the contract event 0x3cb26612e7105331adad836a65ae9b7f1d30a9e469ec70510a7c7ea36b0185ed.
//
// Solidity: event UpdateLimits(uint8 indexed tier, (uint56,uint32,uint32,uint32,uint32,uint32,uint32) limits)
func (_ZkBobPool *ZkBobPoolFilterer) WatchUpdateLimits(opts *bind.WatchOpts, sink chan<- *ZkBobPoolUpdateLimits, tier []uint8) (event.Subscription, error) {

	var tierRule []interface{}
	for _, tierItem := range tier {
		tierRule = append(tierRule, tierItem)
	}

	logs, sub, err := _ZkBobPool.contract.WatchLogs(opts, "UpdateLimits", tierRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ZkBobPoolUpdateLimits)
				if err := _ZkBobPool.contract.UnpackLog(event, "UpdateLimits", log); err != nil {
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

// ParseUpdateLimits is a log parse operation binding the contract event 0x3cb26612e7105331adad836a65ae9b7f1d30a9e469ec70510a7c7ea36b0185ed.
//
// Solidity: event UpdateLimits(uint8 indexed tier, (uint56,uint32,uint32,uint32,uint32,uint32,uint32) limits)
func (_ZkBobPool *ZkBobPoolFilterer) ParseUpdateLimits(log types.Log) (*ZkBobPoolUpdateLimits, error) {
	event := new(ZkBobPoolUpdateLimits)
	if err := _ZkBobPool.contract.UnpackLog(event, "UpdateLimits", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ZkBobPoolUpdateOperatorManagerIterator is returned from FilterUpdateOperatorManager and is used to iterate over the raw logs and unpacked data for UpdateOperatorManager events raised by the ZkBobPool contract.
type ZkBobPoolUpdateOperatorManagerIterator struct {
	Event *ZkBobPoolUpdateOperatorManager // Event containing the contract specifics and raw log

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
func (it *ZkBobPoolUpdateOperatorManagerIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ZkBobPoolUpdateOperatorManager)
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
		it.Event = new(ZkBobPoolUpdateOperatorManager)
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
func (it *ZkBobPoolUpdateOperatorManagerIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ZkBobPoolUpdateOperatorManagerIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ZkBobPoolUpdateOperatorManager represents a UpdateOperatorManager event raised by the ZkBobPool contract.
type ZkBobPoolUpdateOperatorManager struct {
	Manager common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUpdateOperatorManager is a free log retrieval operation binding the contract event 0x267052ecaebdd552dc1b20904f59d83d51ae7add7514165322a7da9ef6cf543b.
//
// Solidity: event UpdateOperatorManager(address manager)
func (_ZkBobPool *ZkBobPoolFilterer) FilterUpdateOperatorManager(opts *bind.FilterOpts) (*ZkBobPoolUpdateOperatorManagerIterator, error) {

	logs, sub, err := _ZkBobPool.contract.FilterLogs(opts, "UpdateOperatorManager")
	if err != nil {
		return nil, err
	}
	return &ZkBobPoolUpdateOperatorManagerIterator{contract: _ZkBobPool.contract, event: "UpdateOperatorManager", logs: logs, sub: sub}, nil
}

// WatchUpdateOperatorManager is a free log subscription operation binding the contract event 0x267052ecaebdd552dc1b20904f59d83d51ae7add7514165322a7da9ef6cf543b.
//
// Solidity: event UpdateOperatorManager(address manager)
func (_ZkBobPool *ZkBobPoolFilterer) WatchUpdateOperatorManager(opts *bind.WatchOpts, sink chan<- *ZkBobPoolUpdateOperatorManager) (event.Subscription, error) {

	logs, sub, err := _ZkBobPool.contract.WatchLogs(opts, "UpdateOperatorManager")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ZkBobPoolUpdateOperatorManager)
				if err := _ZkBobPool.contract.UnpackLog(event, "UpdateOperatorManager", log); err != nil {
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
func (_ZkBobPool *ZkBobPoolFilterer) ParseUpdateOperatorManager(log types.Log) (*ZkBobPoolUpdateOperatorManager, error) {
	event := new(ZkBobPoolUpdateOperatorManager)
	if err := _ZkBobPool.contract.UnpackLog(event, "UpdateOperatorManager", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ZkBobPoolUpdateTierIterator is returned from FilterUpdateTier and is used to iterate over the raw logs and unpacked data for UpdateTier events raised by the ZkBobPool contract.
type ZkBobPoolUpdateTierIterator struct {
	Event *ZkBobPoolUpdateTier // Event containing the contract specifics and raw log

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
func (it *ZkBobPoolUpdateTierIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ZkBobPoolUpdateTier)
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
		it.Event = new(ZkBobPoolUpdateTier)
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
func (it *ZkBobPoolUpdateTierIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ZkBobPoolUpdateTierIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ZkBobPoolUpdateTier represents a UpdateTier event raised by the ZkBobPool contract.
type ZkBobPoolUpdateTier struct {
	User common.Address
	Tier uint8
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterUpdateTier is a free log retrieval operation binding the contract event 0x1283ebeb150dffd4da976f64c81e074fd4dc895cb64995dc46f13c9fd96a9551.
//
// Solidity: event UpdateTier(address user, uint8 tier)
func (_ZkBobPool *ZkBobPoolFilterer) FilterUpdateTier(opts *bind.FilterOpts) (*ZkBobPoolUpdateTierIterator, error) {

	logs, sub, err := _ZkBobPool.contract.FilterLogs(opts, "UpdateTier")
	if err != nil {
		return nil, err
	}
	return &ZkBobPoolUpdateTierIterator{contract: _ZkBobPool.contract, event: "UpdateTier", logs: logs, sub: sub}, nil
}

// WatchUpdateTier is a free log subscription operation binding the contract event 0x1283ebeb150dffd4da976f64c81e074fd4dc895cb64995dc46f13c9fd96a9551.
//
// Solidity: event UpdateTier(address user, uint8 tier)
func (_ZkBobPool *ZkBobPoolFilterer) WatchUpdateTier(opts *bind.WatchOpts, sink chan<- *ZkBobPoolUpdateTier) (event.Subscription, error) {

	logs, sub, err := _ZkBobPool.contract.WatchLogs(opts, "UpdateTier")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ZkBobPoolUpdateTier)
				if err := _ZkBobPool.contract.UnpackLog(event, "UpdateTier", log); err != nil {
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

// ParseUpdateTier is a log parse operation binding the contract event 0x1283ebeb150dffd4da976f64c81e074fd4dc895cb64995dc46f13c9fd96a9551.
//
// Solidity: event UpdateTier(address user, uint8 tier)
func (_ZkBobPool *ZkBobPoolFilterer) ParseUpdateTier(log types.Log) (*ZkBobPoolUpdateTier, error) {
	event := new(ZkBobPoolUpdateTier)
	if err := _ZkBobPool.contract.UnpackLog(event, "UpdateTier", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ZkBobPoolUpdateTokenSellerIterator is returned from FilterUpdateTokenSeller and is used to iterate over the raw logs and unpacked data for UpdateTokenSeller events raised by the ZkBobPool contract.
type ZkBobPoolUpdateTokenSellerIterator struct {
	Event *ZkBobPoolUpdateTokenSeller // Event containing the contract specifics and raw log

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
func (it *ZkBobPoolUpdateTokenSellerIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ZkBobPoolUpdateTokenSeller)
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
		it.Event = new(ZkBobPoolUpdateTokenSeller)
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
func (it *ZkBobPoolUpdateTokenSellerIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ZkBobPoolUpdateTokenSellerIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ZkBobPoolUpdateTokenSeller represents a UpdateTokenSeller event raised by the ZkBobPool contract.
type ZkBobPoolUpdateTokenSeller struct {
	Seller common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterUpdateTokenSeller is a free log retrieval operation binding the contract event 0xdf71641930ea322cb32f687f4d292a0af694c81216254f204c930092593d8282.
//
// Solidity: event UpdateTokenSeller(address seller)
func (_ZkBobPool *ZkBobPoolFilterer) FilterUpdateTokenSeller(opts *bind.FilterOpts) (*ZkBobPoolUpdateTokenSellerIterator, error) {

	logs, sub, err := _ZkBobPool.contract.FilterLogs(opts, "UpdateTokenSeller")
	if err != nil {
		return nil, err
	}
	return &ZkBobPoolUpdateTokenSellerIterator{contract: _ZkBobPool.contract, event: "UpdateTokenSeller", logs: logs, sub: sub}, nil
}

// WatchUpdateTokenSeller is a free log subscription operation binding the contract event 0xdf71641930ea322cb32f687f4d292a0af694c81216254f204c930092593d8282.
//
// Solidity: event UpdateTokenSeller(address seller)
func (_ZkBobPool *ZkBobPoolFilterer) WatchUpdateTokenSeller(opts *bind.WatchOpts, sink chan<- *ZkBobPoolUpdateTokenSeller) (event.Subscription, error) {

	logs, sub, err := _ZkBobPool.contract.WatchLogs(opts, "UpdateTokenSeller")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ZkBobPoolUpdateTokenSeller)
				if err := _ZkBobPool.contract.UnpackLog(event, "UpdateTokenSeller", log); err != nil {
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

// ParseUpdateTokenSeller is a log parse operation binding the contract event 0xdf71641930ea322cb32f687f4d292a0af694c81216254f204c930092593d8282.
//
// Solidity: event UpdateTokenSeller(address seller)
func (_ZkBobPool *ZkBobPoolFilterer) ParseUpdateTokenSeller(log types.Log) (*ZkBobPoolUpdateTokenSeller, error) {
	event := new(ZkBobPoolUpdateTokenSeller)
	if err := _ZkBobPool.contract.UnpackLog(event, "UpdateTokenSeller", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ZkBobPoolWithdrawFeeIterator is returned from FilterWithdrawFee and is used to iterate over the raw logs and unpacked data for WithdrawFee events raised by the ZkBobPool contract.
type ZkBobPoolWithdrawFeeIterator struct {
	Event *ZkBobPoolWithdrawFee // Event containing the contract specifics and raw log

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
func (it *ZkBobPoolWithdrawFeeIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ZkBobPoolWithdrawFee)
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
		it.Event = new(ZkBobPoolWithdrawFee)
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
func (it *ZkBobPoolWithdrawFeeIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ZkBobPoolWithdrawFeeIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ZkBobPoolWithdrawFee represents a WithdrawFee event raised by the ZkBobPool contract.
type ZkBobPoolWithdrawFee struct {
	Operator common.Address
	Fee      *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterWithdrawFee is a free log retrieval operation binding the contract event 0x66bf9186b00db666fc37aaffbb95a050c66e599e000c785c1dff0467d868f1b1.
//
// Solidity: event WithdrawFee(address indexed operator, uint256 fee)
func (_ZkBobPool *ZkBobPoolFilterer) FilterWithdrawFee(opts *bind.FilterOpts, operator []common.Address) (*ZkBobPoolWithdrawFeeIterator, error) {

	var operatorRule []interface{}
	for _, operatorItem := range operator {
		operatorRule = append(operatorRule, operatorItem)
	}

	logs, sub, err := _ZkBobPool.contract.FilterLogs(opts, "WithdrawFee", operatorRule)
	if err != nil {
		return nil, err
	}
	return &ZkBobPoolWithdrawFeeIterator{contract: _ZkBobPool.contract, event: "WithdrawFee", logs: logs, sub: sub}, nil
}

// WatchWithdrawFee is a free log subscription operation binding the contract event 0x66bf9186b00db666fc37aaffbb95a050c66e599e000c785c1dff0467d868f1b1.
//
// Solidity: event WithdrawFee(address indexed operator, uint256 fee)
func (_ZkBobPool *ZkBobPoolFilterer) WatchWithdrawFee(opts *bind.WatchOpts, sink chan<- *ZkBobPoolWithdrawFee, operator []common.Address) (event.Subscription, error) {

	var operatorRule []interface{}
	for _, operatorItem := range operator {
		operatorRule = append(operatorRule, operatorItem)
	}

	logs, sub, err := _ZkBobPool.contract.WatchLogs(opts, "WithdrawFee", operatorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ZkBobPoolWithdrawFee)
				if err := _ZkBobPool.contract.UnpackLog(event, "WithdrawFee", log); err != nil {
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

// ParseWithdrawFee is a log parse operation binding the contract event 0x66bf9186b00db666fc37aaffbb95a050c66e599e000c785c1dff0467d868f1b1.
//
// Solidity: event WithdrawFee(address indexed operator, uint256 fee)
func (_ZkBobPool *ZkBobPoolFilterer) ParseWithdrawFee(log types.Log) (*ZkBobPoolWithdrawFee, error) {
	event := new(ZkBobPoolWithdrawFee)
	if err := _ZkBobPool.contract.UnpackLog(event, "WithdrawFee", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
