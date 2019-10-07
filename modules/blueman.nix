# This file was stolen from https://gitlab.com/xaverdh/my-nixos-config/
{ config, lib, pkgs, ... }:

with lib;

let
   cfg = config.services.blueman;
in {

  options.services.blueman.enable = mkEnableOption "the blueman applet";

  config = mkIf cfg.enable {

    systemd.user.services.blueman = {
      enable = true;
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig.ExecStart = [
      "${pkgs.blueman}/bin/blueman-applet"
      ];
    };

    hardware.bluetooth.enable = true;
    systemd.packages = [ pkgs.blueman ];
    services.dbus.packages = [ pkgs.blueman ];
    environment.systemPackages = [ pkgs.blueman ];
  };

}
