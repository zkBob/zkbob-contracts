package main

import (
	"encoding/binary"
	"encoding/json"
	"flag"
	"log"
	"os"
	"regexp"
	"sync"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/crypto"
)

var (
	deployer = flag.String("deployer", "0xBF3d6f830CE263CAE987193982192Cd990442B53", "")
	mockImpl = flag.String("mockImpl", "0xdead", "")
	factory  = flag.String("factory", "0xce0042B868300000d44A59004Da54A005ffdcf9f", "")
	pattern  = flag.String("pattern", "(?i)^0xB0B.*B0B$", "")
	threads  = flag.Int("threads", 10, "")
)

func main() {
	flag.Parse()

	log.Printf("Factory address: %s\n", *factory)
	log.Printf("Contract: EIP1967Proxy\n")
	log.Printf("Deployer: %s\n", *deployer)
	log.Printf("Implementation: %s\n", *mockImpl)
	log.Printf("Threads: %d\n", *threads)
	log.Printf("Generating vanity addr: %s\n", *pattern)

	rawArtifact, err := os.Open("./contracts/EIP1967Proxy.json")
	if err != nil {
		log.Fatalln("can't open file", err)
	}
	artifact := make(map[string]interface{}, 10)
	err = json.NewDecoder(rawArtifact).Decode(&artifact)
	if err != nil {
		log.Fatalln("can't decode data", err)
	}

	regex := regexp.MustCompile(*pattern)

	initCode := hexutil.MustDecode(artifact["bytecode"].(map[string]interface{})["object"].(string))
	arg1 := common.HexToAddress(*deployer).Hash().Bytes()
	arg2 := common.HexToAddress(*mockImpl).Hash().Bytes()
	arg3 := make([]byte, 64)
	arg3[31] = 0x60
	initCode = append(initCode, arg1...)
	initCode = append(initCode, arg2...)
	initCode = append(initCode, arg3...)
	initCodeHash := crypto.Keccak256Hash(initCode)

	log.Printf("Code hash: %s\n", initCodeHash)

	wg := sync.WaitGroup{}
	wg.Add(1)
	for n := 0; n < *threads; n++ {
		go func(n int) {
			defer wg.Done()
			state := crypto.NewKeccakState()
			var hash common.Hash

			// keccak256( 0xff ++ address ++ salt ++ keccak256(init_code))[12:]
			msg := make([]byte, 85)
			msg[0] = 0xff
			copy(msg[1:21], common.HexToAddress(*factory).Bytes())
			copy(msg[53:85], initCodeHash.Bytes())
			for i := n; ; i += *threads {
				if (i / *threads)%5000000 == 0 {
					log.Printf("progress (%d/%d) - %d\n", n+1, *threads, i)
				}
				binary.BigEndian.PutUint64(msg[45:], uint64(i))
				_, _ = state.Write(msg)
				state.Read(hash[:])
				state.Reset()
				addr := common.BytesToAddress(hash.Bytes())
				if regex.MatchString(addr.String()) {
					log.Printf("Found, nonce: %d, salt: %s, address: %s\n", i, common.BytesToHash(msg[21:53]), addr.String())
					break
				}
			}
		}(n)
	}

	wg.Wait()
}
