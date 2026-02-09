{...}: {
  config.networking.wireguard.interfaces.mullvad = {
    ips = ["10.67.21.121/32" "fc00:bbbb:bbbb:bb01::4:1578/128"];
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
