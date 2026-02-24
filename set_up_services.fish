#!/usr/bin/env fish
sudo tailscale serve --https=443 --service=svc:frigate https+insecure://localhost:8971
sudo tailscale serve --https=443 --service=svc:immich localhost:2283
sudo tailscale serve --https=443 --service=svc:jellyfin localhost:8096
sudo tailscale serve --https=443 --service=svc:jellyseerr localhost:5055
sudo tailscale serve --https=443 --service=svc:ntopng localhost:4256
sudo tailscale serve --https=443 --service=svc:prowlarr localhost:9696
sudo tailscale serve --https=443 --service=svc:qbittorrent localhost:8080
sudo tailscale serve --https=443 --service=svc:radarr localhost:7878
sudo tailscale serve --https=443 --service=svc:sonarr localhost:8989
