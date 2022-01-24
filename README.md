# nixos-configs
My NixOS configs shared across my machines. To image a new machine:
1. Obtain a NixOS installer and burn it onto a USB.
2. Boot into it.
3. Follow the normal installation process but stop just short of running `nixos-install`.
4. Checkout this repository into `/etc/nixos`.
5. Invent a new hostname `<HOSTNAME>` and adapt the `hardware-configuration.nix` into a `hosts/<HOSTNAME>.nix`.
6. Delete `configuration.nix`.
7. Run `nixos-install --flake /mnt/etc/nixos#<HOSTNAME>`.

Code in this repo is subject to MIT license (see LICENSE file).

Images are believed to be authorized for sharing and personal use as desktop wallpaper by the author.
