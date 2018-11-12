module Enecuum.Framework.Networking.Interpreter where

import Enecuum.Prelude

import           Data.Aeson as A
import qualified Data.Text as T
import qualified Data.Map as M


import qualified Enecuum.Domain                     as D
import qualified Enecuum.Language                   as L
import qualified Enecuum.Framework.Networking.Internal.Tcp.Connection as Tcp ()
import qualified Enecuum.Framework.Networking.Internal.Udp.Connection as Udp
import qualified Enecuum.Framework.Networking.Internal.Connection     as Con
import           Enecuum.Framework.Runtime
import qualified Enecuum.Framework.RLens as RL
import qualified Network.Socket.ByteString.Lazy     as S
import           Enecuum.Framework.Networking.Internal.Client
import qualified Network.Socket as S hiding (recv, send) --, sendAll)


deleteConnection nodeRt conn = do
    connects <- atomically $ takeTMVar $ nodeRt ^. RL.tcpConnects
    let newConnects = M.delete conn connects 
    atomically $ putTMVar (nodeRt ^. RL.tcpConnects) newConnects

-- | Interpret NetworkingL language.
interpretNetworkingL :: NodeRuntime -> L.NetworkingF a -> IO a
interpretNetworkingL _ (L.SendRpcRequest addr request next) = do
    var <- newEmptyMVar
    ok  <- try $ runClient S.Stream addr $ \connect -> do
        S.sendAll connect $ A.encode request
        msg <- S.recv connect (1024 * 4)
        putMVar var (transformEither T.pack id $ A.eitherDecode msg)
    case ok of
        Right _                    -> pure ()
        Left  (_ :: SomeException) -> putMVar var $ Left "Server does not exist."
    res <- takeMVar var
    pure $ next res

interpretNetworkingL nr (L.SendTcpMsgByConnection conn msg next) = do
    m <- atomically $ readTMVar $ nr ^. RL.tcpConnects
    case conn `M.lookup` m of
        Just nativeConn -> do
            res <- Con.send nativeConn msg
            when (isLeft res) $ deleteConnection nr conn
            pure $ next res
        Nothing  -> do
            deleteConnection nr conn
            pure $ next $ Left D.ConnectionClosed

interpretNetworkingL nr (L.SendUdpMsgByConnection conn msg next) = do
    m <- atomically $ readTMVar $ nr ^. RL.udpConnects
    case conn `M.lookup` m of
        Just nativeConn -> next <$> Con.send nativeConn msg
        Nothing  -> do
            connects <- atomically $ takeTMVar $ nr ^. RL.udpConnects
            let newConnects = M.delete conn connects 
            atomically $ putTMVar (nr ^. RL.udpConnects) newConnects
            pure $ next $ Left D.ConnectionClosed

interpretNetworkingL _ (L.SendUdpMsgByAddress adr msg next) =
    next <$> Udp.sendUdpMsg adr msg

interpretNetworkingL _ _ = error "interpretNetworkingL EvalNetwork not implemented."

transformEither :: (a -> c) -> (b -> d) -> Either a b -> Either c d
transformEither f _ (Left  a) = Left (f a)
transformEither _ f (Right a) = Right (f a)

-- | Run Networking language.
runNetworkingL :: NodeRuntime -> L.NetworkingL a -> IO a
runNetworkingL nr = foldFree (interpretNetworkingL nr)
