package main

import (
	"encoding/binary"
	"encoding/json"
	"flag"
	"log"
	"os"
	"regexp"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/crypto"
)

var (
	deployer = flag.String("deployer", "0xBF3d6f830CE263CAE987193982192Cd990442B53", "")
	mockImpl = flag.String("mockImpl", "0xdead", "")
	pattern  = flag.String("pattern", "(?i)^0xB0B.*B0B$", "")
)

func main() {
	flag.Parse()

	rawArtifact, err := os.Open("../../out/EIP1967Proxy.sol/EIP1967Proxy.json")
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
	initCode = append(initCode, arg1...)
	initCode = append(initCode, arg2...)
	initCodeHash := crypto.Keccak256Hash(initCode)

	// keccak256( 0xff ++ address ++ salt ++ keccak256(init_code))[12:]
	msg := make([]byte, 85)
	msg[0] = 0xff
	copy(msg[1:21], common.HexToAddress("0xce0042B868300000d44A59004Da54A005ffdcf9f").Bytes())
	copy(msg[53:85], initCodeHash.Bytes())
	for i := 0; ; i++ {
		if i%500000 == 0 {
			log.Println("progress", i)
		}
		binary.BigEndian.PutUint64(msg[45:], uint64(i))
		hash := crypto.Keccak256Hash(msg)
		addr := common.BytesToAddress(hash.Bytes())
		if regex.MatchString(addr.String()) {
			log.Println(i, common.BytesToHash(msg[21:53]), addr.String())
			break
		}
	}
}
