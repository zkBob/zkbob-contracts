package main

import (
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"flag"
	"log"
	"math/big"
	"os"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"

	"poolexport/gen"
)

var (
	rpcURL                = flag.String("rpcUrl", "", "")
	pkHex                 = flag.String("pkHex", "", "")
	poolAddress           = flag.String("poolAddress", "0xa5D6fDc51094dEfCA44C1CB4d58903eDc1A1AcF4", "")
	path                  = flag.String("path", "./exported.json", "")
	storageBatchSize      = flag.Uint64("storageBatchSize", 200, "")
	eventsBatchSize       = flag.Uint64("eventsBatchSize", 100, "")
	eventsMaxCalldataSize = flag.Uint64("eventsMaxCalldataSize", 20000, "")
)

type ZkBobTransaction struct {
	Index     uint64
	Hash      common.Hash
	Message   hexutil.Bytes
	TxHash    common.Hash
	User      *common.Address
	Nullifier *common.Hash
	OutCommit common.Hash
	Operator  common.Address
}

type ExportResult struct {
	LastIndex   uint64
	StorageHash common.Hash
	Storage     map[common.Hash]common.Hash
	History     []ZkBobTransaction
}

func main() {
	flag.Parse()

	ctx := context.Background()
	res := &ExportResult{}

	client, err := ethclient.Dial(*rpcURL)
	if err != nil {
		log.Fatal(err)
	}

	file, err := os.OpenFile(*path, os.O_RDONLY, os.ModePerm)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()
	err = json.NewDecoder(file).Decode(res)
	if err != nil {
		log.Fatal(err)
	}

	abi, err := gen.ZkBobPoolMetaData.GetAbi()
	if err != nil {
		log.Fatal(err)
	}

	var calldatas []hexutil.Bytes

	for _, k := range []common.Hash{
		common.HexToHash("0x0000000000000000000000000000000000000000000000000000000000000000"), // owner
		common.HexToHash("0x0000000000000000000000000000000000000000000000000000000000000006"), // operatorManager
		common.HexToHash("0x0000000000000000000000000000000000000000000000000000000000000009"), // all_messages_hash
		common.HexToHash("0x000000000000000000000000000000000000000000000000000000000000000b"), // tokenSeller
		common.HexToHash("0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"), // EIP1967 implementation
		common.HexToHash("0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"), // EIP1967 admin
		common.HexToHash("0x06c991646992b7f0f3fd0c832eac3f519e26682bcb82fbbcfd1ff8013d876f64"), // KYC manager
		common.HexToHash("0x5eff886ea0ce6ca488a3d6e336d6c0f75f46d19b42c06ce5ee98e42c96d256c7"), // roots[0]
		common.HexToHash("0x3617319a054d772f909f7c479a2cebe5066e836a939412e32403c99029b92eff"), // tiers[0]
	} {
		delete(res.Storage, k)
	}

	var keys, values []common.Hash
	for k, v := range res.Storage {
		keys = append(keys, k)
		values = append(values, v)

		if len(keys) == int(*storageBatchSize) {
			cd, err := abi.Pack("uploadState", keys, values)
			if err != nil {
				log.Fatal(err)
			}
			calldatas = append(calldatas, cd)
			keys = keys[:0]
			values = values[:0]
		}
	}

	if len(keys) > 0 {
		cd, err := abi.Pack("uploadState", keys, values)
		if err != nil {
			log.Fatal(err)
		}
		calldatas = append(calldatas, cd)
	}

	var outCommits []common.Hash
	var messages [][]byte
	calldataSize := 0
	index := 0
	for i := 0; i < len(res.History); i++ {
		outCommits = append(outCommits, res.History[i].OutCommit)
		messages = append(messages, res.History[i].Message)
		if calldataSize == 0 {
			index = int(res.History[i].Index)
		}
		calldataSize += len(res.History[i].Message)

		if i == len(res.History)-1 || len(outCommits) >= int(*eventsBatchSize) || calldataSize+len(res.History[i+1].Message) > int(*eventsMaxCalldataSize) {
			cd, err := abi.Pack("uploadMessages", big.NewInt(int64(index)), outCommits, messages)
			if err != nil {
				log.Fatal(err)
			}
			calldatas = append(calldatas, cd)
			outCommits = outCommits[:0]
			messages = messages[:0]
			calldataSize = 0
			index = 0
		}
	}

	pk, err := crypto.HexToECDSA(*pkHex)
	if err != nil {
		log.Fatal(err)
	}
	from := crypto.PubkeyToAddress(*pk.Public().(*ecdsa.PublicKey))
	nonce, err := client.PendingNonceAt(ctx, from)
	if err != nil {
		log.Fatal(err)
	}

	chainID, err := client.ChainID(ctx)
	if err != nil {
		log.Fatal(err)
	}
	signer := types.NewLondonSigner(chainID)

	for i, cd := range calldatas {
		time.Sleep(2 * time.Second)
		to := common.HexToAddress(*poolAddress)
		gas, err := client.EstimateGas(ctx, ethereum.CallMsg{
			From: from,
			To:   &to,
			Data: cd,
		})
		if err != nil {
			log.Fatal(err)
		}
		tx := types.NewTx(&types.LegacyTx{
			Nonce:    nonce + uint64(i),
			GasPrice: big.NewInt(1_000_000),
			Gas:      gas * 130 / 100,
			To:       &to,
			Data:     cd,
		})
		signedTx, err := types.SignTx(tx, signer, pk)
		if err != nil {
			log.Fatal(err)
		}
		log.Printf("Sent %d/%d tx %s with gas of %d", i+1, len(calldatas), tx.Hash(), tx.Gas())
		err = client.SendTransaction(ctx, signedTx)
		if err != nil {
			log.Fatal(err)
		}
	}
}
