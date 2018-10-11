{-# LANGUAGE DeriveAnyClass  #-}
{-# LANGUAGE DuplicateRecordFields  #-}
{-# LANGUAGE FunctionalDependencies #-}

module Enecuum.Framework.Language.Extra where

import Enecuum.Prelude
import qualified Data.Aeson as A

import qualified Enecuum.Framework.State.Language      as L
import qualified Enecuum.Framework.Node.Language       as L
import qualified Enecuum.Framework.Networking.Language as L
import qualified Enecuum.Framework.NodeDefinition.Language as L
import qualified Enecuum.Core.Language                 as L
import qualified Enecuum.Core.Types                    as D
import qualified Enecuum.Framework.Domain              as D
import           Data.HGraph.StringHashable            (StringHashable)
import           Data.HGraph.THGraph                   (THGraph)

-- | Allows to extract graph variable from any structure.
-- To use it, you need to export it unqualified in scope of your data type lenses
-- (made by `makeFieldsNoPrefix`):
-- import Enecuum.Language (HasGraph)
class HasGraph s a | s -> a where
    graph :: Lens' s a

-- | Allows to extract `finished` variable from any structure.
-- To use it, you need to export it unqualified in scope of your data type lenses
-- (made by `makeFieldsNoPrefix`):
-- import Enecuum.Language (HasFinished)
class HasStatus s a | s -> a where
    status :: Lens' s a

data NodeStatus = NodeActing | NodeFinished
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

data StopNode = StopNode

instance A.FromJSON StopNode where
    parseJSON _ = pure StopNode


-- | Evals some graph action (atomically) having a structure that contains a graph variable.
-- To use it, you need to export HasGraph type class unqualified to the scope of your data type lenses
-- (made by `makeFieldsNoPrefix`):
-- import Enecuum.Language (HasGraph)
{-
withGraph
  :: HasGraph s (TVar (THGraph d))
  => (Serialize d, StringHashable d)
  => s
  -> L.HGraphL d a
  -> L.StateL a
-}
withGraph
    :: (HasGraph s (D.TGraph c), Serialize c, StringHashable c)
    => s
    -> Free (L.HGraphF (D.TNodeL c)) a
    -> L.StateL a
withGraph s = L.evalGraph (s ^. graph)

-- | Evals some graph action (non-atomically) having a structure that contains a graph variable.
-- To use it, you need to export HasGraph type class unqualified to the scope of your data type lenses
-- (made by `makeFieldsNoPrefix`):
-- import Enecuum.Language (HasGraph)
{-}
withGraphIO
  :: HasGraph s (TVar (THGraph d))
  => (Serialize d, StringHashable d)
  => s
  -> L.HGraphL d a
  -> L.NodeL a
  -}
withGraphIO s = L.evalGraphIO (s ^. graph)

-- TODO: make this a type class?
-- | Makes RPC call.
makeRpcRequest :: (Typeable a, ToJSON a, FromJSON b) => D.Address -> a -> L.NodeL (Either Text b)
makeRpcRequest connectCfg arg = L.evalNetworking $ L.makeRpcRequest' connectCfg arg

-- | Makes unsafe RPC call. Not recommended to use.
makeRpcRequestUnsafe :: (Typeable a, ToJSON a, FromJSON b) => D.Address -> a -> L.NodeL b
makeRpcRequestUnsafe connectCfg arg = makeRpcRequest connectCfg arg >>= \case
    Left  err -> error err
    Right a   -> pure a


-- | Forces node to stop (actually just fills the `status` field in the data structure. Use `nodeFinishPending` to await `status`.)
-- To use it, you need to export HasStatus type class unqualified to the scope of your data type lenses
-- (made by `makeFieldsNoPrefix`):
-- import Enecuum.Language (HasStatus)
stopNodeHandler :: HasStatus s (D.StateVar NodeStatus) => s -> StopNode -> L.NodeL Text
stopNodeHandler nodeData StopNode = do
    L.atomically $ L.writeVar (nodeData ^. status) NodeFinished
    pure "Finished."

-- | Forces node to stop (actually just fills the variable)
stopNodeHandler' :: D.StateVar NodeStatus -> StopNode -> L.NodeL Text
stopNodeHandler' statusVar StopNode = do
    L.atomically $ L.writeVar statusVar NodeFinished
    pure "Finished."

-- | Makes node awaiting for finishing.
-- To use it, you need to export HasStatus type class unqualified to the scope of your data type lenses
-- (made by `makeFieldsNoPrefix`):
-- import Enecuum.Language (HasStatus)
awaitNodeFinished :: HasStatus s (D.StateVar NodeStatus) => s -> L.NodeDefinitionL ()
awaitNodeFinished nodeData = do
    L.scenario $ L.atomically $ unlessM isNodeFinished L.retry
    where
        isNodeFinished = do
            s <- L.readVar $ nodeData ^. status
            pure $ s == NodeFinished

-- | Makes node awaiting for finishing.
awaitNodeFinished'
    :: D.StateVar NodeStatus
    -> L.NodeDefinitionL ()
awaitNodeFinished' statusVar = do
    L.scenario $ L.atomically $ unlessM isNodeFinished L.retry
    where
        isNodeFinished = do
            s <- L.readVar statusVar
            pure $ s == NodeFinished
