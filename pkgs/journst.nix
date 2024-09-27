{
  lib,
  pkgs,
  config,
}: let
  inherit (pkgs.lib) concatStringsSep stringToCharacters;

  # Read exclusions from the configuration
  exclusions = config.services.journal-brief.settings.exclusions;

  # Function to escape special characters in a string
  escapeCharIfInList = list: char:
    if builtins.elem char list
    then ''\${char}''
    else char;

  escapeStringIfInList = list: string:
    concatStringsSep "" (map (escapeCharIfInList list) (stringToCharacters string));

  # Function to escape regex special characters in a pattern
  escapeRegex =
    escapeStringIfInList (stringToCharacters "\\^$.|?*+()[]{}");

  # Function to process patterns for a field and combine them using alternation
  patternsToRegex = patterns: let
    # Process each pattern
    processedPatterns =
      map (
        pattern: let
          isRegex = builtins.match "^/.*/$" pattern != null;
          rawPattern =
            if isRegex
            then
              # Strip leading and trailing slashes
              builtins.substring 1 (builtins.stringLength pattern - 2) pattern
            else
              # Escape regex special characters and anchor the pattern
              "^${escapeRegex pattern}$";

          escapeString = escapeStringIfInList [''"'' ''\''];

          escapedPattern = escapeString rawPattern;
        in
          escapedPattern
      )
      patterns;
  in
    # Combine processed patterns using alternation '|'
    concatStringsSep "|" processedPatterns;

  # Function to generate jq expressions for a condition
  conditionToJq = condition: let
    # Generate field expressions
    fieldExpressions =
      lib.mapAttrsToList (
        field: patterns: let
          combinedPattern = patternsToRegex patterns;
        in
          # Field test expression with handling for missing fields and non-string values
          ''(try (.${field} | test("${combinedPattern}")) catch false)''
        # "((.${field} // \"\" | tostring) | test(\"${combinedPattern}\"))"
      )
      condition;
    # Combine field expressions using 'and'
    conditionExpression = concatStringsSep " and " fieldExpressions;
  in
    # Wrap the condition expression
    "(${conditionExpression})";

  # Generate the complete jq expression
  jqExpression = let
    # Generate condition expressions
    conditionExpressions = map conditionToJq exclusions;
    # Combine condition expressions using ' or '
    combinedConditions = concatStringsSep " or " conditionExpressions;
  in
    # Final jq expression (no array or 'any' needed)
    ''if ${combinedConditions} then empty else "\(.SYSLOG_IDENTIFIER)\u0000\(.MESSAGE)\u0000" end'';
in
  pkgs.writeTextFile {
    name = "journst";
    executable = true;
    destination = "/bin/journst";
    text = ''
      #!${pkgs.fish}/bin/fish
      ${pkgs.systemd}/bin/journalctl $argv --priority=err --output json | \
      stdbuf --output=0 ${pkgs.jq}/bin/jq --unbuffered -r --join-output '${
        escapeStringIfInList ["'" ''\''] jqExpression
      }' | \
      while IFS= read --null appname; and read --null message;
        ${pkgs.dunst}/bin/dunstify --urgency=critical --appname=$appname Error $message;
      end
    '';
  }
