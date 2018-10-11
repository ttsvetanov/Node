{-# LANGUAGE DuplicateRecordFields  #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE TemplateHaskell        #-}

-- | Lenses for Blockchain domain types.
module Enecuum.Blockchain.Lens where

import           Control.Lens             ( makeFieldsNoPrefix )

import           Enecuum.Blockchain.Domain

makeFieldsNoPrefix ''Transaction
makeFieldsNoPrefix ''TransactionForSign
makeFieldsNoPrefix ''KBlock
makeFieldsNoPrefix ''Microblock
makeFieldsNoPrefix ''MicroblockForSign 