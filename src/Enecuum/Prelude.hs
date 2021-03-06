{-# OPTIONS -fno-warn-orphans #-}

module Enecuum.Prelude
  ( module X
  , trace
  , trace_
  ) where

import           Control.Concurrent           as X (ThreadId, forkIO, killThread, threadDelay)
import           Control.Concurrent.STM       as X (retry)
import           Control.Concurrent.STM.TMVar as X (TMVar, newEmptyTMVar, newEmptyTMVarIO, newTMVar, newTMVarIO,
                                                    putTMVar, readTMVar, takeTMVar, tryReadTMVar)
import           Control.Concurrent.STM.TVar  as X (modifyTVar)
import           Control.Exception            as X (SomeException (..))
import           Control.Lens                 as X (at, (.=))
import           Control.Lens.TH              as X (makeFieldsNoPrefix, makeLenses)
import           Control.Monad                as X (liftM, unless, void, when)
import           Control.Monad.Free           as X (Free (..), foldFree, liftF)
import           Control.Newtype.Generics     as X (Newtype, O, pack, unpack)
import           Data.Aeson                   as X (FromJSON, ToJSON, genericParseJSON, genericToJSON, parseJSON,
                                                    toJSON)
import           Data.Maybe                   as X (fromJust, fromMaybe)
import           Data.Serialize               as X (Serialize)
import           Data.TypeLevel               as X (type (++))
import           Fmt                          as X ((+|), (+||), (|+), (||+))
import           GHC.Base                     as X (until)
import           GHC.Generics                 as X (Generic)
import           Text.Read                    as X (read, readsPrec)
import           Universum                    as X hiding (All, Option, Set, Type, head, init, last, set, tail, trace)
import qualified Universum                    as U
import           Universum.Functor.Fmap       as X ((<<$>>))
import           Universum.Unsafe             as X (head, init, last, tail, (!!))


trace :: Text -> m a -> m a
trace = U.trace

trace_ :: Applicative m => Text -> m ()
trace_ txt = trace txt (pure ())
