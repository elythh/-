{
  config,
  lib,
  pkgs,
  ...
}: let
  hostName = config.networking.hostName;
  otherMachineNames = lib.remove config.networking.hostName (
    builtins.filter (machine: machine != "yellowstone.cofree.coffee") (builtins.attrNames (builtins.readDir ../../../machines))
  );

  syncthingMachineIds = {};
in {
  boot.kernel.sysctl."fs.inotify.max_user_watches" = 1048576;

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = config.primary-user.name;
    dataDir = config.primary-user.home-manager.home.homeDirectory;
    cert = "/secrets/${hostName}-syncthing-cert";
    key = "/secrets/${hostName}-syncthing-key";
    devices = lib.genAttrs otherMachineNames (machine: {
      id = syncthingMachineIds."${machine}";
    });
    folders = {
      Org = {
        path = "${config.primary-user.home}/Org";
        devices = otherMachineNames;
      };
      Public = {
        path = "${config.primary-user.home}/Public";
        devices = otherMachineNames;
      };
    };
  };

  systemd.services = {
    syncthing = {
      wants = [
        "syncthing-cert-key.service"
        "syncthing-key-key.service"
      ];
      after = [
        "syncthing-cert-key.service"
        "syncthing-key-key.service"
      ];
    };

    syncthing-init.serviceConfig.ExecStartPost = pkgs.writeShellScript "rm-sync-dir" ''
      if [ -d "$HOME/Sync" ]
      then
        rmdir "$HOME/Sync"
      fi
    '';
  };
}
