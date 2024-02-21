{lib, ...}: {
  options.palette = {
    black = lib.mkOption {
      type = lib.types.str;
      default = "#282c34";
    };
    green = lib.mkOption {
      type = lib.types.str;
      default = "#7a9f60";
    };
    blue = lib.mkOption {
      type = lib.types.str;
      default = "#3b84c0";
    };
    yellow = lib.mkOption {
      type = lib.types.str;
      default = "#d19a66";
    };
    red = lib.mkOption {
      type = lib.types.str;
      default = "#be5046";
    };
    magenta = lib.mkOption {
      type = lib.types.str;
      default = "#9a52af";
    };
    white = lib.mkOption {
      type = lib.types.str;
      default = "#abb2bf";
    };
  };
}
