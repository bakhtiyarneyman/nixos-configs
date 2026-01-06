#!/usr/bin/env fish
set domain tin.orkhon-mohs.ts.net
if pushd /etc/nixos/secrets
    tailscale cert $domain
    and openssl pkcs12 -export -out $domain.pfx -inkey $domain.key -in $domain.crt -passout pass:
    and setfacl -m g:server:r $domain.{key,crt,pfx}
    and systemctl restart home-assistant immich-server jellyfin monero prowlarr qbittorrent radarr sonarr
    popd
end
