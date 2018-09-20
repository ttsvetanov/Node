{-# LANGUAGE DuplicateRecordFields #-}

module Enecuum.Framework.TestData.Nodes where

import Enecuum.Prelude

import qualified Data.Aeson                    as A
import qualified Data.Map                      as Map

import qualified Enecuum.Domain                as D
import qualified Enecuum.Language              as L
import qualified Enecuum.Framework.Lens        as Lens
import qualified Enecuum.Core.Lens             as Lens
import qualified Data.Text as Text


import           Enecuum.Core.HGraph.Internal.Types
import           Enecuum.Framework.TestData.RPC
import qualified Enecuum.Framework.TestData.TestGraph as TG
import qualified Enecuum.Framework.Domain.Types as T
import           Enecuum.Legacy.Service.Network.Base
import           Enecuum.Framework.Domain.RpcMessages
import           Enecuum.Framework.RpcMethod.Language 
import           Enecuum.Framework.Node.Language          ( NodeModel )

makeRpcRequest
  :: (ToJSON a, FromJSON b) => D.ConnectionConfig -> Text -> a -> L.NodeModel (Either Text b)
makeRpcRequest connectCfg name arg = do
    res <- L.evalNetworking $ L.withConnection connectCfg (makeRequest name arg)
    case res of
        Left txt -> pure $ Left txt
        Right (RpcResponseError (A.String txt) _) -> pure $ Left txt
        Right (RpcResponseError err _)            -> pure $ Left (show err)
        Right (RpcResponseResult val _) -> case A.fromJSON val of
            A.Error txt -> pure $ Left (Text.pack txt)
            A.Success resp -> pure $ Right resp
            

makeRequestUnsafe
  :: (ToJSON a, FromJSON b) => D.ConnectionConfig -> Text -> a -> L.NodeModel b
makeRequestUnsafe connectCfg name arg =
    (\(Right a) -> a) <$> makeRpcRequest connectCfg name arg



bootNodeAddr, masterNode1Addr :: D.NodeAddress
bootNodeAddr = ConnectInfo "0.0.0.0" 1000
masterNode1Addr = ConnectInfo "0.0.0.1" 1000

networkNode1Addr, networkNode2Addr :: D.NodeAddress
networkNode1Addr = ConnectInfo "0.0.0.2" 1000
networkNode2Addr = ConnectInfo "0.0.0.3" 1000

bootNodeTag, masterNodeTag :: D.NodeTag
bootNodeTag = "bootNode"
masterNodeTag = "masterNode"

-- | Boot node discovery sample scenario.
-- Currently, does nothing but returns the default boot node address.
simpleBootNodeDiscovery :: L.NetworkModel D.NodeAddress
simpleBootNodeDiscovery = pure bootNodeAddr

-- RPC handlers.

acceptHello1 :: HelloRequest1 ->  NodeModel HelloResponse1
acceptHello1 (HelloRequest1 msg) = pure $ HelloResponse1 $ "Hello, dear. " +| msg |+ ""

acceptHello2 :: HelloRequest2 ->  NodeModel HelloResponse2
acceptHello2 (HelloRequest2 msg) = pure $ HelloResponse2 $ "Hello, dear2. " +| msg |+ ""

acceptGetHashId :: GetHashIDRequest ->  NodeModel GetHashIDResponse
acceptGetHashId GetHashIDRequest = pure $ GetHashIDResponse "1"

-- Scenario 1: master node can interact with boot node.

bootNode :: L.NodeDefinitionModel ()
bootNode = do
  L.nodeTag bootNodeTag
  L.initialization $ pure $ D.NodeID "abc"
  L.servingRpc 1000 $ do
    method "hello1"    acceptHello1
    method "getHashId" acceptGetHashId

masterNodeInitialization :: L.NodeModel (Either Text D.NodeID)
masterNodeInitialization = do
  addr     <- L.evalNetworking $ L.evalNetwork simpleBootNodeDiscovery
  Right (GetHashIDResponse eHashID)  <- makeRpcRequest (D.ConnectionConfig addr) "getHashId" GetHashIDRequest
  pure $ Right (D.NodeID eHashID)
  
masterNode :: L.NodeDefinitionModel ()
masterNode = do
  L.nodeTag masterNodeTag
  nodeId <- D.withSuccess $ L.initialization masterNodeInitialization
  L.logInfo $ "Master node got id: " +|| nodeId ||+ "."
  L.servingRpc 1000 $ do
    method "hello1" acceptHello1
    method "hello2" acceptHello2

-- Scenario 2: 2 network nodes can interact.
-- One holds a graph with transactions. Other requests balance and amount change.

-- In this scenario, we assume the graph is list-like.
calculateBalance
  :: D.StringHash
  -> Int
  -> L.LGraphModel Int
calculateBalance curNodeHash curBalance = L.getNode curNodeHash >>= \case
  Nothing -> error "Invalid reference found."
  Just curNode -> do
    let trans = D.fromContent $ curNode ^. Lens.content
    let balanceChange = trans ^. Lens.change
    let links = curNode ^. Lens.links
    case Map.toList links of
      [] -> pure $ curBalance + balanceChange
      [(nextNodeHash, _)] -> calculateBalance nextNodeHash $ curBalance + balanceChange
      _ -> error "In this test scenario, graph should be list-like."

tryAddTransaction'
  :: (TNodeL D.Transaction)
  -> Int
  -> Int
  -> L.LGraphModel (Maybe (D.StringHash, Int))
tryAddTransaction' lastNode lastBalance change
  | lastBalance + change < 0 = pure Nothing
  | otherwise = do
      let newTrans = D.Transaction (lastNode ^. Lens.hash) change
      let newTransHash = D.toHash newTrans
      L.newNode newTrans
      L.newLink (lastNode ^. Lens.hash) newTransHash
      pure $ Just (lastNode ^. Lens.hash, lastBalance + change)

tryAddTransaction
  :: D.StringHash
  -> Int
  -> Int
  -> L.LGraphModel (Maybe (D.StringHash, Int))
tryAddTransaction curNodeHash prevBalance change = L.getNode curNodeHash >>= \case
  Nothing -> error "Invalid reference found."
  Just curNode -> do
    let trans = D.fromContent $ curNode ^. Lens.content
    let curBalanceChange = trans ^. Lens.change
    let curBalance = prevBalance + curBalanceChange
    let links = curNode ^. Lens.links
    case Map.toList links of
      [] -> tryAddTransaction' curNode curBalance change
      [(nextNodeHash, _)] -> tryAddTransaction nextNodeHash curBalance change
      _ -> error "In this test scenario, graph should be list-like."

acceptGetBalance :: TNodeL D.Transaction -> GetBalanceRequest -> NodeModel GetBalanceResponse
acceptGetBalance baseNode GetBalanceRequest = do
  balance <- L.evalGraph (calculateBalance (baseNode ^. Lens.hash) 0)
  pure $ GetBalanceResponse balance


acceptBalanceChange :: TNodeL D.Transaction -> BalanceChangeRequest -> NodeModel BalanceChangeResponse
acceptBalanceChange baseNode (BalanceChangeRequest change) = do
  mbHashAndBalance <- L.evalGraph $ tryAddTransaction (baseNode ^. Lens.hash) 0 change
  pure $ case mbHashAndBalance of
    Nothing                        -> BalanceChangeResponse Nothing
    Just (D.StringHash _, balance) -> BalanceChangeResponse (Just balance)


makeMethod :: (FromJSON a, ToJSON b) => (a -> NodeModel b) -> A.Value -> Int -> NodeModel RpcResponse
makeMethod f a i = case A.fromJSON a of
    A.Success req -> do
        res <- f req
        pure $ RpcResponseResult (A.toJSON res) i
    A.Error _     -> pure $ RpcResponseError  (A.toJSON $ A.String "Error in parsing of args") i


makeMethod' :: (FromJSON a, ToJSON b) => (a -> NodeModel (Either Text b)) -> A.Value -> Int -> NodeModel RpcResponse
makeMethod' f a i = case A.fromJSON a of
    A.Success req -> do
        res <- f req
        case res of
            Right b -> pure $ RpcResponseResult (A.toJSON b) i
            Left  t -> pure $ RpcResponseError  (A.toJSON $ A.String t) i
    A.Error _     -> pure $ RpcResponseError  (A.toJSON $ A.String "Error in parsing of args") i


class MethodMaker a where
    method :: Text -> a -> Free RpcMethodL ()

instance (ToJSON b, FromJSON a) => MethodMaker (a -> NodeModel b) where
    method t f = rpcMethod t (makeMethod f)

instance (ToJSON b, FromJSON a) => MethodMaker (a -> NodeModel (Either Text b)) where
    method t f = rpcMethod t (makeMethod' f)

makeResult :: ToJSON a => Int -> a -> NodeModel RpcResponse
makeResult i a = pure $ RpcResponseResult (A.toJSON a) i

newtorkNode1Initialization :: L.NodeModel (TNodeL D.Transaction)
newtorkNode1Initialization = L.evalGraph $ TG.getTransactionNode TG.nilTransaction >>= \case
  Nothing -> error "Graph is not ready: no genesis node found."
  Just baseNode -> pure baseNode


networkNode1 :: L.NodeDefinitionModel ()
networkNode1 = do
  L.nodeTag "networkNode1"
  baseNode <- L.initialization newtorkNode1Initialization
  L.servingRpc 1000 $ do
    method "getBalance"    (acceptGetBalance baseNode)
    method "balanceChange" (acceptBalanceChange baseNode)



networkNode2Scenario :: L.NodeModel ()
networkNode2Scenario = do
    let connectCfg = D.ConnectionConfig networkNode1Addr
    -- No balance change
    GetBalanceResponse balance0 <- makeRequestUnsafe connectCfg "getBalance" GetBalanceRequest
    L.logInfo $ "balance0 (should be 0): " +|| balance0 ||+ "."
    -- Add 10
    BalanceChangeResponse balance1 <- makeRequestUnsafe connectCfg "balanceChange" $ BalanceChangeRequest 10
    L.logInfo $ "balance1 (should be Just 10): " +|| balance1 ||+ "."
    -- Subtract 20
    BalanceChangeResponse balance2 <- makeRequestUnsafe connectCfg "balanceChange" $ BalanceChangeRequest (-20)
    L.logInfo $ "balance2 (should be Nothing): " +|| balance2 ||+ "."
    -- Add 101
    BalanceChangeResponse balance3 <- makeRequestUnsafe connectCfg "balanceChange" $ BalanceChangeRequest 101
    L.logInfo $ "balance3 (should be Just 111): " +|| balance3 ||+ "."
    -- Final balance
    GetBalanceResponse balance4 <- makeRequestUnsafe connectCfg "getBalance" GetBalanceRequest
    L.logInfo $ "balance4 (should be 111): " +|| balance4 ||+ "."



networkNode2 :: L.NodeDefinitionModel ()
networkNode2 = do
  L.nodeTag "networkNode2"
  L.scenario networkNode2Scenario
