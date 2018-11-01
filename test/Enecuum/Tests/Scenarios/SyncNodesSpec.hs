{-# LANGUAGE DuplicateRecordFields #-}

module Enecuum.Tests.Scenarios.SyncNodesSpec where

import           Data.Aeson
import qualified Data.Map                                     as M
import qualified Enecuum.Assets.Nodes.Address                 as A
import qualified Enecuum.Assets.Nodes.GraphNode.Receiver      as A
import qualified Enecuum.Assets.Nodes.GraphNode.Transmitter   as A
import qualified Enecuum.Assets.Nodes.Messages                as A
import qualified Enecuum.Assets.Nodes.PoA                     as A
import qualified Enecuum.Assets.Nodes.PoW                     as A
import qualified Enecuum.Blockchain.Lens                      as Lens
import qualified Enecuum.Domain                               as D
import qualified Enecuum.Framework.NodeDefinition.Interpreter as R
-- import           Enecuum.Interpreters                         (runNodeDefinitionL)
-- import qualified Enecuum.Language                             as L
import           Enecuum.Prelude
-- import qualified Enecuum.Runtime                              as R
-- import           Enecuum.Tests.Scenarios.Common
import           Test.Hspec
import           Test.Hspec.Contrib.HUnit                     (fromHUnitTest)
import           Test.HUnit
import qualified Enecuum.Assets.Nodes.GraphNode.Config       as A
import qualified Enecuum.Assets.Nodes.GraphNode.Transmitter  as A
import qualified Enecuum.Assets.Nodes.GraphNode.Receiver     as A
import qualified Enecuum.Assets.Nodes.PoW                    as A
import qualified Enecuum.Assets.Nodes.PoA                    as A
import qualified Enecuum.Assets.Nodes.Messages               as A
import qualified Enecuum.Assets.Nodes.Address                as A

import           Enecuum.Testing.Integrational

spec :: Spec
spec = describe "Synchronization tests" $ fromHUnitTest $ TestList
    [TestLabel "test net sync" testNodeNet]

-- waitForBlocks :: Integer -> D.Address -> IO ()
-- waitForBlocks number address = go 0
--     where
--         go :: Integer -> IO ()
--         go 50 = error "No valid results from node."
--         go n = do
--             threadDelay $ 1000 * 100
--             A.GetChainLengthResponse count <- D.withSuccess $ makeIORpcRequest address A.GetChainLengthRequest
--             when (count < number) $ go (n + 1)

testNodeNet :: Test
testNodeNet = TestCase $ do
    let graphNodeConfig = A.GraphNodeConfig ""
    let poaNodeConfig   = A.PoANodeConfig 0

    startNode Nothing $ A.graphNodeTransmitter graphNodeConfig
    waitForNode A.graphNodeTransmitterRpcAddress

    startNode Nothing A.powNode
    waitForNode A.powNodeRpcAddress

    startNode Nothing $ A.poaNode A.Good poaNodeConfig
    waitForNode A.poaNodeRpcAddress

    startNode Nothing $ A.graphNodeReceiver graphNodeConfig
    waitForNode A.graphNodeReceiverRpcAddress

    threadDelay $ 1000 * 1000

    _ :: Either Text A.SuccessMsg <- makeIORpcRequest A.powNodeRpcAddress $ A.NBlockPacketGeneration 2

    waitForBlocks 2 A.graphNodeTransmitterRpcAddress
    waitForBlocks 2 A.graphNodeReceiverRpcAddress

    threadDelay $ 1000 * 1000

    Right kBlock1 :: Either Text D.KBlock <- makeIORpcRequest A.graphNodeTransmitterRpcAddress A.GetLastKBlock
    Right kBlock2 :: Either Text D.KBlock <- makeIORpcRequest A.graphNodeReceiverRpcAddress    A.GetLastKBlock

    D.toHash kBlock1 `shouldBe` D.StringHash "LtemDXK0lVSbo90SjIG62jEOi/6CHl8x3ws38xcrpsI="
    kBlock1 `shouldBe` kBlock2

    Right (A.GetMBlocksForKBlockResponse mblocksPrev1) <- makeIORpcRequest A.graphNodeTransmitterRpcAddress
        $ A.GetMBlocksForKBlockRequest (kBlock1 ^. Lens.prevHash)
    Right (A.GetMBlocksForKBlockResponse mblocksPrev2) <- makeIORpcRequest A.graphNodeReceiverRpcAddress
        $ A.GetMBlocksForKBlockRequest (kBlock2 ^. Lens.prevHash)

    eWalletBalances1 :: [Either Text A.WalletBalanceMsg] <- forM (concat $ toKeys <$> mblocksPrev1) $ \i ->
        makeIORpcRequest A.graphNodeTransmitterRpcAddress $ A.GetWalletBalance i

    eWalletBalances2 :: [Either Text A.WalletBalanceMsg] <- forM (concat $ toKeys <$> mblocksPrev2) $ \i ->
        makeIORpcRequest A.graphNodeReceiverRpcAddress    $ A.GetWalletBalance i

    (rights eWalletBalances1) `shouldBe` (rights eWalletBalances2)
    length (rights eWalletBalances1) `shouldSatisfy` (> 0)

    -- Mblocks for the underlying kblock should be synchronized.
    length mblocksPrev1 `shouldBe` 1
    mblocksPrev1 `shouldBe` mblocksPrev2

    stopNode A.graphNodeTransmitterRpcAddress
    stopNode A.powNodeRpcAddress
    stopNode A.poaNodeRpcAddress
    stopNode A.graphNodeReceiverRpcAddress
    where
        toKeys mblocks = (D._owner :: D.Transaction -> D.PublicKey) <$> (D._transactions :: D.Microblock -> [D.Transaction]) mblocks
