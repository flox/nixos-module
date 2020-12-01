# NixOS module for flox

Add the following to `/etc/nixos/configuration.nix`:

```nix
{
  imports = [
    (import (fetchTarball "https://github.com/flox/nixos-module/archive/master.tar.gz"))
  ];
}
```

Then invoke: `sudo nixos-rebuild test --option extra-substituters 'https://beta.floxdev.com/floxchan/?trusted=1'`

Then, add the following parameter to the same file:

```nix
{
  services.flox.substituterAdded = true;
}
```

... and invoke it again: `sudo nixos-rebuild test --option extra-substituters 'https://beta.floxdev.com/floxchan/?trusted=1'`
