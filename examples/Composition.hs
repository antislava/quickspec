-- Function composition.

module Main where

import QuickSpec

main = quickSpec [
  con "id" (id :: A -> A),
  con "." ((.) :: (B -> C) -> (A -> B) -> A -> C) ]
