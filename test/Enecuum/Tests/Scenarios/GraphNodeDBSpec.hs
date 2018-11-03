{-# LANGUAGE TemplateHaskell        #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE PackageImports         #-}

module Enecuum.Tests.Scenarios.GraphNodeDBSpec where

import           Enecuum.Prelude

import qualified Data.Aeson    as A
import           Data.Typeable (typeOf)
import           Data.Proxy    (Proxy)
import qualified Data.Map      as M
import qualified Data.List     as List
import           Data.Kind
import qualified Data.ByteString.Lazy as LBS
import           Control.Lens (makeFieldsNoPrefix)
import qualified "rocksdb-haskell" Database.RocksDB as Rocks
import qualified System.Directory as Dir
import           System.FilePath as FP ((</>))
import           Text.Printf (printf)

import           Enecuum.Interpreters                         (runNodeDefinitionL)
import qualified Enecuum.Runtime                              as R
import qualified Enecuum.Framework.NodeDefinition.Interpreter as R
import qualified Enecuum.Domain                               as D
import qualified Enecuum.Language                             as L
import qualified Enecuum.Blockchain.Lens                      as Lens
import           Enecuum.Blockchain.DB

import qualified Enecuum.Framework.NodeDefinition.Interpreter as R

import qualified Enecuum.Assets.Nodes.GraphNode.Config       as A
import qualified Enecuum.Assets.Nodes.GraphNode.Transmitter  as A
import qualified Enecuum.Assets.Nodes.PoW.Config             as A
import qualified Enecuum.Assets.Nodes.PoW.PoW                as A
import qualified Enecuum.Assets.Nodes.Messages               as A
import qualified Enecuum.Assets.Nodes.Address                as A

import           Test.Hspec
import           Enecuum.Testing.Integrational

spec :: Spec
spec = do
    let dbOpts = D.defaultDbOptions
                { D._createIfMissing = True
                , D._errorIfExists   = False
                }
    let blocksCount = 10
    let blocksDelay = 0

    describe "Dump and restore graph test" $ do
        it "Write and Read KBlock Meta" $ withDbAbsence dbPath $ do
            let graphNodeConfig = A.GraphNodeConfig "dumped_graph.dbm" dbOpts True

            startNode Nothing $ A.graphNodeTransmitter graphNodeConfig
            waitForNode A.graphNodeTransmitterRpcAddress

            startNode Nothing A.powNode
            waitForNode A.powNodeRpcAddress

            _ :: Either Text A.SuccessMsg <- makeIORpcRequest A.powNodeRpcAddress $ A.NBlockPacketGeneration blocksCount blocksDelay

            waitForBlocks blocksCount A.graphNodeTransmitterRpcAddress
            
            void $ makeIORpcRequest A.graphNodeReceiverRpcAddress A.DumpToDB

            threadDelay $ 1000 * 1000



