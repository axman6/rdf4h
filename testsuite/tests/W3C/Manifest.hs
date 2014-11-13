module W3C.Manifest (
  loadManifest,

  Manifest(..),
  TestEntry(..)
) where

import Data.RDF.TriplesGraph
import Data.RDF.Query
import Data.RDF.Types
import Data.RDF.Namespace
import Text.RDF.RDF4H.TurtleParser

import qualified Data.Text as T
import qualified Data.List as L (find)
import Data.Maybe (fromJust)

-- | Manifest data as represented in W3C test files.
data Manifest =
    Manifest {
      description :: T.Text,
      entries :: [TestEntry]
    }

data TestEntry =
    TestTurtleEval {
      name :: T.Text,
      comment :: T.Text,
      approval :: Node,
      action :: Node,
      result :: Node
    } |
    TestTurtleNegativeEval {
      name :: T.Text,
      comment :: T.Text,
      approval :: Node,
      action :: Node
    } |
    TestTurtlePositiveSyntax {
      name :: T.Text,
      comment :: T.Text,
      approval :: Node,
      action :: Node
    } |
    TestTurtleNegativeSyntax {
      name :: T.Text,
      comment :: T.Text,
      approval :: Node,
      action :: Node
    }

-- TODO: Perhaps these should be pulled from the manifest graph
rdfType = unode $ mkUri rdf "type"
rdfsComment = unode $ mkUri rdfs "comment"
rdftTestTurtleEval = unode "http://www.w3.org/ns/rdftest#TestTurtleEval"
rdftTestTurtleNegativeEval = unode "http://www.w3.org/ns/rdftest#TestTurtleNegativeEval"
rdftApproval = unode "http://www.w3.org/ns/rdftest#approval"
mfName = unode "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#name"
mfManifest = unode "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#Manifest"
mfAction = unode "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#action"
mfResult = unode "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#result"
mfEntries = unode "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#entries"

-- | Load the manifest from the given file;
-- apply the given namespace as the base IRI of the manifest.
loadManifest :: T.Text -> T.Text -> IO Manifest
loadManifest manifestPath baseIRI = do
  parseFile testParser (T.unpack manifestPath) >>= return . rdfToManifest . fromEither
  where testParser = TurtleParser (Just (BaseUrl baseIRI)) (Just baseIRI)

rdfToManifest :: TriplesGraph -> Manifest
rdfToManifest rdf = Manifest desc tpls
  where desc = lnodeText $ objectOf $ head $ query rdf (Just manifestNode) (Just rdfsComment) Nothing
        tpls = map (rdfToTestEntry rdf) $ rdfCollectionToList rdf collectionHead
        collectionHead = objectOf $ head $ query rdf (Just manifestNode) (Just mfEntries) Nothing
        manifestNode = head $ manifestSubjectNodes rdf

rdfToTestEntry :: TriplesGraph -> Node -> TestEntry
rdfToTestEntry rdf teSubject = triplesToTestEntry $ query rdf (Just teSubject) Nothing Nothing

triplesToTestEntry :: Triples -> TestEntry
triplesToTestEntry ts = case objectByPredicate rdfType ts of
                          (UNode "http://www.w3.org/ns/rdftest#TestTurtleEval") -> mkTestTurtleEval ts
                          (UNode "http://www.w3.org/ns/rdftest#TestTurtleNegativeEval") -> mkTestTurtleNegativeEval ts
                          (UNode "http://www.w3.org/ns/rdftest#TestTurtlePositiveSyntax") -> mkTestTurtlePositiveSyntax ts
                          (UNode "http://www.w3.org/ns/rdftest#TestTurtleNegativeSyntax") -> mkTestTurtleNegativeSyntax ts
                          _ -> error "Unknown test case"

mkTestTurtleEval :: Triples -> TestEntry
mkTestTurtleEval ts = TestTurtleEval {
                        name = lnodeText $ objectByPredicate mfName ts,
                        comment = lnodeText $ objectByPredicate rdfsComment ts,
                        approval = objectByPredicate rdftApproval ts,
                        action = objectByPredicate mfAction ts,
                        result = objectByPredicate mfResult ts
                      }

mkTestTurtleNegativeEval :: Triples -> TestEntry
mkTestTurtleNegativeEval ts = TestTurtleNegativeEval {
                                name = lnodeText $ objectByPredicate mfName ts,
                                comment = lnodeText $ objectByPredicate rdfsComment ts,
                                approval = objectByPredicate rdftApproval ts,
                                action = objectByPredicate mfAction ts
                              }

mkTestTurtlePositiveSyntax :: Triples -> TestEntry
mkTestTurtlePositiveSyntax ts = TestTurtlePositiveSyntax {
                                  name = lnodeText $ objectByPredicate mfName ts,
                                  comment = lnodeText $ objectByPredicate rdfsComment ts,
                                  approval = objectByPredicate rdftApproval ts,
                                  action = objectByPredicate mfAction ts
                                }

mkTestTurtleNegativeSyntax :: Triples -> TestEntry
mkTestTurtleNegativeSyntax ts = TestTurtleNegativeSyntax {
                                  name = lnodeText $ objectByPredicate mfName ts,
                                  comment = lnodeText $ objectByPredicate rdfsComment ts,
                                  approval = objectByPredicate rdftApproval ts,
                                  action = objectByPredicate mfAction ts
                                }

objectByPredicate :: Predicate -> Triples -> Object
objectByPredicate p ts = objectOf $ fromJust $ L.find (\t -> predicateOf t == p) ts

manifestSubjectNodes :: TriplesGraph -> [Subject]
manifestSubjectNodes rdf = subjectNodes rdf [mfManifest]

subjectNodes :: TriplesGraph -> [Object] -> [Subject]
subjectNodes rdf ns = map subjectOf $ concatMap queryType ns
  where queryType n = query rdf Nothing (Just rdfType) (Just n)

-- | Text of the literal node.
-- Note that it doesn't perform type conversion for TypedL.
-- TODO: Looks useful. Move it to RDF4H lib?
lnodeText :: Node -> T.Text
lnodeText (LNode(PlainL t)) = t
lnodeText (LNode(PlainLL t _)) = t
lnodeText (LNode(TypedL t _)) = t
lnodeText _ = error "Not a literal node"

-- | Convert an RDF collection to a List of its objects.
-- TODO: Looks useful. Move it to RDF4H lib?
rdfCollectionToList :: TriplesGraph -> Node -> [Node]
rdfCollectionToList rdf nbn = concatMap (tripleToList rdf) $ nextCollectionTriples rdf nbn

tripleToList :: TriplesGraph -> Triple -> [Node]
tripleToList rdf (Triple _ (UNode("http://www.w3.org/1999/02/22-rdf-syntax-ns#first")) n@(UNode _)) = [n]
tripleToList rdf (Triple _ (UNode("http://www.w3.org/1999/02/22-rdf-syntax-ns#rest")) bn@(BNodeGen _)) = rdfCollectionToList rdf bn
tripleToList rdf (Triple _ (UNode("http://www.w3.org/1999/02/22-rdf-syntax-ns#rest")) (UNode("http://www.w3.org/1999/02/22-rdf-syntax-ns#nil"))) = []
tripleToList rdf _ = error "Invalid collection format"

nextCollectionTriples :: TriplesGraph -> Node -> Triples
nextCollectionTriples rdf nbn@(BNodeGen _) = query rdf (Just nbn) Nothing Nothing
nextCollectionTriples rdf _ = error "Invalid collection format"
