{-# LANGUAGE GADTs #-}

module Enecuum.Framework.Node.Language where

import           Enecuum.Prelude
import qualified Enecuum.Core.Types                       as T
import qualified Enecuum.Core.Language                    as L
import qualified Enecuum.Framework.State.Language         as L
import qualified Enecuum.Framework.Networking.Language    as L
import qualified Enecuum.Framework.Domain                 as D

-- | Node language.
data NodeF next where
  -- | Eval stateful action atomically.
  EvalStateAtomically :: L.StateL a -> (a -> next) -> NodeF next
  -- | Eval networking.
  EvalNetworking :: L.NetworkingL a -> (a -> next) -> NodeF next
  -- | Eval core effect.
  EvalCoreEffectNodeF :: L.CoreEffectModel a -> (a -> next) -> NodeF next
  -- | Eval graph non-atomically (parts of script are evaluated atomically but separated from each other).
  EvalGraphIO :: L.GraphModel a -> (a -> next) -> NodeF next
    -- | Eval graph.
    EvalGraph      :: LGraphModel a -> (a -> next) -> NodeF next
    -- | Eval networking.
    EvalNetworking :: L.NetworkingL a -> (a -> next) -> NodeF next
    -- | Eval core effect.
    EvalCoreEffectNodeF :: L.CoreEffect a -> (a -> next) -> NodeF next

instance Functor NodeF where
  fmap g (EvalStateAtomically statefulAction next) = EvalStateAtomically statefulAction (g . next)
  fmap g (EvalNetworking networking next)          = EvalNetworking networking          (g . next)
  fmap g (EvalCoreEffectNodeF coreEffect next)     = EvalCoreEffectNodeF coreEffect     (g . next)
  fmap g (EvalGraphIO graphAction next)            = EvalGraphIO graphAction            (g . next)
    fmap g (EvalGraph graph next) = EvalGraph graph (g . next)
    fmap g (EvalNetworking networking next) =
        EvalNetworking networking (g . next)
    fmap g (EvalCoreEffectNodeF coreEffect next) =
        EvalCoreEffectNodeF coreEffect (g . next)

type NodeL next = Free NodeF next

-- | Eval stateful action atomically.
evalStateAtomically :: L.StateL a -> NodeModel a
evalStateAtomically statefulAction = liftF $ EvalStateAtomically statefulAction id

-- | Alias for convenience.
atomically :: L.StateL a -> NodeModel a
atomically = evalStateAtomically

-- | Eval networking.
evalNetworking :: L.NetworkingL a -> NodeL a
evalNetworking newtorking = liftF $ EvalNetworking newtorking id

-- | Eval core effect.
evalCoreEffectNodeF :: L.CoreEffect a -> NodeL a
evalCoreEffectNodeF coreEffect = liftF $ EvalCoreEffectNodeF coreEffect id

-- | Eval graph non-atomically (parts of script are evaluated atomically but separated from each other).
evalGraphIO :: L.GraphModel a -> NodeModel a
evalGraphIO graphAction = liftF $ EvalGraphIO graphAction id

instance L.Logger (Free NodeF) where
    logMessage level msg = evalCoreEffectNodeF $ L.logMessage level msg
