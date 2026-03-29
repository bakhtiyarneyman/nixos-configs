module Shell
  ( Fragment (..)
  , FragmentType (..)
  , parseFragments
  ) where

import Protolude hiding (try)

import Data.Attoparsec.Text
import qualified Data.Text as T

data FragmentType = Command | Overwrite | Append
  deriving (Show, Eq)

data Fragment = Fragment FragmentType Text
  deriving (Show, Eq)

-- | Parse a shell command string into fragments.
-- Extracts processes (pipe stages, command list elements),
-- redirect targets (> and >>), and recursively handles
-- command substitution $() and backticks.
parseFragments :: Text -> Either [Char] [Fragment]
parseFragments input =
  case parseOnly (topLevel <* endOfInput) (T.strip input) of
    Left err -> Left err
    Right frags -> Right (filter nonEmpty frags)
  where
    nonEmpty (Fragment _ t) = not (T.null (T.strip t))

-- Top level: a sequence of commands separated by ;, &&, ||, |, newlines
topLevel :: Parser [Fragment]
topLevel = concat <$> commandGroup `sepBy` separator

-- A command group is a simple command with possible redirections
commandGroup :: Parser [Fragment]
commandGroup = do
  skipSpace
  go [] []
  where
    go :: [Text] -> [Fragment] -> Parser [Fragment]
    go cmdParts extraFrags = do
      skipHSpace
      atEnd <- atEnd
      if atEnd
        then pure (emitCmd cmdParts extraFrags)
        else do
          c <- peekChar'
          case c of
            -- Separators end this command group
            _ | isSepStart c -> pure (emitCmd cmdParts extraFrags)

            -- Redirect >> or > or >&
            '>' -> do
              _ <- char '>'
              isAppend <- option False (char '>' $> True)
              skipSpace
              -- fd duplication: >&N or >&- (not a file redirect)
              next <- peekChar
              case next of
                Just '&' -> do
                  _ <- char '&'
                  _ <- takeWhile1 (\x -> isDigit x || x == '-')
                  go cmdParts extraFrags
                _ -> do
                  target <- redirectTarget
                  let subFrags = extractSubcommandFragments target
                  let fragType = if isAppend then Append else Overwrite
                  go cmdParts (extraFrags ++ [Fragment fragType target] ++ subFrags)

            -- Could be process substitution <(...) or input redirect
            '<' -> do
              _ <- char '<'
              next <- peekChar
              case next of
                Just '(' -> do
                  -- Process substitution <(...)
                  inner <- parenBlock
                  let subFrags = parseSubcommand inner
                  go (cmdParts ++ ["<(" <> inner <> ")"]) (extraFrags ++ subFrags)
                Just '<' -> do
                  -- Heredoc << or <<-
                  _ <- char '<'
                  _ <- option ' ' (char '-')  -- <<- strips leading tabs
                  skipSpace
                  delim <- heredocDelim
                  consumeHeredocBody delim
                  go cmdParts extraFrags
                _ -> do
                  -- Input redirect < file
                  skipSpace
                  target <- redirectTarget
                  go (cmdParts ++ ["<", target]) extraFrags

            -- Command substitution $(...)
            '$' -> do
              _ <- char '$'
              next <- peekChar
              case next of
                Just '(' -> do
                  inner <- parenBlock
                  let subFrags = parseSubcommand inner
                  go (cmdParts ++ ["$(" <> inner <> ")"]) (extraFrags ++ subFrags)
                _ -> do
                  -- Regular $variable
                  rest <- takeWhile1 isVarChar <|> pure ""
                  go (cmdParts ++ ["$" <> rest]) extraFrags

            -- Backtick command substitution
            '`' -> do
              inner <- backtickBlock
              let subFrags = parseSubcommand inner
              go (cmdParts ++ ["`" <> inner <> "`"]) (extraFrags ++ subFrags)

            -- Quoted strings
            '\'' -> do
              s <- singleQuoted
              go (cmdParts ++ [s]) extraFrags

            '"' -> do
              s <- doubleQuoted
              let subFrags = extractSubcommandFragments s
              go (cmdParts ++ [s]) (extraFrags ++ subFrags)

            -- FD number before redirect (e.g., 2> or 2>> or 2>&1)
            _ | isDigit c -> do
              digits <- takeWhile1 isDigit
              next <- peekChar
              case next of
                Just '>' -> do
                  _ <- char '>'
                  isAppend <- option False (char '>' $> True)
                  skipSpace
                  -- fd duplication: 2>&1 or 2>&- (not a file redirect)
                  next2 <- peekChar
                  case next2 of
                    Just '&' -> do
                      _ <- char '&'
                      _ <- takeWhile1 (\x -> isDigit x || x == '-')
                      go cmdParts extraFrags
                    _ -> do
                      target <- redirectTarget
                      let subFrags = extractSubcommandFragments target
                      let fragType = if isAppend then Append else Overwrite
                      go cmdParts (extraFrags ++ [Fragment fragType target] ++ subFrags)
                _ ->
                  -- Just a number as part of a command
                  go (cmdParts ++ [digits]) extraFrags

            -- Parenthesized subshell
            '(' -> do
              inner <- parenBlock
              let subFrags = parseSubcommand inner
              go (cmdParts ++ ["(" <> inner <> ")"]) (extraFrags ++ subFrags)

            -- Regular word
            _ -> do
              w <- word
              go (cmdParts ++ [w]) extraFrags

    emitCmd :: [Text] -> [Fragment] -> [Fragment]
    emitCmd [] extras = extras
    emitCmd parts extras = Fragment Command (T.intercalate " " parts) : extras

-- Check if a character starts a separator
isSepStart :: Char -> Bool
isSepStart c = c == ';' || c == '|' || c == '&' || c == '\n'

-- Parse a separator: ;, &&, ||, |, newline
separator :: Parser ()
separator = do
  skipHSpace
  void (string "&&")
    <|> void (string "||")
    <|> void (char ';')
    <|> void (char '|')
    <|> void (char '\n')
  skipHSpace

-- Skip horizontal whitespace only (spaces and tabs, not newlines)
skipHSpace :: Parser ()
skipHSpace = skipWhile (\c -> c == ' ' || c == '\t')

-- Parse a word (non-whitespace, non-special token).
-- Handles backslash escapes: \( \; \| etc. are consumed as single units.
word :: Parser Text
word = T.concat <$> some wordPart
  where
    wordPart =
      -- Backslash escape: consume \ and next char as a unit
      (do _ <- char '\\'
          c <- anyChar
          pure ("\\" <> T.singleton c))
      -- Regular word characters
      <|> takeWhile1 isWordChar
      -- Bare trailing backslash (no char after it)
      <|> (T.singleton <$> char '\\')

    isWordChar c =
      not (isSpace c)
        && c /= ';'
        && c /= '|'
        && c /= '&'
        && c /= '>'
        && c /= '<'
        && c /= '('
        && c /= ')'
        && c /= '\''
        && c /= '"'
        && c /= '`'
        && c /= '$'
        && c /= '\\'

isVarChar :: Char -> Bool
isVarChar c = isAlphaNum c || c == '_'

-- Parse a redirect target (a word, possibly quoted)
redirectTarget :: Parser Text
redirectTarget = do
  skipSpace
  c <- peekChar'
  case c of
    '\'' -> singleQuoted
    '"' -> doubleQuoted
    _ -> word

-- Parse heredoc delimiter: bare word, 'quoted', or "quoted"
-- Returns the bare delimiter text (quotes stripped)
heredocDelim :: Parser Text
heredocDelim =
  (char '\'' *> takeTill (== '\'') <* char '\'')
  <|> (char '"' *> takeTill (== '"') <* char '"')
  <|> word

-- Consume heredoc body from current position to closing delimiter line
consumeHeredocBody :: Text -> Parser ()
consumeHeredocBody delim = do
  _ <- takeTill (== '\n')  -- skip rest of current line
  consumeHeredocLines delim

consumeHeredocLines :: Text -> Parser ()
consumeHeredocLines delim = do
  end <- atEnd
  if end then pure ()
  else do
    _ <- char '\n'
    line <- takeTill (== '\n')
    unless (T.strip line == delim) $
      consumeHeredocLines delim

-- Parse single-quoted string (no escaping inside)
singleQuoted :: Parser Text
singleQuoted = do
  _ <- char '\''
  content <- takeTill (== '\'')
  _ <- char '\''
  pure ("\'" <> content <> "\'")

-- Parse double-quoted string (backslash escaping)
doubleQuoted :: Parser Text
doubleQuoted = do
  _ <- char '"'
  content <- doubleQuotedContent
  _ <- char '"'
  pure ("\"" <> content <> "\"")

doubleQuotedContent :: Parser Text
doubleQuotedContent = T.concat <$> many' doubleQuotedPart

doubleQuotedPart :: Parser Text
doubleQuotedPart =
  -- Escaped character
  (do _ <- char '\\'
      c <- anyChar
      pure ("\\" <> T.singleton c))
  -- Command substitution inside double quotes
  <|> (do _ <- char '$'
          next <- peekChar
          case next of
            Just '(' -> do
              inner <- parenBlock
              pure ("$(" <> inner <> ")")
            _ -> do
              rest <- takeWhile1 isVarChar <|> pure ""
              pure ("$" <> rest))
  -- Backtick inside double quotes
  <|> (do inner <- backtickBlock
          pure ("`" <> inner <> "`"))
  -- Regular characters
  <|> takeWhile1 (\c -> c /= '"' && c /= '\\' && c /= '$' && c /= '`')

-- Parse balanced parentheses block, returning inner content
parenBlock :: Parser Text
parenBlock = do
  _ <- char '('
  content <- parenContent 1
  pure content

parenContent :: Int -> Parser Text
parenContent 0 = pure ""
parenContent depth = do
  c <- anyChar
  case c of
    ')' | depth == 1 -> pure ""
        | otherwise -> do
            rest <- parenContent (depth - 1)
            pure (")" <> rest)
    '(' -> do
      rest <- parenContent (depth + 1)
      pure ("(" <> rest)
    '\'' -> do
      inner <- takeTill (== '\'')
      _ <- char '\''
      rest <- parenContent depth
      pure ("\'" <> inner <> "\'" <> rest)
    '"' -> do
      inner <- doubleQuotedContent
      _ <- char '"'
      rest <- parenContent depth
      pure ("\"" <> inner <> "\"" <> rest)
    '\\' -> do
      next <- anyChar
      rest <- parenContent depth
      pure ("\\" <> T.singleton next <> rest)
    _ -> do
      rest <- parenContent depth
      pure (T.singleton c <> rest)

-- Parse backtick block
backtickBlock :: Parser Text
backtickBlock = do
  _ <- char '`'
  content <- takeTill (== '`')
  _ <- char '`'
  pure content

-- Recursively parse a subcommand string into fragments
parseSubcommand :: Text -> [Fragment]
parseSubcommand inner =
  case parseFragments inner of
    Right frags -> frags
    Left _ -> []

-- Extract subcommand fragments from text that may contain $() or backticks
extractSubcommandFragments :: Text -> [Fragment]
extractSubcommandFragments t =
  case parseOnly (extractSubs <* endOfInput) t of
    Right frags -> frags
    Left _ -> []

extractSubs :: Parser [Fragment]
extractSubs = concat <$> many' extractSubPart

extractSubPart :: Parser [Fragment]
extractSubPart =
  -- $(...) command substitution
  (do _ <- char '$'
      next <- peekChar
      case next of
        Just '(' -> do
          inner <- parenBlock
          pure (parseSubcommand inner)
        _ -> do
          _ <- takeWhile1 isVarChar <|> pure ""
          pure [])
  -- backtick command substitution
  <|> (do inner <- backtickBlock
          pure (parseSubcommand inner))
  -- skip any other character
  <|> (do _ <- anyChar
          pure [])
