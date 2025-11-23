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
      nativeBuildInputs =
        [pkgs.makeWrapper]
        ++ lib.optionals pkgs.stdenv.isLinux [pkgs.autoPatchelfHook];
      buildInputs = lib.optionals pkgs.stdenv.isLinux (with pkgs; [
        stdenv.cc.cc.lib
        zlib
      ]);
      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        mkdir -p $out/bin
        install -m755 $src $out/bin/.claude-wrapped
      '';
      # Wrap the binary with environment variables to disable telemetry and auto-updates
      postFixup = ''
        wrapProgram $out/bin/.claude-wrapped \
          --set DISABLE_AUTOUPDATER 1 \
          --set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1 \
          --set DISABLE_NON_ESSENTIAL_MODEL_CALLS 1 \
          --set DISABLE_TELEMETRY 1
        mv $out/bin/.claude-wrapped $out/bin/claude
      '';

      # Disable version check: The distributed binary is version 1.3.2 (last 1.x release)
      # which self-updates to 2.x on first run. Since /nix/store is read-only, the
      # self-update cannot occur, so the binary remains at 1.3.2 but functions correctly.
      # The official installer works around this by running `claude install` which downloads
      # the actual 2.x binary, but this requires network access during build.
      doInstallCheck = false;
      # Prevent all install check phases including versionCheckPhase
      installCheckPhase = "echo 'Skipping install check'";
      dontCheck = true;

      passthru = {
        updateScript = ./update;
      };

      meta = with lib; {
        description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
        homepage = "https://claude.ai/code";
        downloadPage = "https://github.com/anthropics/claude-code/releases";
        changelog = "https://github.com/anthropics/claude-code/releases";
        license = licenses.unfree;
        mainProgram = "claude";
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
