module Main (main) where

import Protolude

import Data.Attoparsec.Text (Parser, parseOnly, char, string, takeWhile1, skipSpace, endOfInput, anyChar, peekChar', many')
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import qualified System.IO as IO

import DSL (Reason (..), Result (..), Verdict (..), evaluateCommand)
import Rules (rules)

main :: IO ()
main = do
  input <- TIO.getContents
  case extractCommand input of
    Left err -> do
      IO.hPutStrLn IO.stderr ("claude-permission-hook: " <> err)
      exitWith (ExitFailure 2)
    Right command -> do
      result <- evaluateCommand rules 0 command
      TIO.putStrLn (formatResponse result)

-- | Extract tool_input.command from hook input JSON using attoparsec.
-- We look for the "command" key inside "tool_input" without a full JSON parser.
extractCommand :: Text -> Either [Char] Text
extractCommand input =
  case parseOnly (findJsonStringValue "command") input of
    Left _ -> Left "Could not extract tool_input.command from input"
    Right cmd -> Right cmd

-- | Find a JSON string value for a given key anywhere in the text.
-- Scans for "key": "value" pattern and extracts the value.
findJsonStringValue :: Text -> Parser Text
findJsonStringValue key = scanForKey
  where
    scanForKey = do
      -- Try to match the key at current position
      matchKey <|> (anyChar *> scanForKey)

    matchKey = do
      _ <- char '"'
      _ <- string key
      _ <- char '"'
      skipSpace
      _ <- char ':'
      skipSpace
      jsonStringValue

-- | Parse a JSON string value (handles escape sequences).
jsonStringValue :: Parser Text
jsonStringValue = do
  _ <- char '"'
  content <- jsonStringContent
  _ <- char '"'
  pure content

jsonStringContent :: Parser Text
jsonStringContent = T.concat <$> many' jsonStringPart

jsonStringPart :: Parser Text
jsonStringPart =
  -- Escape sequence
  (do _ <- char '\\'
      c <- peekChar'
      case c of
        '"'  -> anyChar $> "\""
        '\\' -> anyChar $> "\\"
        '/'  -> anyChar $> "/"
        'n'  -> anyChar $> "\n"
        't'  -> anyChar $> "\t"
        'r'  -> anyChar $> "\r"
        _    -> do ch <- anyChar; pure ("\\" <> T.singleton ch))
  -- Regular characters (not " or \)
  <|> takeWhile1 (\c -> c /= '"' && c /= '\\')

-- | Format a reason for display: "command: message".
formatReason :: Reason -> Text
formatReason (Reason cmd msg) = cmd <> ": " <> msg

-- | Format the hook response as JSON.
formatResponse :: Result -> Text
formatResponse (Result verdict reasons) =
  let verdictStr = case verdict of
        Allow -> "allow"
        Ask -> "ask"
        Deny -> "deny"
      reasonStr = T.intercalate "; " (map formatReason reasons)
  in "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\""
     <> ",\"permissionDecision\":\"" <> verdictStr <> "\""
     <> ",\"permissionDecisionReason\":\"" <> escapeJson reasonStr <> "\""
     <> "}}"

-- | Escape a string for JSON output.
escapeJson :: Text -> Text
escapeJson = T.concatMap escapeChar
  where
    escapeChar '"'  = "\\\""
    escapeChar '\\' = "\\\\"
    escapeChar '\n' = "\\n"
    escapeChar '\t' = "\\t"
    escapeChar '\r' = "\\r"
    escapeChar c    = T.singleton c
