{pkgs, ...}: {
  imports = [
    ./hardware.nix
    ./fs.nix

    ../../../profiles
  ];

  nix.package = pkgs.nixUnstable;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  environment.systemPackages = [
    pkgs.libva
  ];

  primary-user.name = "gwen";

  networking = {
    hostName = "mithrix";
    hostId = "960855f8";
    interfaces.eno1.useDHCP = true;
    useDHCP = false;
  };

  services.nginx = {
    enable = true;

    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
  };

  networking.firewall.allowedTCPPorts = [80 9002];

  services.prometheus.exporters = {
    node = {
      enable = true;
      enabledCollectors = ["systemd"];
      port = 9002;
    };
  };

  virtualisation = {
    containers = {
      enable = true;
    };

    docker = {
      enable = true;
      storageDriver = "devicemapper";
    };
    oci-containers.backend = "docker";
  };

  primary-user.extraGroups = ["docker"];
}
