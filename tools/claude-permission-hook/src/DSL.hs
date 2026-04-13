module DSL (
  Node (..),
  Subject (..),
  MatchTarget (..),
  FragmentType (..),
  Verdict (..),
  Result (..),
  match,
  command,
  (~>),
  allow,
  ask,
  deny,
  recurse,
  evaluateCommand,
) where

import Protolude hiding (ask, check, try)

import Data.ByteString qualified as BS
import Data.ByteString.Char8 qualified as BS8
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.Process (CreateProcess (..), readCreateProcessWithExitCode, shell)
import Text.Regex.PCRE.Light (Regex, captureNames, compileM, dotall)
import Text.Regex.PCRE.Light qualified as PCRE

import Shell (Fragment (..), FragmentType (..), parseFragments)

-- | DSL node types
data Subject
  = Process MatchTarget Text    -- ^ shell command to execute + what to match
  | Variable Text               -- ^ env variable name to read
  deriving (Eq, Show)

data Node
  = Match Subject [(Text, Node)]
  | Decision Verdict Text
  | Recurse [(FragmentType, Text)]
  deriving (Show)

data MatchTarget = Stdout | ErrorCode
  deriving (Eq, Show)

data Verdict = Allow | Ask | Deny
  deriving (Eq, Ord, Show)

data Result = Result
  { resultVerdict :: Verdict
  , resultReasons :: [Text]
  }
  deriving (Show)

-- | DSL combinators
match :: Subject -> [(Text, Node)] -> Node
match = Match

-- | Convenience: Variable "COMMAND" appears in most rules.
command :: Subject
command = Variable "COMMAND"

(~>) :: Text -> Node -> (Text, Node)
(~>) = (,)

infixr 0 ~>

allow :: Text -> Node
allow = Decision Allow

ask :: Text -> Node
ask = Decision Ask

deny :: Text -> Node
deny = Decision Deny

recurse :: [(FragmentType, Text)] -> Node
recurse = Recurse

type Env = Map Text Text

maxRecursionDepth :: Int
maxRecursionDepth = 10

-- | Evaluate a command string against a rule tree.
-- Parses into fragments, evaluates each, aggregates results.
evaluateCommand :: Node -> Int -> Text -> IO Result
evaluateCommand root depth command
  | depth > maxRecursionDepth =
      pure (Result Ask ["Max recursion depth exceeded for: " <> command])
  | otherwise =
      case parseFragments command of
        Left err ->
          pure (Result Ask ["Failed to parse command: " <> T.pack err])
        Right [] ->
          -- Empty command (e.g., comment only) — no opinion
          pure (Result Allow [])
        Right frags -> do
          results <- mapM (evaluateFragment root depth) frags
          pure (aggregateResults results)

-- | Evaluate a single fragment against the rule tree.
evaluateFragment :: Node -> Int -> Fragment -> IO Result
evaluateFragment root depth (Fragment ftype content) =
  let env =
        Map.fromList
          [ ("COMMAND", content)
          , ("FRAGMENT_TYPE", fragmentTypeName ftype)
          ]
  in evaluateNode root depth env root

fragmentTypeName :: FragmentType -> Text
fragmentTypeName Command = "command"
fragmentTypeName Overwrite = "overwrite"
fragmentTypeName Append = "append"

-- | Evaluate a node in the rule tree.
evaluateNode :: Node -> Int -> Env -> Node -> IO Result
evaluateNode root depth env = \case
  Decision verdict reason ->
    pure (Result verdict [expandVars env reason])
  Recurse pairs
    | depth > maxRecursionDepth ->
        pure (Result Ask ["Max recursion depth exceeded"])
    | otherwise -> do
        results <- forM pairs $ \(ftype, template) ->
          let value = expandVars env template
          in evaluateFragment root (depth + 1) (Fragment ftype value)
        pure (aggregateResults results)
  Match source cases -> do
    subject <- case source of
      Variable varName -> pure (Map.findWithDefault "" varName env)
      Process matchTarget cmd -> do
        let expandedCmd = expandVars env cmd
        (exitCode, stdout, _stderr) <- runShell env expandedCmd
        pure $ case matchTarget of
          Stdout -> T.strip (T.pack stdout)
          ErrorCode -> T.pack (show (exitCodeToInt exitCode))
    matchCases root depth env subject cases

-- | Try each case pattern against the subject, first match wins.
matchCases :: Node -> Int -> Env -> Text -> [(Text, Node)] -> IO Result
matchCases root depth env subject = \case
  [] ->
    let cmd = Map.findWithDefault subject "COMMAND" env
    in pure (Result Ask ["No rule matched '" <> cmd <> "'"])
  (pattern, node) : rest ->
    case compileRegex pattern of
      Left err ->
        pure (Result Ask ["Invalid regex '" <> pattern <> "': " <> T.pack err])
      Right regex ->
        case PCRE.match regex (TE.encodeUtf8 subject) [] of
          Nothing -> matchCases root depth env subject rest
          Just groups -> do
            let captures = extractNamedCaptures regex groups
            let newEnv = Map.union captures env -- captures shadow parent
            evaluateNode root depth newEnv node

-- | Compile a PCRE regex pattern, implicitly anchored to match the full subject.
compileRegex :: Text -> Either [Char] Regex
compileRegex pattern =
  let anchored = "\\A(?:" <> TE.encodeUtf8 pattern <> ")\\z"
  in case compileM anchored [dotall] of
       Left err -> Left err
       Right regex -> Right regex

-- | Extract named captures from a regex match.
-- captureNames returns 0-based capture indices, but match results have
-- the full match at index 0, so we add 1 to get the right group.
extractNamedCaptures :: Regex -> [BS.ByteString] -> Map Text Text
extractNamedCaptures regex groups =
  let names = captureNames regex
  in Map.fromList
       [ (TE.decodeUtf8 name, TE.decodeUtf8 val)
       | (name, idx) <- names
       , Just val <- [atMay groups (idx + 1)]
       ]

-- | Run a shell command with the given environment variables.
runShell :: Env -> Text -> IO (ExitCode, [Char], [Char])
runShell env cmd = do
  parentEnv <- getEnvironment
  let hookEnv = map (\(k, v) -> (T.unpack k, T.unpack v)) (Map.toList env)
  let fullEnv = hookEnv ++ parentEnv
  let process = (shell (T.unpack cmd)) {env = Just fullEnv}
  readCreateProcessWithExitCode process ""

-- | Convert ExitCode to Int.
exitCodeToInt :: ExitCode -> Int
exitCodeToInt ExitSuccess = 0
exitCodeToInt (ExitFailure n) = n

-- | Expand $VAR and ${VAR} references in a text.
expandVars :: Env -> Text -> Text
expandVars env = go
 where
  go t
    | T.null t = t
    | otherwise =
        case T.breakOn "$" t of
          (before, after)
            | T.null after -> before
            | otherwise ->
                let rest = T.drop 1 after -- skip the $
                in case T.uncons rest of
                     Nothing -> before <> "$"
                     Just ('{', rest') ->
                       case T.breakOn "}" rest' of
                         (varName, rest'')
                           | T.null rest'' -> before <> "${" <> rest'
                           | otherwise ->
                               before
                                 <> Map.findWithDefault "" varName env
                                 <> go (T.drop 1 rest'') -- skip }
                     Just (c, _)
                       | isVarStartChar c ->
                           let (varName, rest') = T.span isVarChar rest
                           in before <> Map.findWithDefault "" varName env <> go rest'
                       | otherwise -> before <> "$" <> go rest

  isVarStartChar c = isAlpha c || c == '_'
  isVarChar c = isAlphaNum c || c == '_'

-- | Aggregate multiple results: any Deny → Deny, any Ask → Ask, else Allow.
aggregateResults :: [Result] -> Result
aggregateResults results
  | any ((== Deny) . resultVerdict) results =
      Result Deny (concatMap resultReasons (filter ((== Deny) . resultVerdict) results))
  | any ((== Ask) . resultVerdict) results =
      Result Ask (concatMap resultReasons (filter ((== Ask) . resultVerdict) results))
  | otherwise =
      Result Allow []
