-- A simple example testing arithmetic functions.

module Main where

import QuickSpec

main = quickSpec [
  con "0" (0 :: Int),
  con "1" (1 :: Int),
  con "+" ((+) :: Int -> Int -> Int),
  con "*" ((*) :: Int -> Int -> Int) ]
