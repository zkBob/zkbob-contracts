package main

import (
	"encoding/binary"
	"encoding/hex"
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
	deployer = flag.String("deployer", "0x39F0bD56c1439a22Ee90b4972c16b7868D161981", "")
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
			state1 := crypto.NewKeccakState()
			state2 := crypto.NewKeccakState()
			var buf [40]byte
			var hash1 common.Hash
			var hash2 common.Hash

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
				_, _ = state1.Write(msg)
				_, _ = state1.Read(hash1[:])
				state1.Reset()

				addr := ChecksumAddr(buf, hash1.Bytes()[12:], state2, hash2)

				if regex.MatchString(addr) {
					log.Printf("Found, nonce: %d, salt: %s, address: %s\n", i, common.BytesToHash(msg[21:53]), common.BytesToAddress(hash1[:]).Hex())
					break
				}
			}
		}(n)
	}

	wg.Wait()
}

func ChecksumAddr(buf [40]byte, addr []byte, state2 crypto.KeccakState, hash2 common.Hash) string {
	hex.Encode(buf[:], addr[:])
	_, _ = state2.Write(buf[:])
	_, _ = state2.Read(hash2[:])
	state2.Reset()
	for i := 0; i < 40; i++ {
		hashByte := hash2[i/2]
		if i%2 == 0 {
			hashByte = hashByte >> 4
		} else {
			hashByte &= 0xf
		}
		if buf[i] > '9' && hashByte > 7 {
			buf[i] -= 32
		}
	}
	return string(buf[:])
}
