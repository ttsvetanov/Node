module Main where

import           App.Initialize  (initialize, runMultiNode)
import           App.GenConfigs  (genConfigs)
import           Enecuum.Config  (withConfig)
import           Enecuum.Prelude

defaultConfig :: IsString a => a
defaultConfig = "configs/config.json"

main :: IO ()
main = do
    args <- getArgs
    case args of
        ["singlenode", configFile] -> withConfig configFile initialize
        ["multinode", configFile]  -> withConfig configFile runMultiNode
        ["genConfigs"]             -> genConfigs
        _                          -> withConfig defaultConfig initialize
