{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE ScopedTypeVariables #-}
module PoA.PoAServer (
        servePoA
  )  where

import              Control.Monad (forM_, void, forever, unless)
import qualified    Network.WebSockets                  as WS
import              Control.Concurrent.MVar
import              Service.Network.Base
import              Service.Network.WebSockets.Server
import qualified    Control.Concurrent.Chan as C
import              Control.Concurrent.Chan.Unagi.Bounded
import              Node.Node.Types
import              Service.InfoMsg as I
import qualified    Data.Text as T
import              Service.Types
import              System.Random.Shuffle
import              Data.Aeson as A
import              Control.Exception
import              Node.Data.GlobalLoging
import              PoA.Types
import qualified    Control.Concurrent as C
import              Node.FileDB.FileServer
import              PoA.Pending

import              Control.Concurrent.Async
import              Node.Data.Key
import              Data.Maybe()


servePoA ::
       PortNumber
    -> InChan MsgToCentralActor
    -> OutChan (Transaction, MVar Bool)
    -> InChan InfoMsg
    -> InChan FileActorRequest
    -> InChan Microblock
    -> IO ()
servePoA aRecivePort ch aRecvChan aInfoChan aFileServerChan aMicroblockChan = do
    writeLog aInfoChan [ServePoATag, InitTag] Info $
        "Init. servePoA: a port is " ++ show aRecivePort
    aPendingChan@(inChanPending, _) <- newChan 120
    void $ C.forkIO $ pendingActor aPendingChan aMicroblockChan aRecvChan aInfoChan
    runServer aRecivePort $ \_ aPending -> do
        aConnect <- WS.acceptRequest aPending
        WS.forkPingThread aConnect 30
        aMsg <- WS.receiveData aConnect
        case A.eitherDecodeStrict aMsg of
            Right (ActionConnect aNodeType (Just aNodeId)) -> do
                (aInpChan, aOutChan) <- newChan 64
                sendActionToCentralActor ch aNodeType $ NewConnect aNodeId aInpChan Nothing

                void $ race
                    (aSender aNodeId aConnect aOutChan)
                    (aReceiver aNodeType (IdFrom aNodeId) aConnect inChanPending)

            Right (ActionConnect aNodeType Nothing) -> do
                aNodeId <- generateClientId []
                WS.sendTextData aConnect $ A.encode $ ResponseNodeId aNodeId
                (aInpChan, aOutChan) <- newChan 64
                sendActionToCentralActor ch aNodeType $ NewConnect aNodeId aInpChan Nothing

                void $ race
                    (aSender aNodeId aConnect aOutChan)
                    (aReceiver aNodeType (IdFrom aNodeId) aConnect inChanPending)

            Right _ -> do
                writeLog aInfoChan [ServePoATag] Warning $ "Broken message from PP " ++ show aMsg
                WS.sendTextData aConnect $ T.pack ("{\"tag\":\"Response\",\"type\":\"ErrorOfConnect\", \"Msg\":" ++ show aMsg ++ ", \"comment\" : \"not a connect msg\"}")

            Left a -> do
                writeLog aInfoChan [ServePoATag] Warning $ "Broken message from PP " ++ show aMsg ++ " " ++ a
                WS.sendTextData aConnect $ T.pack ("{\"tag\":\"Response\",\"type\":\"ErrorOfConnect\", \"reason\":\"" ++ a ++ "\", \"Msg\":" ++ show aMsg ++"}")

  where
    aSender aId aConnect aNewChan = forever (WS.sendTextData aConnect . A.encode =<< readChan aNewChan)
        `finally` writeChan ch (NodeIsDisconnected aId)

    aReceiver aNodeType aId aConnect aPendingChan = forever $ do
        aMsg <- WS.receiveData aConnect
        writeLog aInfoChan [ServePoATag] Info $ "Raw msg: " ++ show aMsg
        case A.eitherDecodeStrict aMsg of
            Right a -> case a of
                -- REVIEW: Check fair distribution of transactions between nodes
                RequestTransaction aNum -> void $ C.forkIO $ do
                    aTmpChan <- C.newChan
                    writeInChan aPendingChan $ GetTransaction aNum aTmpChan
                    aTransactions <- C.readChan aTmpChan
                    writeLog aInfoChan [ServePoATag] Info "sendTransactions to poa"
                    WS.sendTextData aConnect $ A.encode $ ResponseTransactions aTransactions

                RequestPotentialConnects _ -> do
                    aShuffledRecords <- shuffleM =<< getRecords aFileServerChan
                    let aConnects = take 5 aShuffledRecords
                    writeLog aInfoChan [ServePoATag] Info $ "Send connections " ++ show aConnects
                    WS.sendTextData aConnect $ A.encode $ ResponsePotentialConnects aConnects

                RequestPoWList -> do
                        writeLog aInfoChan [ServePoATag] Info $
                            "PoWListRequest the msg from " ++ show aId
                        sendActionToCentralActor ch aNodeType $ RequestListOfPoW aId

                RequestPending (Just aTransaction) -> do
                    aTmpChan <- C.newChan
                    writeInChan aPendingChan $ IsInPending aTransaction aTmpChan
                    aTransactions <- C.readChan aTmpChan
                    WS.sendTextData aConnect $ A.encode $ ResponseTransactionIsInPending aTransactions

                RequestPending Nothing -> do
                    aTmpChan <- C.newChan
                    writeInChan aPendingChan $ GetPending aTmpChan
                    aTransactions <- C.readChan aTmpChan
                    WS.sendTextData aConnect $ A.encode $ ResponseTransactions aTransactions


                RequestActualConnects -> do
                    aMVar <- newEmptyMVar
                    sendActionToCentralActor ch aNodeType $ RequestActualConnectList aMVar
                    WS.sendTextData aConnect . A.encode . ResponseActualConnects =<< takeMVar aMVar
                --
                aMsg -> do
                    writeLog aInfoChan [ServePoATag] Info $ "Received msg " ++ show aMsg
                    sendMsgToCentralActor ch aNodeType aMsg

                _ -> return ()
            Left a -> do
                writeLog aInfoChan [ServePoATag] Warning $ "Broken message from PP " ++ show aMsg ++ " " ++ a
                WS.sendTextData aConnect $ T.pack ("{\"tag\":\"Response\",\"type\":\"Error\", \"reason\":\"" ++ a ++ "\", \"Msg\":" ++ show aMsg ++"}")


writeInChan :: InChan t -> t -> IO ()
writeInChan aChan aMsg = do
    aOk <- tryWriteChan aChan aMsg
    C.threadDelay 10000
    unless aOk $ writeInChan aChan aMsg


sendMsgToCentralActor :: InChan MsgToCentralActor -> NodeType -> NetMessage -> IO ()
sendMsgToCentralActor aChan aNodeType aMsg = writeInChan aChan (MsgFromNode aNodeType aMsg)


sendActionToCentralActor :: InChan MsgToCentralActor -> NodeType -> MsgFromNode -> IO ()
sendActionToCentralActor aChan aNodeType aMsg = writeInChan aChan (ActionFromNode aNodeType aMsg)
