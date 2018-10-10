{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE DuplicateRecordFields    #-}
{-# LANGUAGE OverloadedStrings        #-}
{-# LANGUAGE PackageImports           #-}
{-# LANGUAGE ScopedTypeVariables      #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}

module Enecuum.Blockchain.Domain.Crypto.SerializeJSON where

import           Control.Monad
import qualified "cryptonite" Crypto.PubKey.ECC.ECDSA              as ECDSA
import           Data.Aeson
import           Data.Aeson.Types                                  (typeMismatch)
import           Data.ByteString                                   (ByteString)
import qualified Data.ByteString.Char8                             as BS

import           Control.Exception                                 (throw)
import qualified Data.ByteString.Base64                            as B
import           Data.ByteString.Conversion
import           Data.Text                                         (Text, pack,
                                                                    unpack)
import qualified Data.Text.Encoding                                as T (decodeUtf8,
                                                                         encodeUtf8)
import           Enecuum.Blockchain.Domain.Crypto.PublicPrivateKeyPair
import           Enecuum.Prelude hiding (unpack, pack)



instance FromJSON PublicKey where
  parseJSON (String s) = pure $ read $ unpack s
  -- parseJSON _          = error "PublicKey JSON parse error"

instance ToJSON PublicKey where
  toJSON key = String $ pack $ show key

instance FromJSON PrivateKey
instance ToJSON PrivateKey


encodeToText :: ByteString -> Text
encodeToText = T.decodeUtf8 . B.encode


decodeFromText :: (MonadPlus m) => Text -> m ByteString
decodeFromText aStr = case B.decode . T.encodeUtf8 $ aStr of
    Right a -> pure a
    Left  _ -> mzero

intToBase64Text :: Integer -> Text
intToBase64Text i = encodeToText $ toByteString' i

base64TextToInt :: (MonadPlus m) => Text -> m Integer
base64TextToInt b = do
    bs <- decodeFromText b
    case fromByteString bs of
        Just i -> pure i
        _      -> mzero


instance ToJSON ByteString where
  toJSON h = String $ pack $ BS.unpack h

instance FromJSON ByteString where
  parseJSON (String s) = pure $ BS.pack $ unpack s
  -- parseJSON e          = error "ByteString: Wrong object format" ++ show e

