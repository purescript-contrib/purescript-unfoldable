-- | This module provides a type class for _unfoldable functors_, i.e.
-- | functors which support an `unfoldr` operation.
-- |
-- | This allows us to unify various operations on arrays, lists,
-- | sequences, etc.

module Data.Unfoldable
  ( class Unfoldable, unfoldr
  , replicate
  , replicateA
  , none
  , fromMaybe
  , module Data.Unfoldable1
  ) where

import Prelude

import Data.Maybe (Maybe(..), isNothing, fromJust)
import Data.Traversable (class Traversable, sequence)
import Data.Tuple (Tuple(..), fst, snd)
import Data.Unfoldable1 (class Unfoldable1, unfoldr1, singleton, range, replicate1, replicate1A)
import Partial.Unsafe (unsafePartial)

-- | This class identifies (possibly empty) data structures which can be
-- | _unfolded_.
-- |
-- | Just as `Foldable` structures can be collapsed to a single value with
-- | `foldl` and a provided _folding_ function, `unfoldr` allows generating
-- | an `Unfoldable` structure from a provided _unfolding_ function and an
-- | initial seed value.
-- |
-- | The generating function `f` in `unfoldr f` is understood as follows:
-- |
-- | - If `f b` is `Nothing`, then `unfoldr f b` should be empty.
-- | - If `f b` is `Just (Tuple a b1)`, then `unfoldr f b` should consist of `a`
-- |   appended to the result of `unfoldr f b1`.
-- |
-- | For example:
-- | ``` purescript
-- | f :: Int -> Maybe (Tuple Int Int)
-- | f n | n < 0 = Nothing
-- | f n = Just (Tuple n (n - 1))
-- |
-- | unfoldr f 3 == [3, 2, 1, 0]
-- | unfoldr f 3 == 3 : 2 : 1 : 0 : Nil
-- | ```
-- |
-- | Note that it is not possible to give `Unfoldable` instances to types which
-- | represent structures which are guaranteed to be non-empty, such as
-- | `NonEmptyArray`: consider what `unfoldr (const Nothing)` should produce.
-- | Structures which are guaranteed to be non-empty can instead be given
-- | `Unfoldable1` instances.
class Unfoldable1 t <= Unfoldable t where
  unfoldr :: forall a b. (b -> Maybe (Tuple a b)) -> b -> t a

instance unfoldableArray :: Unfoldable Array where
  unfoldr = unfoldrArrayImpl isNothing (unsafePartial fromJust) fst snd

instance unfoldableMaybe :: Unfoldable Maybe where
  unfoldr f b = fst <$> f b

foreign import unfoldrArrayImpl
  :: forall a b
   . (forall x. Maybe x -> Boolean)
  -> (forall x. Maybe x -> x)
  -> (forall x y. Tuple x y -> x)
  -> (forall x y. Tuple x y -> y)
  -> (b -> Maybe (Tuple a b))
  -> b
  -> Array a

-- | Replicate a value some natural number of times.
-- |
-- | ``` purescript
-- | replicate 2 "foo" == ["foo", "foo"]
-- | replicate 2 "foo" == "foo" : "foo" : Nil
-- | ```
replicate :: forall f a. Unfoldable f => Int -> a -> f a
replicate n v = unfoldr step n
  where
    step :: Int -> Maybe (Tuple a Int)
    step i =
      if i <= 0 then Nothing
      else Just (Tuple v (i - 1))

-- | Perform an Applicative action `n` times, and accumulate all the results.
-- |
-- | ``` purescript
-- | > replicateA 5 (randomInt 1 10) :: Effect (Array Int)
-- | [1,3,2,7,5]
-- | > replicateA 5 (randomInt 1 10) :: _ (List _)
-- | (4 : 4 : 9 : 8 : 1 : Nil)
-- | ```
replicateA
  :: forall m f a
   . Applicative m
  => Unfoldable f
  => Traversable f
  => Int
  -> m a
  -> m (f a)
replicateA n m = sequence (replicate n m)

-- | The container with no elements - unfolded with zero iterations.
-- |
-- | ``` purescript
-- | none == ([] :: Array Unit)
-- | none == ([] :: _ Int)
-- | none == (Nil :: _ Number)
-- | ```
none :: forall f a. Unfoldable f => f a
none = unfoldr (const Nothing) unit

-- | Convert a Maybe to any Unfoldable, such as lists or arrays.
-- |
-- | ``` purescript
-- | fromMaybe (Nothing :: Maybe Int) == []
-- | fromMaybe (Just 1) == [1]
-- | fromMaybe (Just 1) == 1 : Nil
-- | ```
fromMaybe :: forall f a. Unfoldable f => Maybe a -> f a
fromMaybe = unfoldr (\b -> flip Tuple Nothing <$> b)
