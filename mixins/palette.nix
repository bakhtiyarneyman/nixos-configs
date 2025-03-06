{
  lib,
  config,
  ...
}: {
  # `kmscon` supports all of these, so don't introduce new colors here.
  options.palette = {
    black = lib.mkOption {
      type = lib.types.str;
      default = "000000";
    };
    background = lib.mkOption {
      type = lib.types.str;
      default = "23272e";
    };
    red = lib.mkOption {
      type = lib.types.str;
      default = "be5046";
    };
    yellow = lib.mkOption {
      type = lib.types.str;
      default = "d19a66";
    };
    green = lib.mkOption {
      type = lib.types.str;
      default = "7a9f60";
    };
    blue = lib.mkOption {
      type = lib.types.str;
      default = "3b84c0";
    };
    magenta = lib.mkOption {
      type = lib.types.str;
      default = "9a52af";
    };
    foreground = lib.mkOption {
      type = lib.types.str;
      default = "abb2bf";
    };
    white = lib.mkOption {
      type = lib.types.str;
      default = "ffffff";
    };
  };

  config = {
    environment.etc."sway/colors.conf".text = let
      toColor = name: hex: "set $" + "${name} #${hex}";
    in
      builtins.concatStringsSep "\n" (
        builtins.attrValues (builtins.mapAttrs toColor config.palette)
      );
  };
}
