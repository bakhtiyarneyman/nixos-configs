{
  lib,
  config,
  ...
}: {
  options.services.nfs.server = with lib; {
    importers = mkOption {
      type = with types; listOf str;
      default = [];
    };
    boundExports = mkOption {
      type = with types; attrsOf str;
      default = {};
    };
  };

  config = let
    cfg = config.services.nfs.server;
  in {
    fileSystems = let
      mkExport = name: device: {
        "/exports/${name}" = {
          inherit device;
          options = ["bind"];
        };
      };
    in
      lib.attrsets.concatMapAttrs mkExport cfg.boundExports;

    services.nfs.server.exports = let
      trustedHosts = builtins.concatStringsSep "," cfg.importers;
      mkExport = name: _: "/exports/${name} ${trustedHosts}(rw,no_subtree_check)";
    in
      builtins.concatStringsSep "\n" (
        builtins.attrValues (builtins.mapAttrs mkExport cfg.boundExports)
      );
  };
}
