{ lib, pkgs, options, config, ... }:
let

  inherit (lib) types;
  cfg = config.services.flox;

  flox = import (builtins.fetchTarball "https://${cfg.server}/floxchan/nixexprs.tar.bz2") {};
in {

  options.services.flox = {
    enable = lib.mkEnableOption "Flox" // {
      # Enable by default because just including this module should turn it on
      default = true;
    };

    # we can switch with the new substituter in one shot with:
    # nixos-rebuild switch --option extra-substituters 'https://beta.floxdev.com/floxchan?trusted=1'
    substituterAdded = lib.mkOption {
      description = ''
        Whether the flox binary substituter is configured. This should initially
        be turned off, but then turned on after the initial rebuild which
        configures them.
      '';
      type = types.bool;
      default = false;
    };

    server = lib.mkOption {
      description = ''
        Which flox server to use.
      '';
      type = types.str;
      default = "beta.floxdev.com";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      nix.binaryCaches = lib.mkAfter [
        "https://${cfg.server}/floxchan/?trusted=1"
      ];

      warnings = lib.mkIf (! cfg.substituterAdded)
        [ ("The option services.flox.substituterAdded is turned off, which "
        + "should only be done for the initial rebuild. If the initial rebuild "
        + "is completed, enable this option to configure flox fully:"
        + "\n  services.flox.substituterAdded = true;") ];
    }
    (lib.mkIf cfg.substituterAdded {

      environment = {
        etc = {
          "flox.toml".source = "${flox.flox-uncle}/etc/flox.toml";
          "npfs.conf".source = "${flox.flox-uncle}/etc/npfs.conf";
          "flox-release".source = "${flox.flox-uncle}/etc/flox-release";
        };
        systemPackages = [
          flox.flox-uncle
          flox.floxrun # to reveal man page
        ];
      };

      systemd.services = {
        flox = {
          description = "Flox";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" "local-fs.target" ];
          requires = [ "network-online.target" "local-fs.target" ];
          after = [ "network-online.target" "local-fs.target" ];
          path = [ flox.flox-uncle pkgs.utillinux ];
          serviceConfig = {
            User = "root";
            Type = "notify";
            NotifyAccess = "all";
            ExecStart = "${flox.flox-uncle}/bin/floxd";
            ExecReload = "${flox.flox-uncle}/bin/floxadm restart";
            ExecStop = "${flox.flox-uncle}/bin/floxadm stop";
          };
          reloadIfChanged = true;
          # environment.FLOXADM_DEBUG = "1";
        };
      };

      # TODO: Figure out which set of permissions are necessary
      security.wrappers."floxrun" = {
        source = "${flox.floxrun}/bin/floxrun";
        owner = "root";
        group = "root";
      };

    })
  ]);
}
