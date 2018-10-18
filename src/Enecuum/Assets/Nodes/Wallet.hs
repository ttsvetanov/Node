module Enecuum.Assets.Nodes.Wallet where

import Enecuum.Blockchain.Domain.Crypto
import Enecuum.Prelude

-- | Wallets and keys for demo purpose

publicKeys2 :: [PublicKey]
publicKeys2 = map readPublicKey
    [
    "8fM3up1pPDUgMnYZzKiBpsnrvNopjSoURSnpYbm5aZKz",
    "4vCovnpyuooGBi7t4LcEGeiQYA2pEKc4hixFGRGADw4X",
    "GS5xDwfTffg86Wyv8uy3H4vVQYqTXBFKPxGPy1Ksp2NS",
    "Jh8vrASby8nrVG7N3PLZjqSpbrpXFGmfpMd1nrYifZou",
    "8LZQhs3Z7WiBZbQvTTeXCcCtXfJYtk6RNxxBExo9PEQm"
    ]

privateKeys2 :: [PrivateKey]
privateKeys2 = map readPrivateKey
    [
          "FDabUqrGEd1i3rfZpqHJkzhvqP9QEpKveoEwmknfJJFa"
        , "DKAJTFr1bFWHE7psYX976YZis1Fqwkh3ikFAgKaw6bWj"
        , "6uU38xA2ucJ2zEqgg1zs5j3U8hx8RL3thVFNmhk3Nbsq"
        , "3n8QPsZwUJxUK85VrgTEuybyj1zDnUeMeovntB5EdqWP"
        , "MzwHKfF4vGsQB2hgcK3MFKY9TaFaUe78NJwQehfjZ5s"
    ]


wallets2 :: [KeyPair]
wallets2 = map (\(pub,priv) -> KeyPair pub priv) $ zip publicKeys2 privateKeys2

wallets1 =
    [ KeyPair { getPub = PublicKey256k1 162041393014266997694715179451060754359644353694678397659483656769944713491456, getPriv = PrivateKey256k1 73999854534268080627202311492113505346257058527387365056343245962475387806824}
    , KeyPair { getPub = PublicKey256k1 23186060215033531139909219478710866146713960681525059519120352475511495484295, getPriv = PrivateKey256k1 80275203804811449396339565643717793100181946842787928746035268781288915302925}
    , KeyPair { getPub = PublicKey256k1 164363796434547946853458519561021460997113148099374090547007640384559783907145, getPriv = PrivateKey256k1 45296987227396366574213327507378838872662579496436764556010122073219687535323}
    , KeyPair { getPub = PublicKey256k1 173043485450315606298237908613520700023796771897337701234671407559917415352139, getPriv = PrivateKey256k1 82158945569976313932019709311991001165798670590623541702268906445336500466266}
    , KeyPair { getPub = PublicKey256k1 147652403275775160917551599158321585505101195507923120640188760137020641154251, getPriv = PrivateKey256k1 93012031260270053609962666689128395737092805673829781984811938911430811953211}
    ]