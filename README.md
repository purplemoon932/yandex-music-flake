# Yandex Music Flake

<!-- markdownlint-disable MD013 MD033 -->
<p align="center">
  <a href="flake.nix"><img src="https://img.shields.io/badge/Nix-flakes-9cbeff?style=for-the-badge&amp;labelColor=0D1117&amp;logo=nixos&amp;logoColor=white" alt="Nix Flakes"></a>
  <a href="flake.nix"><img src="https://img.shields.io/badge/platform-x86__64--linux-85c5fa?style=for-the-badge&amp;labelColor=0D1117&amp;logo=linux&amp;logoColor=white" alt="Platform"></a>
  <a href="https://github.com/purplemoon932/yandex-music-flake/commits/main"><img src="https://img.shields.io/github/last-commit/purplemoon932/yandex-music-flake?style=for-the-badge&amp;labelColor=0D1117&amp;color=9dce8f" alt="Last commit"></a>
</p>

<p align="center">Nix flake for the Yandex Music Linux desktop client</p>
<!-- markdownlint-enable MD013 MD033 -->

## Try it without installing

```bash
nix run github:purplemoon932/yandex-music-flake
```

Unfree access is allowed inside the flake, so a global `allowUnfree` setting is
not required.

## Install on NixOS

### Step 1: Add the flake input

In your system `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    yandex-music.url = "github:purplemoon932/yandex-music-flake";
  };

  outputs = { nixpkgs, ... }@inputs: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      # For home-manager, use home-manager.extraSpecialArgs instead.
      modules = [ ./configuration.nix ];
    };
  };
}
```

### Step 2: Add the package

In `configuration.nix`:

```nix
{ inputs, pkgs, ... }:

{
  environment.systemPackages = [
    # Or use home.packages for home-manager.
    inputs.yandex-music.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
```

## How it is built

It fetches the official `.deb` package, extracts it, disables auto-updates,
repacks it, and adds a wrapper with the required libraries.
