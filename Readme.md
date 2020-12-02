# NixOS module for flox

To install flox on NixOS, add the following to `/etc/nixos/configuration.nix`:

```nix
{
  imports = [
    (import (fetchTarball "https://github.com/flox/nixos-module/archive/master.tar.gz"))
  ];
}
```

Then invoke: `sudo nixos-rebuild switch`. This will configure the binary substituter needed for flox.

Once finished, add the following parameter to the same file:

```nix
{
  services.flox.substituterAdded = true;
}
```

And run `sudo nixos-rebuild switch` again. This will fully configure flox.
