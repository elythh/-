{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    unstable.url = "github:nixos/nixpkgs";

    flake-utils = {
      url = "github:numtide/flake-utils";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "unstable";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    unstable,
    flake-utils,
    home-manager,
    disko,
    sops-nix,
    nixos-hardware,
    nixos-generators,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;

      config = {
        allowUnfree = true;
      };
    };

    mkServer = targetHost: {config, ...}: {
      deployment = {
        inherit targetHost;
        #targetUser = config.primary-user.name;
        tags = ["server"];
        allowLocalDeployment = false;
      };

      imports = [
        "${toString config/machines/servers}/${targetHost}"
        nixpkgs.nixosModules.notDetected
        home-manager.nixosModules.home-manager
        sops-nix.nixosModules.sops
        disko.nixosModules.disko
      ];

      sops = {
        defaultSopsFile = ./secrets.yaml;
        secrets.primary-user-password = {};
      };
    };
  in {
    formatter."${system}" = pkgs.nixpkgs-fmt;
    devShells."${system}".default = pkgs.mkShell {
      nativeBuildInputs = [pkgs.colmena pkgs.nixfmt-rfc-style pkgs.sops];
    };

    packages.x86_64-linux = {
      # NixOS boot disk with my SSH Keys integrated
      nixos-iso = nixos-generators.nixosGenerate {
        inherit system;
        format = "install-iso";
        modules = [
          ./installer
          home-manager.nixosModules.home-manager
        ];
      };

      # NixOS-Anywhere provisioning script for physical machines.
      # nix run '.#install-pc'
      install-pc = let
        src = builtins.readFile ./installer/install-pc.sh;

        script = (pkgs.writeScriptBin "install-pc" src).overrideAttrs (old: {
          buildCommand = "${old.buildCommand}\n patchShebangs $out";
        });
      in
        pkgs.symlinkJoin {
          name = "install-pc";
          paths = [pkgs.gum pkgs.jq pkgs.pass script];
          buildInputs = [pkgs.makeWrapper];
          postBuild = "wrapProgram $out/bin/install-pc --prefix PATH : $out/bin";
        };

      # NixOS-Anywhere provisioning script for virtual machines and remote servers.
      # nix run '.#install-server'
      install-server = let
        src = builtins.readFile ./installer/install-server.sh;

        script = (pkgs.writeScriptBin "install-server" src).overrideAttrs (old: {
          buildCommand = "${old.buildCommand}\n patchShebangs $out";
        });
      in
        pkgs.symlinkJoin {
          name = "install-server";
          paths = [pkgs.gum pkgs.jq pkgs.pass script];
          buildInputs = [pkgs.makeWrapper];
          postBuild = "wrapProgram $out/bin/install-server --prefix PATH : $out/bin";
        };

      deploy = pkgs.writeShellScriptBin "deploy" ''
        servers=$(ls config/machines/servers)
        all="servers"
        machine=$(echo "$servers" | ${pkgs.gum}/bin/gum choose)
        echo "Deploying '$machine'"
        ${pkgs.colmena}/bin/colmena apply --on $machine
      '';

      deploy-all = pkgs.writeShellScriptBin "deploy-all" ''
        ${pkgs.colmena}/bin/colmena apply --on @server
      '';
    };

    apps = {
      deploy = flake-utils.lib.mkApp {drv = self.packages.${system}.deploy;};
      deploy-all = flake-utils.lib.mkApp {drv = self.packages.${system}.deploy-all;};
      default = self.apps.${system}.deploy;
    };

    nixosConfigurations = {
      mithrix = nixpkgs.lib.nixosSystem {
        inherit pkgs system;
        modules = [
          ./config/machines/servers/mithrix
          ({...}: {
            sops = {
              defaultSopsFile = ./secrets.yaml;
              secrets.primary-user-password = {};
            };
          })
          nixpkgs.nixosModules.notDetected
          home-manager.nixosModules.home-manager
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
        ];

        specialArgs = {inherit inputs;};
      };
    };

    colmena = let
      configs = self.nixosConfigurations;
    in
      {
        meta = {
          nixpkgs = pkgs;
          specialArgs = {
            inherit inputs;
          };
          nodeNixpkgs = builtins.mapAttrs (name: value: value.pkgs) configs;
          nodeSpecialArgs = builtins.mapAttrs (name: value: value._module.specialArgs) configs;
        };
      }
      // builtins.mapAttrs (machine: _: mkServer machine) (builtins.readDir ./config/machines/servers)
      // builtins.mapAttrs
      (name: value: {
        deployment = {
          targetHost = name;
          tags = ["pc"];
          allowLocalDeployment = true;
        };
        imports = value._module.args.modules;
      })
      configs;
  };
}
