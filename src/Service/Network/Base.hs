module Service.Network.Base (
    HostAddress,
    PortNumber(..),
    showHostAddress,
    sockAddrToHostAddress
  ) where

import Network.Socket
import Data.List

-- | Show host adres in 0.0.0.0 form.
showHostAddress :: HostAddress -> String
showHostAddress aHostAdress = concat $ intersperse "." $ show <$> [i1, i2, i3, i4]
  where (i1, i2, i3, i4) = hostAddressToTuple aHostAdress


-- | Transform SockAddr to HostAddress.
sockAddrToHostAddress :: SockAddr -> HostAddress
sockAddrToHostAddress aSockAddr = case aSockAddr of
    SockAddrInet _ aHostAdress                  -> aHostAdress
    SockAddrInet6 _ _  (_, _, _, aHostAdress) _ -> reverseAdr aHostAdress
    _                          -> error "error: sockAddrToHostAddress"


-- | 1.2.3.4 -> 4.3.2.1
reverseAdr :: HostAddress -> HostAddress
reverseAdr aHostAdress = case hostAddressToTuple aHostAdress of
    (a, b, c, d) -> tupleToHostAddress (d, c, b, a)
