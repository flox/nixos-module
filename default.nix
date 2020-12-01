{ lib, pkgs, options, config, ... }:
let

  inherit (lib) types;
  cfg = config.services.flox;

  flox = import (builtins.fetchTarball "https://beta.floxdev.com/floxchan/nixexprs.tar.bz2") {};
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
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      nix.binaryCaches = lib.mkAfter [
        "https://beta.floxdev.com/floxchan/?trusted=1"
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
          "flox.toml".source = "${flox.flox-config}/etc/flox.toml";
          # Set non-default mode to force NixOS to copy to /etc. We
          # do this because the UNCLE namespace prevents us from
          # storing configuration in /nix/store.
          "flox.toml".mode = "0644";
          "npfs.conf".source = "${flox.flox-config}/etc/npfs.conf";
          "flox-release".source = "${flox.flox-config}/etc/flox-release";
        };
        systemPackages = [ flox.floxadm flox.icfs ];
      };

      systemd.services = {
        flox = {
          description = "Flox";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" "local-fs.target" ];
          path = [ flox.floxadm ];
          serviceConfig = {
            User = "root";
            Type = "oneshot"; # "notify";
            NotifyAccess = "all";
            ExecStart = "${flox.floxadm}/bin/floxd";
            TimeoutSec = 300;
            Restart = "no";
            KillMode = "none";
          };
          environment.FLOXADM_DEBUG = "1";
        };

        # TODO: These should be undone when the service is uninstalled.
        # More declarative with perhaps the fileSystems option might solve this
        floxmnt = {
          description = "Setup flox overlay mount namespace";
          wantedBy = [ "multi-user.target" ];
          requires = [ "flox.service" ];
          after = [ "flox.service" ];
          path = [ pkgs.utillinux ];
          script = ''
            set -eux
            # First clear up any leftover mounts.
            test ! -e /run/flox/mnt || umount -q /run/flox/mnt || true
            test ! -e /run/flox || umount -q /run/flox || true
            # Create run directory for persisted namespace mount.
            mkdir -p /run/flox
            # Make run directory a private mount namespace as required
            # for persisted mounts. See:
            # https://github.com/karelzak/util-linux/issues/289.
            mount --bind /run/flox /run/flox
            mount --make-private /run/flox
            # Bind mount namespace to path before creating child mounts.
            touch /run/flox/mnt
            unshare --mount=/run/flox/mnt $SHELL -c '
              mount --make-rslave /nix/store && \
              mount -t overlay overlay -olowerdir=/nix/store:/flox/store /nix/store'
          '';
          serviceConfig.Type = "oneshot";
        };
      };

      # TODO: Figure out which set of permissions are necessary
      security.wrappers."floxrun" = {
        source = "${flox.floxrun}/bin/floxrun";
        #capabilities = "cap_sys_admin+ep";
        owner = "root";
        group = "root";
        #permissions = "u+rx,g+rx,o-rx";
      };

    })
  ]);
}
