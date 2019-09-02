-- A simple example testing arithmetic functions.

module Main where

import QuickSpec

main = quickSpec [
    con "0" (0 :: Float)
  , con "1" (1 :: Float)
  , con "+" ((+) :: Float -> Float -> Float)
  , con "*" ((*) :: Float -> Float -> Float)
  , monoType (Proxy :: Proxy Float)
  ]
