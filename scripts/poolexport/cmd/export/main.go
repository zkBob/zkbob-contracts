package main

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"math/big"
	"os"
	"sync"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/common/math"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/ethclient/gethclient"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/ethereum/go-ethereum/trie"
	"golang.org/x/sync/semaphore"

	"poolexport/gen"
)

var TransferTopic = crypto.Keccak256Hash([]byte("Transfer(address,address,uint256)"))

var (
	rpcURL      = flag.String("rpcUrl", "https://polygon-mainnet.g.alchemy.com/v2/gdDTzlWG-NCJyOtC-JzZQBJzKrivCZBV", "")
	bobAddress  = flag.String("bobAddress", "0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B", "")
	poolAddress = flag.String("poolAddress", "0x72e6B59D4a90ab232e55D4BB7ed2dD17494D62fB", "")
	startBlock  = flag.Uint64("startBlock", 32845526, "")
	endBlock    = flag.Uint64("endBlock", 0, "")
	blockBatch  = flag.Uint64("blockBatch", 30000, "")
	threads     = flag.Int64("threads", 10, "")
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

	client, gethClient, err := dial(*rpcURL)
	if err != nil {
		log.Fatal(err)
	}

	zkBob, err := gen.NewZkBobPool(common.HexToAddress(*poolAddress), client)
	if err != nil {
		log.Fatal(err)
	}

	latest := *endBlock
	if latest == 0 {
		latest, err = client.BlockNumber(ctx)
		if err != nil {
			log.Fatalf("can't fetch latest block number: %s", err)
		}
	}

	lastIndex, messages, err := fetchMessages(ctx, zkBob, latest)
	if err != nil {
		log.Fatal(err)
	}

	directDepositUsers, err := fetchDirectDepositUsers(ctx, client, zkBob, latest)
	if err != nil {
		log.Fatal(err)
	}

	tierUsers, err := fetchTierUpdates(ctx, zkBob, latest)
	if err != nil {
		log.Fatal(err)
	}

	res.LastIndex = lastIndex

	proof, err := gethClient.GetProof(ctx, common.HexToAddress(*poolAddress), nil, big.NewInt(int64(latest)))
	if err != nil {
		log.Fatal(err)
	}
	res.StorageHash = proof.StorageHash

	res.History, err = buildTxInfos(ctx, client, messages)
	if err != nil {
		log.Fatal(err)
	}

	res.Storage, err = fetchStorage(ctx, latest, client, res.History, append(directDepositUsers, tierUsers...))
	if err != nil {
		log.Fatal(err)
	}

	storageRoot := computeStorageRoot(res.Storage)
	if storageRoot != res.StorageHash {
		log.Printf("storage roots do not match %s!=%s\n", storageRoot, res.StorageHash)
	}

	file, err := os.OpenFile("exported.json", os.O_TRUNC|os.O_RDWR|os.O_CREATE, os.ModePerm)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()
	err = json.NewEncoder(file).Encode(res)
	if err != nil {
		log.Fatal(err)
	}
}

func dial(rpcURL string) (*ethclient.Client, *gethclient.Client, error) {
	rpcClient, err := rpc.Dial(rpcURL)
	if err != nil {
		return nil, nil, fmt.Errorf("can't dial rpc: %w", err)
	}
	return ethclient.NewClient(rpcClient), gethclient.New(rpcClient), nil
}

func fetchMessages(ctx context.Context, zkBob *gen.ZkBobPool, block uint64) (uint64, []*gen.ZkBobPoolMessage, error) {
	var messages []*gen.ZkBobPoolMessage

	nextIndex, err := zkBob.PoolIndex(&bind.CallOpts{
		BlockNumber: big.NewInt(int64(block)),
		Context:     ctx,
	})
	if err != nil {
		return 0, nil, fmt.Errorf("can't fetch events: %w", err)
	}
	count := int(nextIndex.Uint64() / 128)

	fromBlock, toBlock := *startBlock, *startBlock+*blockBatch-1

	for fromBlock < block {
		if toBlock > block {
			toBlock = block
		}
		log.Printf("Fetching Message logs from %d to %d\n", fromBlock, toBlock)
		iter, err := zkBob.FilterMessage(&bind.FilterOpts{
			Start:   fromBlock,
			End:     &toBlock,
			Context: ctx,
		}, nil, nil)
		if err != nil {
			return 0, nil, fmt.Errorf("can't fetch events: %w", err)
		}

		for iter.Next() {
			messages = append(messages, iter.Event)
		}

		log.Printf("Fetched %d/%d Message events\n", len(messages), count)

		fromBlock += *blockBatch
		toBlock += *blockBatch
	}

	if len(messages) != count {
		return 0, nil, fmt.Errorf("mismatched number of events")
	}

	return nextIndex.Uint64() - 128, messages, nil
}

func fetchDirectDepositUsers(ctx context.Context, client *ethclient.Client, zkBob *gen.ZkBobPool, block uint64) ([]common.Address, error) {
	var users []common.Address

	queueAddress, err := zkBob.DirectDepositQueue(&bind.CallOpts{
		BlockNumber: big.NewInt(int64(block)),
		Context:     ctx,
	})
	if err != nil {
		log.Printf("can't fetch queue address: %s", err)
		return nil, nil
	}

	queue, err := gen.NewZkBobDirectDepositQueue(queueAddress, client)
	if err != nil {
		return nil, fmt.Errorf("can't create dd queue: %w", err)
	}

	nonce, err := queue.DirectDepositNonce(&bind.CallOpts{
		BlockNumber: big.NewInt(int64(block)),
		Context:     ctx,
	})
	if err != nil {
		return nil, fmt.Errorf("can't fetch dd nonce: %w", err)
	}

	fromBlock, toBlock := *startBlock, *startBlock+*blockBatch-1

	for fromBlock < block {
		if toBlock > block {
			toBlock = block
		}
		log.Printf("Fetching SubmitDirectDeposit logs from %d to %d\n", fromBlock, toBlock)
		iter, err := queue.FilterSubmitDirectDeposit(&bind.FilterOpts{
			Start:   fromBlock,
			End:     &toBlock,
			Context: ctx,
		}, nil, nil)
		if err != nil {
			return nil, fmt.Errorf("can't fetch direct deposits: %w", err)
		}

		for iter.Next() {
			users = append(users, iter.Event.Sender)
		}

		log.Printf("Fetched %d/%d SubmitDirectDeposit events\n", len(users), nonce)

		fromBlock += *blockBatch
		toBlock += *blockBatch
	}

	if len(users) != int(nonce) {
		return nil, fmt.Errorf("mismatched number of events")
	}

	return users, nil
}

func fetchTierUpdates(ctx context.Context, zkBob *gen.ZkBobPool, block uint64) ([]common.Address, error) {
	var users []common.Address

	fromBlock, toBlock := *startBlock, *startBlock+*blockBatch-1

	for fromBlock < block {
		if toBlock > block {
			toBlock = block
		}
		log.Printf("Fetching UpdateTier logs from %d to %d\n", fromBlock, toBlock)
		iter, err := zkBob.FilterUpdateTier(&bind.FilterOpts{
			Start:   fromBlock,
			End:     &toBlock,
			Context: ctx,
		})
		if err != nil {
			return nil, fmt.Errorf("can't fetch tier updates: %w", err)
		}

		for iter.Next() {
			users = append(users, iter.Event.User)
		}

		log.Printf("Fetched %d UpdateTier events\n", len(users))

		fromBlock += *blockBatch
		toBlock += *blockBatch
	}

	return users, nil
}

func buildTxInfos(ctx context.Context, client *ethclient.Client, messages []*gen.ZkBobPoolMessage) ([]ZkBobTransaction, error) {
	chainID, err := client.ChainID(ctx)
	if err != nil {
		return nil, fmt.Errorf("can't fetch chainID: %w", err)
	}
	signer := types.NewLondonSigner(chainID)

	sem := semaphore.NewWeighted(*threads)
	res := make([]ZkBobTransaction, len(messages))
	for i, m := range messages {
		res[i] = ZkBobTransaction{
			Index:   m.Index.Uint64(),
			Hash:    common.BytesToHash(m.Hash[:]),
			Message: m.Message,
			TxHash:  m.Raw.TxHash,
		}

		err = sem.Acquire(ctx, 1)
		if err != nil {
			log.Fatalf("can't acquire: %w", err)
		}
		go func(i int, m *gen.ZkBobPoolMessage) {
			for {
				if i == 0 || i%100 == 99 {
					log.Printf("Fetching tx %d/%d\n", i+1, len(messages))
				}

				tx, _, err := client.TransactionByHash(ctx, m.Raw.TxHash)
				if err != nil {
					log.Printf("can't fetch tx by hash %s: %s\n", m.Raw.TxHash, err)
					continue
				}

				res[i].Operator, err = signer.Sender(tx)
				if err != nil {
					log.Fatalf("can't get tx signer: %s\n", err)
				}

				data := tx.Data()
				if bytes.HasPrefix(data, common.FromHex("0xaf989083")) {
					nullifier := common.BytesToHash(data[4:36])
					res[i].Nullifier = &nullifier
					res[i].OutCommit = common.BytesToHash(data[36:68])

					txType := binary.BigEndian.Uint16(data[640:642])

					if txType == 0 || txType == 2 || txType == 3 {
						receipt, err := client.TransactionReceipt(ctx, m.Raw.TxHash)
						if err != nil {
							log.Printf("can't fetch tx receipt by hash %s: %s\n", m.Raw.TxHash, err)
							continue
						}
						for _, l := range receipt.Logs {
							if l.Address == common.HexToAddress(*bobAddress) && len(l.Topics) == 3 && l.Topics[0] == TransferTopic {
								if ((txType == 0 || txType == 3) && l.Topics[2] == common.HexToAddress(*poolAddress).Hash()) || (txType == 2 && l.Topics[1] == common.HexToAddress(*poolAddress).Hash()) {
									addr := common.BytesToAddress(l.Topics[1].Bytes())
									res[i].User = &addr
									break
								}
							}
						}
						if res[i].User == nil {
							log.Fatalf("can't fetch user address for tx %s", m.Raw.TxHash)
						}
					}
				} else {
					res[i].OutCommit = common.BytesToHash(data[68:100])
				}
				break
			}
			sem.Release(1)
		}(i, m)
	}
	sem.Acquire(ctx, *threads)
	return res, nil
}

func buildStorageSlots(ctx context.Context, block uint64, client *ethclient.Client, transactions []ZkBobTransaction, extraUsers []common.Address) ([]common.Hash, error) {
	var slots []common.Hash
	for i := 0; i < 30; i++ {
		slots = append(slots, common.BytesToHash(binary.BigEndian.AppendUint16(nil, uint16(i))))
	}
	slots = append(slots,
		common.HexToHash("0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"), // EIP1967 implementation
		common.HexToHash("0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"), // EIP1967 admin
		common.HexToHash("0x06c991646992b7f0f3fd0c832eac3f519e26682bcb82fbbcfd1ff8013d876f64"), // KYC manager
	)
	users := make(map[common.Address]bool)
	operators := make(map[common.Address]bool)
	slots = append(slots, crypto.Keccak256Hash(math.PaddedBigBytes(big.NewInt(0), 32), math.PaddedBigBytes(big.NewInt(8), 32)))
	for _, tx := range transactions {
		operators[tx.Operator] = true
		if tx.User != nil {
			users[*tx.User] = true
		}

		// mapping(uint256 => uint256) public roots;
		slots = append(slots, crypto.Keccak256Hash(math.PaddedBigBytes(big.NewInt(int64(tx.Index)), 32), math.PaddedBigBytes(big.NewInt(8), 32)))

		if tx.Nullifier != nil {
			// mapping(uint256 => uint256) public nullifiers;
			slots = append(slots, crypto.Keccak256Hash(tx.Nullifier.Bytes(), math.PaddedBigBytes(big.NewInt(7), 32)))
		}
	}

	for _, u := range extraUsers {
		users[u] = true
	}

	for i := 0; i < 256; i++ {
		// mapping(uint256 => Tier) private tiers;
		slot := crypto.Keccak256Hash(math.PaddedBigBytes(big.NewInt(int64(i)), 32), math.PaddedBigBytes(big.NewInt(3), 32))
		slots = append(slots, slot, common.BytesToHash(new(big.Int).Add(slot.Big(), big.NewInt(1)).Bytes()))
	}

	for user := range users {
		// mapping(address => UserStats) private userStats;
		slots = append(slots, crypto.Keccak256Hash(user.Hash().Bytes(), math.PaddedBigBytes(big.NewInt(5), 32)))
	}

	for operator := range operators {
		// mapping(address => uint256) public accumulatedFee;
		slots = append(slots, crypto.Keccak256Hash(operator.Hash().Bytes(), math.PaddedBigBytes(big.NewInt(10), 32)))
	}

	slot0, err := client.StorageAt(ctx, common.HexToAddress(*poolAddress), common.BigToHash(big.NewInt(1)), big.NewInt(int64(block)))
	if err != nil {
		return nil, fmt.Errorf("can't get slot0: %w", err)
	}
	tailSlot := new(big.Int).SetBytes(slot0[18:21]).Int64()
	headSlot := new(big.Int).SetBytes(slot0[15:18]).Int64()

	for i := tailSlot; i <= headSlot; i++ {
		// mapping(uint256 => Snapshot) private snapshots;
		slots = append(slots, crypto.Keccak256Hash(math.PaddedBigBytes(big.NewInt(i), 32), math.PaddedBigBytes(big.NewInt(4), 32)))
	}
	return slots, nil
}

func fetchStorage(ctx context.Context, block uint64, client *ethclient.Client, transactions []ZkBobTransaction, extraUsers []common.Address) (map[common.Hash]common.Hash, error) {
	slots, err := buildStorageSlots(ctx, block, client, transactions, extraUsers)
	if err != nil {
		return nil, fmt.Errorf("can't get slots: %w", err)
	}

	res := make(map[common.Hash]common.Hash, len(slots))
	mut := sync.Mutex{}
	sem := semaphore.NewWeighted(*threads)
	for i, slot := range slots {
		err = sem.Acquire(ctx, 1)
		if err != nil {
			log.Fatalf("can't acquire: %w", err)
		}
		go func(i int, slot common.Hash) {
			if i == 0 || i%100 == 99 {
				log.Printf("Fetching slot %d/%d\n", i+1, len(slots))
			}
			for {
				value, err := client.StorageAt(ctx, common.HexToAddress(*poolAddress), slot, big.NewInt(int64(block)))
				if err != nil {
					log.Printf("Can't get slot value %s: %s\n", slot, err)
					continue
				}
				hash := common.BytesToHash(value)
				if hash != (common.Hash{}) {
					mut.Lock()
					res[slot] = hash
					mut.Unlock()
				}
				break
			}
			sem.Release(1)
		}(i, slot)
	}
	sem.Acquire(ctx, *threads)
	return res, nil
}

func computeStorageRoot(storage map[common.Hash]common.Hash) common.Hash {
	t := trie.NewEmpty(trie.NewDatabase(rawdb.NewMemoryDatabase()))
	for k, v := range storage {
		v1, _ := rlp.EncodeToBytes(common.TrimLeftZeroes(v[:]))
		t.Update(crypto.Keccak256(k.Bytes()), v1)
	}
	return t.Hash()
}
