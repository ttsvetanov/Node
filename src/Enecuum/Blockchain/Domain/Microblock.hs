{-# LANGUAGE DeriveAnyClass        #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE RecordWildCards       #-}
module Enecuum.Blockchain.Domain.Microblock where

import           Enecuum.Prelude

import           Data.HGraph.StringHashable            (StringHash (..), StringHashable, toHash)

import qualified Crypto.Hash.SHA256                    as SHA
import qualified Data.ByteString.Base64                as Base64
import qualified Data.Serialize                        as S
import           Enecuum.Blockchain.Domain.Crypto
import           Enecuum.Blockchain.Domain.Transaction (Transaction)
import qualified Enecuum.Language                      as L

data Microblock = Microblock
    { _keyBlock     :: StringHash
    , _transactions :: [Transaction]
    , _publisher    :: PublicKey
    , _signature    :: Signature
    }
    deriving (Eq, Generic, Ord, Read, Show, ToJSON, FromJSON, Serialize)

instance StringHashable Microblock where
  toHash = StringHash . Base64.encode . SHA.hash . S.encode

data MicroblockForSign = MicroblockForSign
    { _keyBlock     :: StringHash
    , _transactions :: [Transaction]
    , _publisher    :: PublicKey
    }
    deriving (Eq, Generic, Ord, Read, Show, ToJSON, FromJSON, Serialize)

microblockForSign :: Microblock -> MicroblockForSign
microblockForSign (Microblock {..}) = MicroblockForSign
    { _keyBlock = _keyBlock
    , _transactions = _transactions
    , _publisher = _publisher}

verifyMicroblock :: Microblock -> Bool
verifyMicroblock mb@(Microblock {..}) = verifyEncodable _publisher _signature (microblockForSign mb)

signMicroblock :: (Monad m, L.ERandom m) => StringHash -> [Transaction] -> PublicKey -> PrivateKey -> m Microblock
signMicroblock hashofKeyBlock tx publisherPubKey publisherPrivKey = do
    let mb = MicroblockForSign
            { _keyBlock = hashofKeyBlock
            , _transactions = tx
            , _publisher = publisherPubKey
            }
    signature <- L.sign publisherPrivKey mb
    pure $ Microblock
            { _keyBlock = hashofKeyBlock
            , _transactions = tx
            , _publisher = publisherPubKey
            , _signature = signature
            }
