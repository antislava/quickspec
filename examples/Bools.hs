-- Testing functions on booleans. "not x" is used as a condition.
module Main where

import QuickSpec

main = quickSpec [
  predicate "not" not,
  con "True" True,
  con "False" False,
  con "||" (||),
  con "&&" (&&) ]
