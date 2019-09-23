# This file was stolen from https://gitlab.com/xaverdh/my-nixos-config/
{ config, lib, pkgs, ... }:

with lib;

let
   cfg = config.services.blueman;
in {

  options.services.blueman.enable = mkEnableOption "the blueman applet";

  config = mkIf cfg.enable {

    systemd.user.services.blueman.enable = true;
    systemd.user.services.blueman.serviceConfig.ExecStart = [ 
      "${pkgs.blueman}/bin/blueman-applet" 
    ];

    systemd.packages = [ pkgs.blueman ];
    services.dbus.packages = [ pkgs.blueman ];
  };

}
