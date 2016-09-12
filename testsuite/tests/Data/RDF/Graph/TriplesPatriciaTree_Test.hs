{-# LANGUAGE FlexibleInstances #-}

module Data.RDF.Graph.TriplesPatriciaTree_Test (triplesOf',uniqTriplesOf',empty',mkRdf') where

import Data.RDF.Types
import Data.RDF.Graph.TriplesPatriciaTree (TriplesPatriciaTree)
import Data.RDF.GraphTestUtils
import qualified Data.Map as Map
import Control.Monad

import Test.QuickCheck

instance Arbitrary TPatriciaTree

instance Arbitrary (RDF TriplesPatriciaTree) where
  arbitrary = liftM3 mkRdf arbitraryTs (return Nothing) (return $ PrefixMappings Map.empty)
  --coarbitrary = undefined

empty' :: RDF TriplesPatriciaTree
empty' = empty

mkRdf' :: Triples -> Maybe BaseUrl -> PrefixMappings -> RDF TriplesPatriciaTree
mkRdf' = mkRdf

triplesOf' :: RDF TriplesPatriciaTree -> Triples
triplesOf' = triplesOf

uniqTriplesOf' :: RDF TriplesPatriciaTree -> Triples
uniqTriplesOf' = uniqTriplesOf
