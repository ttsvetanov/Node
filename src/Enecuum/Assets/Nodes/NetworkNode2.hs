{-# LANGUAGE DuplicateRecordFields  #-}
{-# LANGUAGE TemplateHaskell        #-}
{-# LANGUAGE FunctionalDependencies #-}

-- TODO: this is copy-paste from tests with little changes.
module Enecuum.Assets.Nodes.NetworkNode2 where

import           Enecuum.Prelude

import qualified Data.Aeson                    as A
import qualified Data.Map                      as Map
import qualified Data.Text as Text
import           Control.Lens                  (makeFieldsNoPrefix)

import           Enecuum.Config                (Config)
import qualified Enecuum.Domain                as D
import qualified Enecuum.Language              as L
import qualified Enecuum.Blockchain.Lens       as Lens
import qualified Enecuum.Framework.Lens        as Lens
import qualified Enecuum.Core.Lens             as Lens
import           Enecuum.Language              (HasGraph)

import           Enecuum.Core.HGraph.Internal.Types
import           Enecuum.Framework.Domain.RPC
import           Enecuum.Framework.RpcMethod.Language
import qualified Enecuum.Blockchain.Domain.Graph as TG
import           Enecuum.Assets.Nodes.RPC
import           Enecuum.Assets.Nodes.Address

data NetworkNode2Data = NetworkNode2Data
  { _graph        :: TG.GraphVar
  , _graphHeadVar :: D.StateVar D.StringHash
  , _balanceVar   :: D.StateVar Int
  }

makeFieldsNoPrefix ''NetworkNode2Data

acceptGetBalance
  :: NetworkNode2Data
  -> GetBalanceRequest
  -> L.NodeL GetBalanceResponse
acceptGetBalance nodeData GetBalanceRequest =
  GetBalanceResponse <$> (L.atomically $ L.readVar (nodeData ^. balanceVar))

acceptBalanceChange
  :: NetworkNode2Data
  -> BalanceChangeRequest
  -> L.NodeL BalanceChangeResponse
acceptBalanceChange nodeData (BalanceChangeRequest change) = do
  L.logInfo $ "Network node 2: receives balance change: " +|| change ||+ "."
  (l, r) <- L.atomically $ do
        curBalance   <- L.readVar $ nodeData ^. balanceVar
        graphHead    <- L.readVar $ nodeData ^. graphHeadVar
        mbNewBalance <- L.withGraph nodeData $ TG.tryAddTransaction' graphHead curBalance change
        case mbNewBalance of
          Nothing -> pure ("Network node 2: no balance change (invalid).", BalanceChangeResponse Nothing)
          Just (newGraphHead, newBalance) -> do
            L.writeVar (nodeData ^. balanceVar) newBalance
            L.writeVar (nodeData ^. graphHeadVar) newGraphHead
            pure $ ("Network node 2: balance change: adding new transaction to graph.", BalanceChangeResponse $ Just newBalance)
  L.logInfo l
  pure r

newtorkNode2Initialization :: TG.GraphVar -> L.NodeL NetworkNode2Data
newtorkNode2Initialization g = do
  baseNode <- L.evalGraphIO g $ L.getNode TG.nilTransactionHash >>= \case
    Nothing -> error "Graph is not ready: no genesis node found."
    Just baseNode -> pure baseNode
  balanceVar'   <- L.atomically $ L.newVar 0
  graphHeadVar' <- L.atomically $ L.newVar $ baseNode ^. Lens.hash
  pure $ NetworkNode2Data g graphHeadVar' balanceVar'

networkNode2 :: TG.GraphVar -> L.NodeDefinitionL ()
networkNode2 g = do
  L.nodeTag "networkNode2"
  nodeData <- L.initialization $ newtorkNode2Initialization g
  L.serving 2002 $ do
    L.method (acceptGetBalance nodeData)
    L.method (acceptBalanceChange nodeData)