pragma solidity ^0.6.0;

library Pairing {
    uint256 constant PRIME_Q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    struct G1Point {
        uint256 X;
        uint256 Y;
    }

    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint256[2] X;
        uint256[2] Y;
    }

    /*
        * @return The negation of p, i.e. p.plus(p.negate()) should be zero.
        */
    function negate(G1Point memory p) internal pure returns (G1Point memory) {
        // The prime q in the base field F_q for G1
        if (p.X == 0 && p.Y == 0) {
            return G1Point(0, 0);
        } else {
            return G1Point(p.X, PRIME_Q - (p.Y % PRIME_Q));
        }
    }

    /*
        * @return r the sum of two points of G1
        */
    function plus(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint256[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success
            case 0 { invalid() }
        }
        require(success, "pairing-add-failed");
    }

    /*
        * @return r the product of a point on G1 and a scalar, i.e.
        *         p == p.scalar_mul(1) and p.plus(p) == p.scalar_mul(2) for all
        *         points p.
        */
    function scalar_mul(G1Point memory p, uint256 s) internal view returns (G1Point memory r) {
        uint256[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success
            case 0 { invalid() }
        }
        require(success, "pairing-mul-failed");
    }

    /* @return The result of computing the pairing check
        *         e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
        *         For example,
        *         pairing([P1(), P1().negate()], [P2(), P2()]) should return true.
        */
    function pairing(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2,
        G1Point memory c1,
        G2Point memory c2,
        G1Point memory d1,
        G2Point memory d2
    )
        internal
        view
        returns (bool)
    {
        G1Point[4] memory p1 = [a1, b1, c1, d1];
        G2Point[4] memory p2 = [a2, b2, c2, d2];
        uint256 inputSize = 24;
        uint256[] memory input = new uint256[](inputSize);
        for (uint256 i = 0; i < 4; i++) {
            uint256 j = i * 6;
            input[j + 0] = p1[i].X;
            input[j + 1] = p1[i].Y;
            input[j + 2] = p2[i].X[0];
            input[j + 3] = p2[i].X[1];
            input[j + 4] = p2[i].Y[0];
            input[j + 5] = p2[i].Y[1];
        }
        uint256[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success
            case 0 { invalid() }
        }
        require(success, "pairing-opcode-failed");
        return out[0] != 0;
    }
}

contract TransferVerifier {
    uint256 constant SNARK_SCALAR_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 constant PRIME_Q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    using Pairing for *;

    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[6] IC;
    }

    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }

    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(
            9514134500877857403115335863915322693995540095145158372022904380007076027092,
            8372334624387565525385453061286946876689491244334233164795671529025622943939
        );
        vk.beta2 = Pairing.G2Point(
            [
                uint256(4635995007818623853650093150790373353457075178538446270966490675217280899399),
                10217172510376932092200837897222453543412130608279494572081813208483787189998
            ],
            [
                uint256(21284983559166676030831818105849125961107122403261403520488455937960710503136),
                20017983928110146483653560679660829686508688166374811003616195675959717362437
            ]
        );
        vk.gamma2 = Pairing.G2Point(
            [
                uint256(6136046590335400345918273294243776505048392510853923381842631312663153242877),
                20585716494914206082984940354882218392748583022208810126077519408917812442494
            ],
            [
                uint256(18697329406557667713753689819993356973765528768715915716510690442209484214489),
                4730373467638489776567365941261316077019230301864702351973879163044048991725
            ]
        );
        vk.delta2 = Pairing.G2Point(
            [
                uint256(13538272361037621383761776428158801706757118203414422069277904251214710109636),
                3912268273992685232788766540499837502724420881389257965573064602758288618565
            ],
            [
                uint256(21301877089672679085378105186741810200974630071306684834010243433426455347882),
                8464240234046220775662838314806909567632422175503983932636469026052879820874
            ]
        );
        vk.IC[0] = Pairing.G1Point(
            3492453369194876765551554929640565842657503375661358337169400340881663980150,
            15513374451080234903100010256504707802597515151648159389968534866429323908022
        );
        vk.IC[1] = Pairing.G1Point(
            13977685511525532625600730432701129223944169660194509809257463969717002070545,
            2371831061134998922849290259579931471434880589692062961670360786156909293732
        );
        vk.IC[2] = Pairing.G1Point(
            19446796187421046807471885509814867081214580749388098051977455723279523014635,
            18939412789801588930566495387906835941025039735264459832316959305347853659696
        );
        vk.IC[3] = Pairing.G1Point(
            18772890302244234557588665253660460087192325602128391754309399306310651480672,
            9464929287704544031293380032625532585366352188873178060444346636762510332248
        );
        vk.IC[4] = Pairing.G1Point(
            7655024459843840023914329401771491443863667457238466454230269046460061972846,
            7111420925292116527528019930341660122748488558568608460333454597412297677170
        );
        vk.IC[5] = Pairing.G1Point(
            16380634188725969906083517449323858883911255046426532187446742923586409664784,
            19746399438773145033388000646034532965581007071771129213954995152992975404622
        );
    }

    /*
        * @returns Whether the proof is valid given the hardcoded verifying key
        *          above and the public inputs
        */
    function verifyProof(uint256[5] memory input, uint256[8] memory p) public view returns (bool) {
        // Make sure that each element in the proof is less than the prime q
        for (uint8 i = 0; i < p.length; i++) {
            require(p[i] < PRIME_Q, "verifier-proof-element-gte-prime-q");
        }
        Proof memory _proof;
        _proof.A = Pairing.G1Point(p[0], p[1]);
        _proof.B = Pairing.G2Point([p[3], p[2]], [p[5], p[4]]);
        _proof.C = Pairing.G1Point(p[6], p[7]);
        VerifyingKey memory vk = verifyingKey();
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        vk_x = Pairing.plus(vk_x, vk.IC[0]);
        // Make sure that every input is less than the snark scalar field
        for (uint256 i = 0; i < input.length; i++) {
            require(input[i] < SNARK_SCALAR_FIELD, "verifier-gte-snark-scalar-field");
            vk_x = Pairing.plus(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }
        return Pairing.pairing(
            Pairing.negate(_proof.A), _proof.B, vk.alfa1, vk.beta2, vk_x, vk.gamma2, _proof.C, vk.delta2
        );
    }
}
