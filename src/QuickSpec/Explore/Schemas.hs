-- Theory exploration which works on a schema at a time.
{-# LANGUAGE RecordWildCards, FlexibleContexts, PatternGuards, TupleSections, TemplateHaskell, MultiParamTypeClasses, FlexibleInstances #-}
module QuickSpec.Explore.Schemas where

import qualified Data.Map.Strict as Map
import Data.Map(Map)
import QuickSpec.Prop
import QuickSpec.Pruning
import QuickSpec.Term
import QuickSpec.Type
import QuickSpec.Testing
import QuickSpec.Utils
import qualified QuickSpec.Explore.Terms as Terms
import QuickSpec.Explore.Terms(Terms)
import Control.Monad.Trans.State.Strict hiding (State)
import Data.List
import Data.Ord
import Data.Lens.Light
import qualified Data.Set as Set
import Data.Set(Set)
import Data.Maybe
import Control.Monad

data Schemas testcase result fun norm =
  Schemas {
    sc_instantiate_singleton :: Term fun -> Bool,
    sc_empty :: Terms testcase result (Term fun) norm,
    sc_classes :: Terms testcase result (Term fun) norm,
    sc_instantiated :: Set (Term fun),
    sc_instances :: Map (Term fun) (Terms testcase result (Term fun) norm) }

makeLensAs ''Schemas
  [("sc_classes", "classes"),
   ("sc_instances", "instances"),
   ("sc_instantiated", "instantiated")]

instance_ :: Ord fun => Term fun -> Lens (Schemas testcase result fun norm) (Terms testcase result (Term fun) norm)
instance_ t = reading (\Schemas{..} -> keyDefault t sc_empty # instances)

initialState ::
  (Term fun -> Bool) ->
  (Term fun -> testcase -> result) ->
  Schemas testcase result fun norm
initialState inst eval =
  Schemas {
    sc_instantiate_singleton = inst,
    sc_empty = Terms.initialState eval,
    sc_classes = Terms.initialState eval,
    sc_instantiated = Set.empty,
    sc_instances = Map.empty }

data Result fun =
    Accepted { result_props :: [Prop (Term fun)] }
  | Rejected { result_props :: [Prop (Term fun)] }

-- The schema is represented as a term where there is only one distinct variable of each type
explore ::
  (PrettyTerm fun, Ord result, Ord fun, Ord norm, Typed fun,
  MonadTester testcase (Term fun) m, MonadPruner (Term fun) norm m) =>
  Term fun -> StateT (Schemas testcase result fun norm) m (Result fun)
explore t0 = do
  let t = mostSpecific t0
  res <- zoom classes (Terms.explore t)
  case res of
    Terms.Singleton -> do
      inst <- gets sc_instantiate_singleton
      if inst t then
        instantiateRep t
       else do
        -- Add the most general instance of the schema
        zoom (instance_ t) (Terms.explore (mostGeneral t0))
        return (Accepted [])
    Terms.Discovered ([] :=>: _ :=: u) ->
      exploreIn u t
    Terms.Knew ([] :=>: _ :=: u) ->
      exploreIn u t
    _ -> error "term layer returned non-equational property"

{-# INLINEABLE exploreIn #-}
exploreIn ::
  (PrettyTerm fun, Ord result, Ord fun, Ord norm, Typed fun,
  MonadTester testcase (Term fun) m, MonadPruner (Term fun) norm m) =>
  Term fun -> Term fun ->
  StateT (Schemas testcase result fun norm) m (Result fun)
exploreIn rep t = do
  -- First check if schema is redundant
  res <- zoom (instance_ rep) (Terms.explore (mostGeneral t))
  case res of
    Terms.Discovered prop -> do
      add prop
      return (Rejected [prop])
    Terms.Knew _ ->
      return (Rejected [])
    Terms.Singleton -> do
      -- Instantiate rep too if not already done
      inst <- access instantiated
      props <-
        if Set.notMember rep inst
        then result_props <$> instantiateRep rep
        else return []
      res <- instantiate rep t
      return res { result_props = props ++ result_props res }

{-# INLINEABLE instantiateRep #-}
instantiateRep ::
  (PrettyTerm fun, Ord result, Ord fun, Ord norm, Typed fun,
  MonadTester testcase (Term fun) m, MonadPruner (Term fun) norm m) =>
  Term fun ->
  StateT (Schemas testcase result fun norm) m (Result fun)
instantiateRep t = do
  instantiated %= Set.insert t
  instantiate t t

{-# INLINEABLE instantiate #-}
instantiate ::
  (PrettyTerm fun, Ord result, Ord fun, Ord norm, Typed fun,
  MonadTester testcase (Term fun) m, MonadPruner (Term fun) norm m) =>
  Term fun -> Term fun ->
  StateT (Schemas testcase result fun norm) m (Result fun)
instantiate rep t = zoom (instance_ rep) $ do
  let instances = sortBy (comparing generality) (allUnifications (mostGeneral t))
  Accepted <$> catMaybes <$> forM instances (\t -> do
    res <- Terms.explore t
    case res of
      Terms.Discovered prop -> do
        add prop
        return (Just prop)
      _ -> return Nothing)

-- sortBy (comparing generality) should give most general instances first.
generality :: Term f -> (Int, [Var])
generality t = (-length (usort (vars t)), vars t)

-- | Instantiate a schema by making all the variables different.
mostGeneral :: Term f -> Term f
mostGeneral s = evalState (aux s) Map.empty
  where
    aux (Var (V ty _)) = do
      m <- get
      let n = Map.findWithDefault 0 ty m
      put $! Map.insert ty (n+1) m
      return (Var (V ty n))
    aux (App f xs) = fmap (App f) (mapM aux xs)

mostSpecific :: Term f -> Term f
mostSpecific = subst (\(V ty _) -> Var (V ty 0))

allUnifications :: Term fun -> [Term fun]
allUnifications t = map f ss
  where
    vs = [ map (x,) (select xs) | xs <- partitionBy typ (usort (vars t)), x <- xs ]
    ss = map Map.fromList (sequence vs)
    go s x = Map.findWithDefault undefined x s
    f s = subst (Var . go s) t
    select [Var ty x] = [Var ty x, Var ty (succ x)]
    select xs = take 4 xs
