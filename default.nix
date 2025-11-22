{
  pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem,
}: let
  inherit (pkgs) lib;
  sources = builtins.fromJSON (lib.strings.fileContents ./sources.json);

  # mkBinaryInstall makes a derivation that installs Claude Code from a binary.
  mkBinaryInstall = {
    url,
    version,
    sha256,
  }:
    pkgs.stdenv.mkDerivation {
      inherit version;

      pname = "claude";
      src = pkgs.fetchurl {inherit url sha256;};
      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;
      dontFixup = true;
      installPhase = ''
        mkdir -p $out/bin
        install -m755 $src $out/bin/claude
      '';

      meta = with lib; {
        description = "Claude Code CLI - AI-powered coding assistant";
        homepage = "https://claude.ai/code";
        license = licenses.unfree;
        platforms = platforms.linux ++ platforms.darwin;
        maintainers = [];
      };
    };

  # The packages that are tagged releases
  taggedPackages =
    lib.attrsets.mapAttrs
    (_: v: mkBinaryInstall {inherit (v.${system}) version url sha256;})
    (lib.attrsets.filterAttrs
      (_: v: (builtins.hasAttr system v) && (v.${system}.url != null) && (v.${system}.sha256 != null))
      sources);

  # This determines the latest /released/ version.
  latest = lib.lists.last (
    builtins.sort
    (x: y: (builtins.compareVersions x y) < 0)
    (builtins.attrNames taggedPackages)
  );
in
  # We want the packages but also add a "default" that just points to the
  # latest released version.
  taggedPackages // {"default" = taggedPackages.${latest};}
