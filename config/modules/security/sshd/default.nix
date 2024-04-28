{
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
    extraConfig = "PermitUserEnvironment yes";
  };

  programs.ssh.startAgent = true;

  services.sshd.enable = true;

  security.pam = {
    enableSSHAgentAuth = true;
    services.sudo.sshAgentAuth = true;
  };

  primary-user.openssh.authorizedKeys.keys = import ./public-keys.nix;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHDhjgl7IPOvAP/pv8o1hnmSYE2ccN7IqMaGI3a3PYJT homelab - default key"
  ];
}
