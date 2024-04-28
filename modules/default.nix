{...}: {
  imports = [
    ./nixos/network-interfaces.nix
    ./nixos/primary-user.nix
    ./nixos/qbittorrent.nix
    ./nixos/s3fs.nix
  ];
}
