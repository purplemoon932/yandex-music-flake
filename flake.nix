{
  description = "Personal recommendations, mixes for any occasion and the latest musical releases";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      versionInfo = builtins.fromJSON (builtins.readFile ./version.json);

      pkgs = import nixpkgs {
        inherit system;

        config.allowUnfreePredicate =
          pkg:
          builtins.elem (lib.getName pkg) [
            "yandex-music"
          ];
      };

      yandex-music = pkgs.stdenvNoCC.mkDerivation rec {
        pname = "yandex-music";
        version = versionInfo.version;

        src = pkgs.fetchurl {
          url = "https://desktop.app.music.yandex.net/stable/Yandex_Music_amd64_${versionInfo.version}.deb";
          hash = versionInfo.hash;
        };

        nativeBuildInputs = [
          pkgs.dpkg
          pkgs.autoPatchelfHook
          pkgs.makeWrapper
          pkgs.asar
          pkgs.nodejs
        ];

        buildInputs = with pkgs; [
          glib
          nspr
          nss

          dbus
          at-spi2-atk
          cups

          cairo
          gtk3
          pango

          libx11
          libxcomposite
          libxdamage
          libxext
          libxfixes
          libxrandr
          libxcb
          libxkbcommon

          libgbm
          libglvnd
          expat
          systemd
          alsa-lib
        ];

        dontConfigure = true;
        dontBuild = true;

        unpackPhase = ''
          runHook preUnpack

          mkdir unpack
          dpkg-deb -x "$src" unpack

          runHook postUnpack
        '';

        installPhase = ''
          runHook preInstall

          app="$out/lib/yandex-music"

          mkdir -p "$app"
          cp -a "unpack/opt/Яндекс Музыка/." "$app/"

          # Null out the bundled auto-updater: extract -> patch -> repack.
          asar extract "$app/resources/app.asar" app-unpacked
          rm "$app/resources/app.asar"
          node ${./scripts/disable-updates.mjs} app-unpacked/index.js
          asar pack app-unpacked "$app/resources/app.asar"
          rm -rf app-unpacked

          # Remove update config so even unpatched code finds no provider/updater.
          rm "$app/resources/app-update.yml" "$app/resources/package-type"

          mkdir -p "$out/bin"

          makeWrapper "$app/yandexmusic" "$out/bin/yandexmusic" \
            --prefix LD_LIBRARY_PATH : "${
              lib.makeLibraryPath [
                pkgs.libglvnd
              ]
            }:${pkgs.addDriverRunpath.driverLink}"

          mkdir -p "$out/share/applications"
          cp "unpack/usr/share/applications/yandexmusic.desktop" \
            "$out/share/applications/yandexmusic.desktop"

          substituteInPlace "$out/share/applications/yandexmusic.desktop" \
            --replace-fail \
            "/opt/Яндекс Музыка/yandexmusic" \
            "$out/bin/yandexmusic"

          mkdir -p "$out/share"
          cp -a "unpack/usr/share/icons" "$out/share/"

          runHook postInstall
        '';

        postInstall = ''
          addAutoPatchelfSearchPath "$out/lib/yandex-music"
        '';

        meta = {
          description = "Desktop application for Yandex Music";
          homepage = "https://music.yandex.ru/";
          license = lib.licenses.unfree;
          platforms = [ "x86_64-linux" ];
          sourceProvenance = with lib.sourceTypes; [
            binaryNativeCode
          ];
          mainProgram = "yandexmusic";
        };
      };
    in
    {
      packages = {
        ${system} = {
          default = yandex-music;
          yandex-music = yandex-music;
        };
      };

      apps = {
        ${system} = {
          default = {
            type = "app";
            program = "${yandex-music}/bin/yandexmusic";
            meta = {
              description = "Desktop application for Yandex Music";
            };
          };
        };
      };

      checks = {
        ${system}.default = pkgs.runCommand "yandex-music-check" {
          nativeBuildInputs = [
            pkgs.binutils
            pkgs.glibc.bin
          ];
        } ''
          bash ${./scripts/check-ldd.sh} ${yandex-music}
          touch $out
        '';
      };
    };
}
