{...}: {
  config.networking.wireguard.interfaces.mullvad = {
    privateKeyFile = "/etc/nixos/secrets/mullvad_wireguard.private_key";

    peers = [
      {
        publicKey = "sjWKL/W2+21cyjEBjtMd4TQQlWTsLTUN4skYOF7YgnU=";
        endpoint = "23.234.94.127:51820";
        allowedIPs = ["0.0.0.0/0" "::/0"];
      }
    ];
  };
}
