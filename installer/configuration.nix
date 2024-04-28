# Default system config for fresh machines.
{
  pkgs,
  lib,
  ...
}: {
  imports = [./hardware-configuration.nix];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.openssh = {
    enable = true;
    passwordAuthentication = false;
    extraConfig = "PermitUserEnvironment yes";
  };

  programs.ssh.startAgent = true;

  services.sshd.enable = true;

  security.pam = {
    enableSSHAgentAuth = true;
    services.sudo.sshAgentAuth = true;
  };

  users = {
    mutableUsers = false;
    users.gwen = {
      isNormalUser = true;
      extraGroups = ["wheel" "networkmanager" "keys"];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHedhPWMgsGFQS7niiFlgkCty/0yS68tVP0pm4x4PQLp gwen@nightshade"
      ];
      passwordFile = "/etc/primary-user-password";
    };
    users.root.hashedPassword = "*";
  };

  nix.settings.trusted-users = ["root" "gwen"];
  nix.package = pkgs.nixUnstable;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  users.users.root.openssh.authorizedKeys.keyFiles = [/etc/ssh/authorized_keys.d/root];

  networking = {
    hostName = "nixos";
    wireless.enable = true;
    useDHCP = lib.mkDefault true;
    # TODO: This should be generated in the install.sh script
    hostId = "997f3c8d";
  };

  environment.systemPackages = [pkgs.vim pkgs.git];

  system.stateVersion = "23.11";
}
